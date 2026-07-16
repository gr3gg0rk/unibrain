import SwiftUI

#if os(iOS)
import AVFoundation
import UnibrainCore
import UnibrainProviders

// MARK: - iOSRecordState

/// State machine for the iOS Record tab.
enum iOSRecordState: Equatable {
    case idle
    case recording
    case paused
    case saved
}

// MARK: - iOSRecordViewModel

/// Lightweight record-only view model for the iOS Record tab.
///
/// Per IOS-04 and the plan's action block: iPhone is capture-only (no
/// orchestrator/transcriber). This view model owns a RecordingSession actor,
/// a NowPlayingManager, timer state, mic level, waveform buffer, and session
/// state enum.
///
/// Per DISC-04: background recording survives via UIBackgroundModes + active
/// AVAudioSession (configured in AudioRecorder.start via iOSAudioSessionManager).
///
/// Per IC-02: On Stop, the file is moved from sandbox tmp/ to
/// {vault}/_inbox/{source}-{timestamp}-{uuidSuffix}.m4a.
@Observable
@MainActor
final class iOSRecordViewModel {

    // MARK: - Published State

    var recordState: iOSRecordState = .idle
    var elapsedSeconds: TimeInterval = 0
    var micLevel: Float = -160
    var waveformBuffer: [Float] = []

    // MARK: - Dependencies

    private let session = RecordingSession()
    private let nowPlaying = NowPlayingManager.shared

    // MARK: - Private State

    private var pollTask: Task<Void, Never>?
    private var tempURL: URL?

    // MARK: - Recording Lifecycle

    /// Starts recording per IOS-04.
    ///
    /// Per the plan: configures iOSAudioSessionManager (via AudioRecorder.start),
    /// calls session.startRecording with sandbox tmp/ path, starts NowPlayingManager,
    /// begins polling timer.
    func startRecording() async {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let temp = tempDir.appendingPathComponent("unibrain_ios_\(UUID().uuidString).m4a")
            tempURL = temp

            try await session.startRecording(destination: temp)
            recordState = .recording

            nowPlaying.startRecording(
                onPause: { [weak self] in
                    Task { @MainActor in await self?.pauseRecording() }
                },
                onStop: { [weak self] in
                    Task { @MainActor in await self?.stopRecording() }
                }
            )

            startPolling()
        } catch {
            recordState = .idle
        }
    }

    /// Pauses recording per CAPT-02.
    func pauseRecording() async {
        do {
            try await session.pause()
            recordState = .paused
            stopPolling()
        } catch {
            // Non-critical — recording continues
        }
    }

    /// Resumes recording after pause.
    func resumeRecording() async {
        do {
            try await session.resume()
            recordState = .recording
            startPolling()
        } catch {
            // Non-critical
        }
    }

    /// Stops recording and moves file to vault _inbox/ per IC-02.
    ///
    /// Per IC-02: Atomic move from sandbox tmp/ to {vault}/_inbox/.
    /// Uses IC-03 naming: {source}-{YYYYMMDDTHHMMSS}-{uuidSuffix}.m4a.
    func stopRecording() async {
        do {
            let result = try await session.stop()

            nowPlaying.stopRecording()
            stopPolling()

            // Per IC-02: move to vault _inbox/
            await moveAudioToInbox(from: result.audioURL)

            recordState = .saved

            // Brief "Saved" confirmation, then return to idle
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5s
                self?.resetToIdle()
            }
        } catch {
            recordState = .idle
        }
    }

    // MARK: - Private: IC-02 Move to Inbox

    /// Moves the audio file from sandbox tmp/ to the vault _inbox/ subfolder.
    ///
    /// Per IC-02: Uses BookmarkStore to resolve the vault URL.
    /// Per IC-03: Filename follows {source}-{YYYYMMDDTHHMMSS}-{uuidSuffix}.m4a.
    private func moveAudioToInbox(from sourceURL: URL) async {
        guard let vaultURL = BookmarkStore.resolve() else {
            // No vault bookmark — file stays in tmp (lost on purge).
            // In production, the user should have completed onboarding.
            return
        }

        defer {
            vaultURL.stopAccessingSecurityScopedResource()
        }

        let inboxDir = vaultURL.appendingPathComponent("_inbox")

        // Create _inbox if needed
        try? FileManager.default.createDirectory(
            at: inboxDir,
            withIntermediateDirectories: true
        )

        // Per IC-03: generate filename
        let uuidSuffix = String(UUID().uuidString.prefix(4)).lowercased()
        let filename = InboxFilename.generate(
            source: "iphone",
            timestamp: Date(),
            uuidSuffix: uuidSuffix
        )

        let destinationURL = inboxDir.appendingPathComponent(filename)

        // Per IC-02: atomic move
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            // Move failed — file remains in sandbox tmp.
            // TRIG-01 launch scan will catch it on next app open.
        }
    }

    // MARK: - Private: Polling

    /// Polls RecordingSession for live timer + mic level at ~30fps.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                let elapsed = await self.session.elapsedSeconds
                let level = await self.session.currentLevel

                self.elapsedSeconds = elapsed
                self.micLevel = level

                // Update waveform buffer (P-D5): shift + append, max 64
                self.waveformBuffer.append(level)
                if self.waveformBuffer.count > 64 {
                    self.waveformBuffer.removeFirst(self.waveformBuffer.count - 64)
                }

                // Update lock-screen Now Playing elapsed time
                self.nowPlaying.updateElapsed(elapsed)

                try? await Task.sleep(nanoseconds: 33_333_333) // ~30fps
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Private: Reset

    private func resetToIdle() {
        recordState = .idle
        elapsedSeconds = 0
        micLevel = -160
        waveformBuffer = []
        tempURL = nil
        Task { await session.reset() }
    }
}

