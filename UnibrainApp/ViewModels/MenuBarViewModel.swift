import Foundation
import SwiftUI
import UserNotifications
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(AppKit)
import AppKit
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
    case awaitingCourseSelection
    case completed
    case error(String)

    static func == (lhs: SessionDisplayState, rhs: SessionDisplayState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.recording, .recording),
             (.paused, .paused),
             (.transcribing, .transcribing),
             (.awaitingCourseSelection, .awaitingCourseSelection),
             (.completed, .completed):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - PopoverOverlay

/// Inline overlay state for the popover.
///
/// Per RESEARCH.md Pitfall 2 (FB11984872): `.sheet` on `MenuBarExtra(.window)`
/// is unreliable on macOS — sheets fail to anchor or appear behind other windows.
/// All Phase 4 surfaces render INLINE within the 280pt popover by switching on
/// this enum in the popover's `body`.
enum PopoverOverlay: Equatable {
    /// No overlay — normal popover state (idle/recording/transcribing/etc).
    case none
    /// Course picker shown when CourseClassifier returns .multiple or .none.
    case coursePicker(CoursePickerMode)
    /// Manage Courses mapping table.
    case manageCourses
    /// First-time calendar permission explanation.
    case permissionDenied
    /// Term label + date range editor.
    case termEditor
}

// MARK: - PipelineOrchestratorProtocol

/// Protocol abstraction for PipelineOrchestrator, enabling test injection.
///
/// Per W3 fix: Tests inject a mock conforming to this protocol to verify
/// resume/skipClassification calls without a real orchestrator.
/// Not isolated to any actor — both the real actor and test mocks can conform.
protocol PipelineOrchestratorProtocol: Sendable {
    func resume(with event: CalendarEvent) async
    func skipClassification() async
    func cancel()
    func reset()
    func run(inputs: PipelineInputs) async throws
}

// MARK: - PipelineOrchestrator Conformance

