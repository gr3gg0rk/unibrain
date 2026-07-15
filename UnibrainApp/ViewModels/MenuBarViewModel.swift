import Foundation
import SwiftUI
import UserNotifications
#if canImport(AVFoundation)
import AVFoundation
#endif
import UnibrainCore
import UnibrainProviders

// MARK: - SessionDisplayState

/// Display-level state mapping for the menu-bar popover UI.
///
/// Unifies RecordingSession states and PipelineOrchestrator states into a
/// single enum the SwiftUI view can switch on.
enum SessionDisplayState: Equatable {
    case idle
    case recording
    case paused
    case transcribing
    case completed
    case error(String)

    static func == (lhs: SessionDisplayState, rhs: SessionDisplayState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.recording, .recording),
             (.paused, .paused),
             (.transcribing, .transcribing),
             (.completed, .completed):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - MenuBarViewModel

/// @Observable bridge between RecordingSession, SmallEnDownloader, and
/// PipelineOrchestrator for the menu-bar popover UI.
///
/// Per P-08..P-12: the menu-bar popover is the PRIMARY recording surface.
/// This view model exposes UI-friendly state derived from the three
/// underlying domain objects.
///
/// Per TRAN-03: transcription runs via `Task.detached(priority: .userInitiated)`
/// so the MainActor stays responsive.
///
/// Per P-17: download progress is observed for the idle-state status line.
@Observable
@MainActor
final class MenuBarViewModel {

    // MARK: - Published State (UI reads these)

    /// Current display state driving the popover layout switch.
    var sessionState: SessionDisplayState = .idle

    /// Elapsed recording time in seconds (CAPT-04 live timer).
    var elapsedTime: TimeInterval = 0

    /// Current mic level in dB (CAPT-05 mic meter).
    var micLevel: Float = -160

    /// Rolling buffer of last 64 mic level readings for waveform display (P-D5).
    var waveformBuffer: [Float] = []

    /// Download progress: nil when no active download or verified; 0.0-1.0 while downloading (P-17).
    var downloadProgress: Double? = nil

    /// True when model is verified or not needed (SpeechAnalyzer works without model).
    var isModelReady: Bool = false

    /// Number of pauses in current session.
    var pauseCount: Int = 0

    /// Total seconds spent paused (for paused-state summary line per UI-SPEC).
    var totalPausedSeconds: TimeInterval = 0

    // MARK: - Dependencies (injected)

    private let session: RecordingSession
    private let orchestrator: PipelineOrchestrator
    private let downloader: SmallEnDownloader

    /// Polling task for live timer + mic level updates (~30fps).
    private var pollTask: Task<Void, Never>?

    /// Task observing download state changes.
    private var downloadObserverTask: Task<Void, Never>?

    /// The recording start date — needed for PipelineInputs construction.
    private var recordingStartDate: Date?

    // MARK: - Init

    init(
        session: RecordingSession,
        orchestrator: PipelineOrchestrator,
        downloader: SmallEnDownloader
    ) {
        self.session = session
        self.orchestrator = orchestrator
        self.downloader = downloader
        self.sessionState = .idle
        startObservingDownload()
    }

    // deinit: Tasks capture self weakly — they self-terminate when self
    // is deallocated. Swift 6 @MainActor classes cannot access isolated
    // properties from nonisolated deinit.

    // MARK: - Recording Lifecycle