// MARK: - iOSRecordTab View

/// Full-screen recording UI for iOS per IOS-04 and UI-SPEC Surface 2.
///
/// Per IOS-04: Scales Phase 3 macOS popover components up to full-screen iPhone.
/// Idle state: status lines + large Record button.
/// Recording state: 48pt monospaced timer + waveform + mic meter + Pause/Stop.
/// Paused state: frozen timer, dimmed waveform, Resume + Stop.
/// Saved state: brief "Saved" confirmation.
struct iOSRecordTab: View {

    @State private var viewModel = iOSRecordViewModel()

    var body: some View {
        VStack {
            switch viewModel.recordState {
            case .idle:
                idleView
            case .recording:
                recordingView
            case .paused:
                pausedView
            case .saved:
                savedView
            }
        }
        .padding()
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Ready to record")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Label("Microphone available", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
                Label("Calendar connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }

            Spacer()

            Button {
                Task { await viewModel.startRecording() }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .frame(width: 80, height: 80)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Start recording")
            .accessibilityHint("Taps once to begin recording. Recording continues when screen is locked.")

            Spacer()
        }
    }

    // MARK: - Recording State

    private var recordingView: some View {
        VStack(spacing: 24) {
            // Per UI-SPEC: 48pt monospaced timer
            Text(formatTime(viewModel.elapsedSeconds))
                .font(.system(size: 48, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())

            // Per IOS-04: full-width waveform (Canvas)
            WaveformView(buffer: viewModel.waveformBuffer)
                .frame(height: 96)

            // Per IOS-04: 3-segment mic meter
            MicMeterView(level: viewModel.micLevel)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    Task { await viewModel.pauseRecording() }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    Task { await viewModel.stopRecording() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Paused State

    private var pausedView: some View {
        VStack(spacing: 24) {
            Text(formatTime(viewModel.elapsedSeconds))
                .font(.system(size: 48, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            WaveformView(buffer: viewModel.waveformBuffer)
                .frame(height: 96)
                .opacity(0.4)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    Task { await viewModel.resumeRecording() }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    Task { await viewModel.stopRecording() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Saved State

    private var savedView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Saved")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Syncing to your Mac via iCloud.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Helpers

    /// Formats seconds as HH:MM:SS for the timer display.
    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

// MARK: - WaveformView

/// SwiftUI Canvas waveform visualization.
///
/// Per IOS-04: Expanded from Phase 3 to full-width 96pt height.
/// Renders the rolling buffer of mic level readings.
struct WaveformView: View {
    let buffer: [Float]

    var body: some View {
        Canvas { context, size in
            guard !buffer.isEmpty else { return }

            let barWidth = size.width / CGFloat(buffer.count)
            let midY = size.height / 2

            for (index, level) in buffer.enumerated() {
                // Convert dB (-160 to 0) to normalized height (0 to 1)
                let normalized = normalizeLevel(level)
                let barHeight = normalized * size.height

                let rect = CGRect(
                    x: CGFloat(index) * barWidth,
                    y: midY - barHeight / 2,
                    width: barWidth * 0.8,
                    height: barHeight
                )

                context.fill(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .color(.accentColor)
                )
            }
        }
    }

    private func normalizeLevel(_ db: Float) -> CGFloat {
        // Map -60dB..0dB to 0..1 (anything below -60 is silence)
        let clamped = max(-60, min(0, db))
        return CGFloat((clamped + 60) / 60)
    }
}

// MARK: - MicMeterView

/// 3-segment horizontal mic-level meter per IOS-04 and CAPT-05.
///
/// Green (low), Yellow (mid), Red (peak) segments confirm the lecturer is audible.
struct MicMeterView: View {
    let level: Float

    var body: some View {
        let normalized = normalizeLevel(level)

        GeometryReader { geo in
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.green)
                    .frame(width: geo.size.width / 3)
                    .opacity(normalized > 0.0 ? 1 : 0.3)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.yellow)
                    .frame(width: geo.size.width / 3)
                    .opacity(normalized > 0.5 ? 1 : 0.3)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.red)
                    .frame(width: geo.size.width / 3)
                    .opacity(normalized > 0.8 ? 1 : 0.3)
            }
        }
        .frame(height: 8)
    }

    private func normalizeLevel(_ db: Float) -> CGFloat {
        let clamped = max(-60, min(0, db))
        return CGFloat((clamped + 60) / 60)
    }
}

#endif