/// PipelineOrchestrator is an actor whose methods already match this protocol.
/// Swift 6 handles actor-to-MainActor hops automatically when the view model
/// calls these methods.
extension PipelineOrchestrator: PipelineOrchestratorProtocol {}

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

    // MARK: - Phase 4: Overlay State (inline view-state switching per Pitfall 2)

    /// Drives the inline overlay view switch in the popover.
    /// Per Pitfall 2 (FB11984872): replaces .sheet with inline view-state switching.
    var overlayState: PopoverOverlay = .none

    // MARK: - Phase 4: Calendar Permission State

    /// Tracks current calendar permission status.
    var calendarPermission: PermissionState = .notDetermined

    /// Tracks first-time overlay display (persisted via @AppStorage on macOS).
    var hasShownPermissionOverlay: Bool = false

    // MARK: - Phase 4: Term State

    /// Current term label from CourseMappingStore, displayed in idle state.
    var currentTermLabel: String = ""

    /// True when currentTerm.endDate has passed.
    var termHasExpired: Bool = false

    // MARK: - Phase 5: iCloud Inbox State

    /// Number of pending files in the iCloud inbox queue.
    var inboxPendingCount: Int = 0

    /// Current inbox processing state for popover display.
    var inboxProcessingState: InboxProcessingState = .idle

    /// Phase 5: Controls presentation of PermissionsSheet from the popover.
    var showPermissions = false

    /// Phase 5: Triggers PermissionsSheet presentation (ONBD-05).
    func showPermissionsSheet() {
        showPermissions = true
    }

    // MARK: - Dependencies (injected)

    private let session: RecordingSession
    private let downloader: SmallEnDownloader

    /// Orchestrator protocol — allows test injection via PipelineOrchestratorProtocol.
    private let overlayOrchestrator: PipelineOrchestratorProtocol?

    /// Per-recording orchestrator with fresh mapping snapshot (Phase 4 gap 1).
    /// Reconstructed in stopRecording with the latest CourseMappingStore data.
    private var currentOrchestrator: PipelineOrchestrator?

    /// Access to the real orchestrator — prefers per-recording instance,
    /// falls back to the injected (test) orchestrator.
    private var orchestrator: PipelineOrchestrator? {
        currentOrchestrator ?? (overlayOrchestrator as? PipelineOrchestrator)
    }

    // MARK: - Phase 4: Injected Dependencies

    /// Course mapping store for reading/writing courses.json.
    private var courseMappingStore: CourseMappingStore?

    /// Calendar provider for fetching events.
    private var calendarProvider: (any CalendarEventProvider)?

    /// Course picker view model created on demand when picker fires.
    private var coursePickerViewModel: CoursePickerViewModel?

    /// Polling task for live timer + mic level updates (~30fps).
    private var pollTask: Task<Void, Never>?

    /// Task observing download state changes.
    private var downloadObserverTask: Task<Void, Never>?

    /// Task polling orchestrator.currentState for .awaitingUserChoice (Phase 4 gap 2).
    private var stateObserverTask: Task<Void, Never>?

    /// Events captured during stopRecording for match reconstruction (Phase 4 gap 2).
    private var pendingEvents: [CalendarEvent] = []

    /// The recording start date — needed for PipelineInputs construction.
    private var recordingStartDate: Date?

    // MARK: - Init (Phase 3 — backward compatible with Phase 4 additions)

    init(
        session: RecordingSession,
        orchestrator: PipelineOrchestrator,
        downloader: SmallEnDownloader,
        courseMappingStore: CourseMappingStore? = nil,
        calendarProvider: (any CalendarEventProvider)? = nil
    ) {
        self.session = session
        self.overlayOrchestrator = orchestrator
        self.downloader = downloader
        self.courseMappingStore = courseMappingStore
        self.calendarProvider = calendarProvider
        self.sessionState = .idle
        startObservingDownload()
    }

    // MARK: - Test Init (W3 fix — allows mock orchestrator injection)

    /// Test-only init that accepts a mock orchestrator protocol.
    /// Used by MenuBarViewModelOverlayTests to verify overlay state transitions.
    init(
        overlayOrchestrator: PipelineOrchestratorProtocol
    ) {
        self.session = RecordingSession()
        self.overlayOrchestrator = overlayOrchestrator
        self.downloader = SmallEnDownloader()
        self.sessionState = .idle
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
    ///
    /// Per W4 fix: Explicitly sets `inputs.termLabel = currentTermLabel` so
    /// the pipeline carries the real term label to NoteNormalizer and
    /// ScheduleAwareVaultResolver (without this, termLabel defaults to empty
    /// string and the resolver falls back to "default-term").
    ///
    /// Per P-02: Requests calendar permission on first recording if .notDetermined.
    /// Fetches calendar events for classification if permission is granted.
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

            // Per P-02: Request calendar permission just-in-time if not yet determined.
            if calendarPermission == .notDetermined {
                await requestCalendarPermission()
            }

            // Fetch calendar events if permission is granted.
            var events: [CalendarEvent] = []
            if calendarPermission == .granted, let provider = calendarProvider {
                do {
                    let term = try await courseMappingStore?.currentTerm()
                    let dateRange = (term?.startDate ?? .distantPast)...(term?.endDate ?? .distantFuture)
                    events = try await provider.fetchEvents(in: dateRange)
                } catch {
                    // Calendar fetch failed — proceed with empty events.
                    // The manual picker will fire for .none match.
                    events = []
                }
            }

            // W4 fix: explicitly set termLabel from currentTermLabel.
            var inputs = PipelineWiring.makePipelineInputs(
                recordingResult: result,
                source: "MacBook",
                recordingStart: recordingStart
            )
            inputs.events = events
            inputs.termLabel = currentTermLabel

            // Phase 4 gap 2: Store events for match reconstruction when
            // the orchestrator parks at .awaitingUserChoice.
            self.pendingEvents = events

            // Phase 4 gap 1: Construct a fresh orchestrator with the latest
            // mapping snapshot so newly-learned courses route correctly.
            let mapping = (try? await courseMappingStore?.allMappings()) ?? [:]
            let fresh = PipelineWiring.makeScheduleAwareOrchestrator(
                modelPath: SmallEnDownloader.modelStoragePath,
                vaultRoot: HardcodedVaultResolver.vaultRoot,
                termLabel: currentTermLabel,
                mapping: mapping
            )
            self.currentOrchestrator = fresh

            // Phase 4 gap 2: Start observing orchestrator state for .awaitingUserChoice.
            self.startObservingOrchestratorState()

            // Per TRAN-03: run transcription off MainActor.
            guard let orchestrator = self.orchestrator else {
                sessionState = .error("Pipeline orchestrator not available.")
                return
            }
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
        stateObserverTask?.cancel()
        stateObserverTask = nil
        if let orchestrator {
            await orchestrator.reset()
        }
        await session.reset()
        sessionState = .idle
        overlayState = .none
        elapsedTime = 0
        micLevel = -160
        waveformBuffer = []
        pauseCount = 0
        totalPausedSeconds = 0
        recordingStartDate = nil
        pendingEvents = []
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

    // MARK: - Phase 4: Calendar Permission

    /// Requests calendar Full Access permission.
    ///
    /// Per P-02: fires on first recording alongside mic permission.
    /// Per P-05: verifies .fullAccess explicitly — .writeOnly treated as denied.
    func requestCalendarPermission() async {
        guard let provider = calendarProvider else {
            calendarPermission = .denied
            return
        }

        do {
            let granted = try await provider.requestFullAccess()
            if granted {
                calendarPermission = .granted
            } else {
                calendarPermission = .denied
            }
        } catch {
            calendarPermission = .denied
        }
    }

    /// Checks the current calendar permission status without requesting.
    ///
    /// Updates `calendarPermission` based on the current system state.
    /// Useful for detecting permission changes when the app becomes active.
    func checkCalendarPermission() async {
        guard let provider = calendarProvider else {
            calendarPermission = .denied
            return
        }

        let status = await provider.checkAuthorization()
        calendarPermission = PermissionState.from(status)
    }

    // MARK: - Phase 4: Classification Pause/Resume

    /// Called when the orchestrator reaches `.awaitingUserChoice`.
    ///
    /// Per MP-04: Creates a CoursePickerViewModel with mode based on match
    /// (.multiple or .none), loaded courses from CourseMappingStore, and
    /// recent codes. Sets `overlayState = .coursePicker(mode)`.
    func handleClassificationPause(match: CourseMatch) async {
        let mode: CoursePickerMode
        switch match {
        case .none:
            mode = .none
        case .multiple(let events):
            mode = .multiple(events)
        case .single:
            // .single should not reach here — the orchestrator auto-resolves.
            overlayState = .none
            return
        }

        // Load courses and recent codes from the mapping store.
        let mappings: [String: CourseMapping]
        let recentCodes: [String]
        if let store = courseMappingStore {
            mappings = (try? await store.allMappings()) ?? [:]
            recentCodes = (try? await store.allRecentCourses()) ?? []
        } else {
            mappings = [:]
            recentCodes = []
        }

        let courses: [CourseSummary] = mappings.values.map { mapping in
            CourseSummary(code: mapping.courseCode, name: mapping.courseName)
        }

        coursePickerViewModel = CoursePickerViewModel(
            mode: mode,
            courses: courses,
            recentCodes: recentCodes
        )

        overlayState = .coursePicker(mode)
    }

    /// Converts CourseSelection to a CalendarEvent and resumes the orchestrator.
    ///
    /// Per M-03: Manual pick updates BOTH mapping AND recent list in courses.json.
    /// Per MP-03: Skip routes to _unsorted via orchestrator.skipClassification().
    func selectCourse(_ selection: CourseSelection) async {
        switch selection {
        case .course(let code):
            let event = CalendarEvent(
                id: code,
                title: code,
                startDate: Date(),
                endDate: Date()
            )
            await updateMappingAndRecent(code: code, name: code)
            await overlayOrchestrator?.resume(with: event)

        case .event(let event):
            await updateMappingAndRecent(code: event.title, name: event.title)
            await overlayOrchestrator?.resume(with: event)

        case .newCourse(let code, let name):
            let event = CalendarEvent(
                id: code,
                title: code,
                startDate: Date(),
                endDate: Date()
            )
            // Update mapping for the new course.
            if let store = courseMappingStore {
                try? await store.upsert(
                    eventTitle: code,
                    mapping: CourseMapping(courseCode: code, courseName: name)
                )
                try? await store.addRecent(courseCode: code)
            }
            await overlayOrchestrator?.resume(with: event)

        case .skip:
            await overlayOrchestrator?.skipClassification()
        }

        overlayState = .none
    }

    /// Skips classification and routes to _unsorted.
    ///
    /// Per MP-03: Calls orchestrator.skipClassification() and resets overlay.
    func skipClassification() async {
        await overlayOrchestrator?.skipClassification()
        overlayState = .none
    }

    // MARK: - Phase 4: System Settings Deep-Link

    /// Opens macOS System Settings to Privacy > Calendars.
    ///
    /// Per RESEARCH.md Pattern 5: Uses NSWorkspace.open with the
    /// `x-apple.systempreferences:` URL scheme.
    func openSystemSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    // MARK: - Phase 4: Term Management

    /// Sets the current term label and date range.
    ///
    /// Per CT-01: Updates CourseMappingStore and refreshes local state.
    func setTerm(label: String, startDate: Date, endDate: Date) async {
        try? await courseMappingStore?.setCurrentTerm(
            label: label,
            startDate: startDate,
            endDate: endDate
        )
        currentTermLabel = label
        termHasExpired = endDate < Date()
    }

    /// Loads the current term from CourseMappingStore and updates local state.
    func loadCurrentTerm() async {
        guard let store = courseMappingStore else { return }
        do {
            let term = try await store.currentTerm()
            currentTermLabel = term.label
            termHasExpired = term.endDate < Date()
        } catch {
            currentTermLabel = ""
            termHasExpired = false
        }
    }

    // MARK: - Phase 4: Private Helpers

    /// Starts polling orchestrator.currentState for the .awaitingUserChoice
    /// transition (Phase 4 gap 2).
    ///
    /// Per T-04-06-01: The observer self-terminates after firing
    /// handleClassificationPause (its sole job). It is also cancelled in
    /// onTranscriptionComplete, onTranscriptionError, and dismissCompletion.
    private func startObservingOrchestratorState() {
        stateObserverTask?.cancel()
        stateObserverTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                // Poll the current orchestrator's state.
                let state: PipelineState?
                if let orch = self.orchestrator {
                    state = await orch.currentState
                } else {
                    state = nil
                }

                if case .awaitingUserChoice = state {
                    // Reconstruct the CourseMatch from pendingEvents.
                    let match: CourseMatch
                    if self.pendingEvents.count >= 2 {
                        match = .multiple(self.pendingEvents)
                    } else {
                        match = .none
                    }

                    self.stateObserverTask?.cancel()
                    await self.handleClassificationPause(match: match)
                    return
                }

                // Poll every 100ms — state transitions are fast but not frame-critical.
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    // MARK: - Phase 4: Picker Data Exposure (Gap 3)

    /// Recent courses from the CoursePickerViewModel for CoursePickerView.
    var pickerRecentCourses: [CourseSummary] {
        coursePickerViewModel?.recentCourses ?? []
    }

    /// Filtered courses from the CoursePickerViewModel for CoursePickerView.
    var pickerFilteredCourses: [CourseSummary] {
        coursePickerViewModel?.filteredCourses ?? []
    }

    /// Search query from the CoursePickerViewModel for CoursePickerView.
    var pickerSearchQuery: String {
        coursePickerViewModel?.searchQuery ?? ""
    }

    // MARK: - Phase 4: Mappings Loader for ManageCoursesView (Gap 4)

    /// Loads all course mappings from CourseMappingStore.
    ///
    /// Used by ManageCoursesView to display real data from courses.json.
    func loadAllMappings() async -> [String: CourseMapping] {
        guard let store = courseMappingStore else { return [:] }
        return (try? await store.allMappings()) ?? [:]
    }

    /// Deletes a mapping via CourseMappingStore (M-04).
    ///
    /// Called by ManageCoursesView.deleteMapping to persist deletions.
    func deleteMapping(eventTitle: String) async {
        try? await courseMappingStore?.deleteMapping(eventTitle: eventTitle)
    }

    /// Adds a mapping via CourseMappingStore (M-04).
    ///
    /// Called by ManageCoursesView.addMapping to persist new mappings.
    func addMapping(eventTitle: String, code: String, name: String) async {
        try? await courseMappingStore?.upsert(
            eventTitle: eventTitle,
            mapping: CourseMapping(courseCode: code, courseName: name)
        )
    }

    /// Updates mapping and recent list for a course selection (M-03).
    private func updateMappingAndRecent(code: String, name: String) async {
        guard let store = courseMappingStore else { return }
        try? await store.upsert(
            eventTitle: code,
            mapping: CourseMapping(courseCode: code, courseName: name)
        )
        try? await store.addRecent(courseCode: code)
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
        stateObserverTask?.cancel()
        stateObserverTask = nil
        sessionState = .completed
        fireCompletionNotification()
    }

    /// Called when transcription fails.
    private func onTranscriptionError(_ error: Error) {
        stopPolling()
        stateObserverTask?.cancel()
        stateObserverTask = nil
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

    // MARK: - Phase 5: iCloud Inbox Monitoring

    /// Inbox watcher for detecting new `_inbox/` files via NSMetadataQuery (TRIG-01).
    #if os(macOS)
    private var inboxWatcher: InboxWatcher?
    private var inboxQueue: InboxQueue?
    private var inboxDeadLetterHandler: DeadLetterHandler?
    private var inboxFileDownloader = InboxFileDownloader()
    private var inboxProcessingTask: Task<Void, Never>?
    private var failedRecordingURL: URL?

    /// Starts monitoring the vault `_inbox/` folder for iCloud handoff files.
    ///
    /// Per TRIG-01: creates an InboxWatcher pointed at `{vault}/_inbox/`,
    /// performs a launch scan, then starts live NSMetadataQuery monitoring.
    /// Discovered files are enqueued and processed one at a time (TRIG-02).
    ///
    /// - Parameter vaultURL: The root vault URL (from BookmarkStore).
    func startInboxMonitoring(vaultURL: URL) {
        let inboxURL = vaultURL.appendingPathComponent("_inbox")

        // Create _inbox/ if it doesn't exist
        try? FileManager.default.createDirectory(
            at: inboxURL,
            withIntermediateDirectories: true
        )

        let queue = InboxQueue()
        let deadLetter = DeadLetterHandler()
        inboxQueue = queue
        inboxDeadLetterHandler = deadLetter

        let watcher = InboxWatcher(inboxURL: inboxURL) { [weak self] newFiles in
            guard let self else { return }
            Task { @MainActor in
                for file in newFiles {
                    await queue.enqueue(file)
                }
                self.inboxPendingCount = await queue.pendingCount
                await self.processNextInboxFileIfNeeded(vaultURL: vaultURL)
            }
        }

        watcher.start()
        inboxWatcher = watcher
    }

    /// Stops inbox monitoring.
    func stopInboxMonitoring() {
        inboxWatcher?.stop()
        inboxWatcher = nil
        inboxProcessingTask?.cancel()
        inboxProcessingTask = nil
    }

    /// Processes the next inbox file if the queue is not already processing.
    ///
    /// Per TRIG-02: one file at a time. Checks IC-04 download status,
    /// runs the full pipeline, moves audio on success (TRIG-03), or
    /// schedules retry/dead-letter on failure (TRIG-04).
    private func processNextInboxFileIfNeeded(vaultURL: URL) async {
        guard let queue = inboxQueue else { return }

        // Don't start if already processing
        let isProcessing = await queue.processing
        guard !isProcessing else { return }

        guard let fileURL = try? await queue.processNext() else {
            inboxPendingCount = 0
            inboxProcessingState = .idle
            return
        }

        inboxPendingCount = await queue.pendingCount
        inboxProcessingState = .downloading(filename: fileURL.lastPathComponent, progress: 0)

        // IC-04: check if file needs download (.icloud placeholder)
        let status = inboxFileDownloader.checkFileStatus(at: fileURL)
        if status == .downloadNeeded {
            inboxProcessingState = .downloading(
                filename: fileURL.lastPathComponent,
                progress: 0
            )
            do {
                try await inboxFileDownloader.startDownload(at: fileURL)
            } catch {
                // Download failed — record failure for retry/dead-letter
                await handleInboxFailure(
                    fileURL: fileURL,
                    vaultURL: vaultURL,
                    error: .downloadTimedOut(fileURL)
                )
                return
            }
        }

        // TRIG-02/03: run the full pipeline on the downloaded file
        inboxProcessingState = .transcribing(filename: fileURL.lastPathComponent)

        let recordingStart = PipelineWiring.parseRecordingStart(from: fileURL)
        let mapping = (try? await courseMappingStore?.allMappings()) ?? [:]
        let events: [CalendarEvent] = []
        let duration = computeAudioDuration(at: fileURL) ?? 0

        do {
            _ = try await PipelineWiring.processInboxFile(
                at: fileURL,
                vaultRoot: vaultURL,
                termLabel: currentTermLabel,
                mapping: mapping,
                recordingStart: recordingStart,
                events: events,
                durationSeconds: duration
            )

            // Success — mark complete and process next
            await queue.markComplete()
            inboxProcessingState = .idle
            await processNextInboxFileIfNeeded(vaultURL: vaultURL)
        } catch {
            await handleInboxFailure(
                fileURL: fileURL,
                vaultURL: vaultURL,
                error: .pipelineFailed(fileURL, underlying: error)
            )
        }
    }

    /// Handles a pipeline failure for an inbox file (TRIG-04).
    ///
    /// Records the failure with the DeadLetterHandler, which either schedules
    /// a retry or dead-letters the file to `_failed/`.
    private func handleInboxFailure(
        fileURL: URL,
        vaultURL: URL,
        error: InboxError
    ) async {
        guard let queue = inboxQueue,
              let deadLetter = inboxDeadLetterHandler else { return }

        let inboxRoot = vaultURL.appendingPathComponent("_inbox")
        let outcome = await deadLetter.recordFailure(
            for: fileURL,
            inboxRoot: inboxRoot,
            error: error
        )

        await queue.markComplete()

        switch outcome {
        case .retryScheduled:
            // Per TRIG-04: schedule a retry after backoff.
            // The retry count and backoff are tracked by DeadLetterHandler.
            // We re-enqueue after a delay.
            let retryCount = await deadLetter.retryCount(for: fileURL)
            let backoffIndex = min(retryCount - 1, DeadLetterHandler.backoffSchedule.count - 1)
            let delay = DeadLetterHandler.backoffSchedule[max(0, backoffIndex)]

            inboxProcessingState = .idle
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await queue.enqueue(fileURL)
                await self?.processNextInboxFileIfNeeded(vaultURL: vaultURL)
            }

        case .deadLettered:
            // TRIG-04: file dead-lettered to _failed/
            failedRecordingURL = inboxRoot.appendingPathComponent("_failed")
                .appendingPathComponent(fileURL.lastPathComponent)
            inboxProcessingState = .failed(
                filename: fileURL.lastPathComponent,
                errorSummary: error.errorMessage
            )
        }
    }

    /// Retries a previously dead-lettered recording (UI-SPEC Surface 4).
    ///
    /// Moves the file from `_failed/` back to `_inbox/` and re-enqueues.
    func retryFailedRecording() async {
        guard let failedURL = failedRecordingURL else { return }
        let inboxRoot = failedURL.deletingLastPathComponent().deletingLastPathComponent()
        let filename = failedURL.lastPathComponent
        let destURL = inboxRoot.appendingPathComponent(filename)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: failedURL, to: destURL)

            // Remove the sidecar
            let sidecar = failedURL.appendingPathComponent(".error.json")
            try? FileManager.default.removeItem(at: sidecar)

            // Reset retries and re-enqueue
            await inboxDeadLetterHandler?.resetRetries(for: destURL)
            if let queue = inboxQueue {
                await queue.enqueue(destURL)
                failedRecordingURL = nil
                inboxProcessingState = .idle

                let vaultRoot = inboxRoot.deletingLastPathComponent()
                await processNextInboxFileIfNeeded(vaultURL: vaultRoot)
            }
        } catch {
            // Retry move failed — keep the failure state
        }
    }

    /// Deletes a dead-lettered recording permanently (UI-SPEC Surface 4).
    ///
    /// Removes the audio file and its `.error.json` sidecar.
    func deleteFailedRecording() async {
        guard let failedURL = failedRecordingURL else { return }
        try? FileManager.default.removeItem(at: failedURL)
        let sidecar = URL(fileURLWithPath: failedURL.path + ".error.json")
        try? FileManager.default.removeItem(at: sidecar)
        failedRecordingURL = nil
        inboxProcessingState = .idle
    }

    /// Computes the audio file duration in seconds from AVAudioSession.
    ///
    /// Returns nil if the duration cannot be determined (the pipeline will
    /// use 0 as a fallback).
    private func computeAudioDuration(at url: URL) -> Int? {
        #if canImport(AVFoundation)
        if let asset = try? AVURLAsset(url: url) {
            let duration = CMTimeGetSeconds(asset.duration)
            return Int(duration)
        }
        #endif
        return nil
    }
    #endif // os(macOS)
}

// MARK: - InboxProcessingState

/// Display state for the iCloud inbox queue processing (UI-SPEC Surface 4).
///
/// Drives the macOS popover inbox progress rendering:
/// - `.idle`: no inbox activity
/// - `.downloading`: IC-04 active iCloud download in progress
/// - `.transcribing`: pipeline is transcribing + classifying + writing
/// - `.failed`: file dead-lettered after 3 retries (TRIG-04)
enum InboxProcessingState: Equatable {
    case idle
    case downloading(filename: String, progress: Double)
    case transcribing(filename: String)
    case failed(filename: String, errorSummary: String)

    static func == (lhs: InboxProcessingState, rhs: InboxProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.downloading(let a), .downloading(let b)):
            return a.filename == b.filename && a.progress == b.progress
        case (.transcribing(let a), .transcribing(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a.filename == b.filename && a.errorSummary == b.errorSummary
        default:
            return false
        }
    }
}