    /// Starts a new recording session.
    ///
    /// Per CAPT-01: one-tap start via menu-bar Record button.
    /// Per P-D2: audio is recorded to temp, moved to destination on stop.
    func startRecording() async {
        do {
            let destination = computeDestinationURL()
            recordingStartDate = Date()
            try await session.startRecording(destination: destination)
            sessionState = .recording
            startPolling()
        } catch {
            sessionState = .error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    /// Pauses the current recording.
    ///
    /// Per CAPT-02: pause with distinct visual state.
    func pauseRecording() async {
        do {
            try await session.pause()
            pauseCount += 1
            sessionState = .paused
            stopPolling()
        } catch {
            sessionState = .error("Failed to pause: \(error.localizedDescription)")
        }
    }

    /// Resumes recording after a pause.
    ///
    /// Per CAPT-02: resume continues writing to the same file.
    func resumeRecording() async {
        do {
            try await session.resume()
            sessionState = .recording
            startPolling()
        } catch {
            sessionState = .error("Failed to resume: \(error.localizedDescription)")
        }
    }

    /// Stops recording and kicks off transcription.
    ///
    /// Per CAPT-01: one-tap stop — no confirmation dialog.
    /// Per P-11: popover transitions to transcribing state within 200ms.
    /// Per TRAN-03: transcription runs via Task.detached off MainActor.
    func stopRecording() async {
        do {
            let result = try await session.stop()

            // Per P-11: transition to transcribing immediately for responsive UI.
            sessionState = .transcribing

            // Construct PipelineInputs from the recording result.
            guard let recordingStart = recordingStartDate else {
                sessionState = .error("Recording start time was lost.")
                return
            }

            let inputs = PipelineWiring.makePipelineInputs(
                recordingResult: result,
                source: "MacBook",
                recordingStart: recordingStart
            )

            // Per TRAN-03: run transcription off MainActor.
            let orchestrator = self.orchestrator
            Task.detached(priority: .userInitiated) { [weak self] in
                do {
                    try await orchestrator.run(inputs: inputs)
                    await MainActor.run {
                        self?.onTranscriptionComplete()
                    }
                } catch {
                    await MainActor.run {
                        self?.onTranscriptionError(error)
                    }
                }
            }
        } catch {
            sessionState = .error("Failed to stop recording: \(error.localizedDescription)")
        }
    }

    /// Dismisses the completion state and returns to idle.
    func dismissCompletion() async {
        await orchestrator.reset()
        await session.reset()
        sessionState = .idle
        elapsedTime = 0
        micLevel = -160
        waveformBuffer = []
        pauseCount = 0
        totalPausedSeconds = 0
        recordingStartDate = nil
    }

    /// Retries the model download after a failure (P-18).
    func retryDownload() {
        Task {
            await downloader.startDownload()
        }
    }

    // MARK: - Permission Handling

    /// Requests microphone permission.
    ///
    /// Per UI-SPEC: if denied, the idle status line shows "Microphone permission needed".
    @discardableResult
    func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
        let granted = await requestMicPermission()
        return granted
        #else
        return false
        #endif
    }

    // MARK: - Private: Polling

    /// Starts polling RecordingSession for live timer + mic level at ~30fps.
    ///
    /// Per P-D5: waveform buffer is updated from mic level readings.
    /// Per TRAN-03: polling reads from the actor without blocking MainActor rendering.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                let elapsed = await self.session.elapsedSeconds
                let level = await self.session.currentLevel

                self.elapsedTime = elapsed
                self.micLevel = level

                // Update waveform buffer (P-D5): shift + append, max 64 elements.
                self.waveformBuffer.append(level)
                if self.waveformBuffer.count > 64 {
                    self.waveformBuffer.removeFirst(self.waveformBuffer.count - 64)
                }

                // Poll at ~30fps
                try? await Task.sleep(nanoseconds: 33_333_333)
            }
        }
    }

    /// Stops the polling task (called on pause/stop).
    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Private: Destination URL

    /// Computes the audio file destination URL.
    ///
    /// Per P-15: audio file sits alongside the note at
    /// `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.m4a`.
    private func computeDestinationURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: Date())

        return HardcodedVaultResolver.lecturesDir
            .appendingPathComponent("\(dateString)-Lecture.m4a")
    }

    // MARK: - Private: Download Observation

    /// Observes the SmallEnDownloader state for the idle-status line (P-10, P-17).
    private func startObservingDownload() {
        downloadObserverTask?.cancel()
        downloadObserverTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                let state = await self.downloader.currentState
                switch state {
                case .notStarted:
                    self.downloadProgress = nil
                    self.isModelReady = false
                case .downloading(let progress):
                    self.downloadProgress = progress
                    self.isModelReady = false
                case .verified:
                    self.downloadProgress = nil
                    self.isModelReady = true
                case .failed:
                    self.downloadProgress = nil
                    self.isModelReady = false
                }

                // Check every 500ms — download progress doesn't need 30fps.
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    // MARK: - Private: Transcription Callbacks

    /// Called when transcription completes successfully.
    ///
    /// Per P-11: fires a macOS system notification and transitions to .completed.
    private func onTranscriptionComplete() {
        stopPolling()
        sessionState = .completed
        fireCompletionNotification()
    }

    /// Called when transcription fails.
    private func onTranscriptionError(_ error: Error) {
        stopPolling()
        sessionState = .error("Transcription failed: \(error.localizedDescription)")
    }

    /// Fires a macOS system notification on transcription completion (P-11).
    ///
    /// Per UI-SPEC copywriting contract:
    /// - Title: "Lecture transcript ready"
    /// - Body: "Opened in vault"
    private func fireCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Lecture transcript ready"
        content.body = "Opened in vault"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "unibrain-transcription-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in
            // Fire-and-forget — notification errors are non-critical.
        }
    }

    // MARK: - Private: Microphone Permission

    #if os(macOS)
    /// Requests microphone access on macOS.
    ///
    /// On macOS 14+, uses the AVAudioApplication requestRecordPermission API.
    /// Returns true if permission was already granted or is granted on request.
    private func requestMicPermission() async -> Bool {
        // macOS 14+ uses AVAudioApplication
        let granted = await AVAudioApplication.requestRecordPermission()
        return granted
    }
    #endif
}
