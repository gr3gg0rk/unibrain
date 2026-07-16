import SwiftUI
import UnibrainCore

// MARK: - MenuBarPopover

/// SwiftUI view rendering all menu-bar popover states.
///
/// Per P-08..P-12 and the 03-UI-SPEC: renders idle, recording, paused,
/// transcribing, and error states with the correct layout, typography,
/// and interaction contracts.
///
/// Per P-D5: waveform uses Canvas inside TimelineView for efficient rendering.
///
/// Per Phase 4 Pitfall 2 (FB11984872): The body switches on
/// `viewModel.overlayState` FIRST. If overlayState is not .none, render the
/// overlay view inline. If .none, fall through to the existing sessionState switch.
/// This replaces `.sheet` which is unreliable on MenuBarExtra(.window).
struct MenuBarPopover: View {
    @Bindable var viewModel: MenuBarViewModel

    var body: some View {
        switch viewModel.overlayState {
        case .none:
            mainContent
        case .coursePicker(let mode):
            CoursePickerView(mode: mode, viewModel: viewModel)
        case .manageCourses:
            ManageCoursesView(viewModel: viewModel)
        case .permissionDenied:
            PermissionDeniedSheet(viewModel: viewModel)
        case .termEditor:
            TermEditorForm(viewModel: viewModel)
        }
    }

    // MARK: - Main Content (session state switch)

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.sessionState {
        case .idle:
            idleState
        case .recording:
            recordingState
        case .paused:
            pausedState
        case .transcribing:
            transcribingState
        case .awaitingCourseSelection:
            ClassificationPausedView(viewModel: viewModel)
        case .completed:
            completedState
        case .error(let message):
            errorState(message)
        }
    }

    // MARK: - iCloud Inbox Processing States (UI-SPEC Surface 4)

    @ViewBuilder
    private var inboxProcessingView: some View {
        switch viewModel.inboxProcessingState {
        case .idle:
            EmptyView()
        case .downloading(let filename, let progress):
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Downloading iPhone recording…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressView(value: progress)
                    .controlSize(.small)
                if viewModel.inboxPendingCount > 0 {
                    Text("Queue: \(viewModel.inboxPendingCount) more pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .transcribing(let filename):
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Transcribing iPhone recording…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Est. ~3 min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if viewModel.inboxPendingCount > 0 {
                    Text("Queue: \(viewModel.inboxPendingCount) more pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .failed(let filename, let errorSummary):
            VStack(spacing: 8) {
                Label("Recording failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Failed after 3 retries. Saved to `_inbox/_failed/`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.retryFailedRecording() }
                    } label: {
                        Text("Retry")
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await viewModel.deleteFailedRecording() }
                    } label: {
                        Text("Delete")
                    }
                    .controlSize(.small)
                    .tint(.red)
                }
            }
        }
    }

    // MARK: - Idle State (P-10 + Phase 4 extensions)

    private var idleState: some View {
        VStack(spacing: 16) {
            // Phase 4: Permission banner (if calendar denied and overlay shown before)
            if viewModel.calendarPermission == .denied && viewModel.hasShownPermissionOverlay {
                PermissionBanner(viewModel: viewModel)
            }

            // Phase 4: Term-expired banner (mutually exclusive with permission banner)
            if viewModel.calendarPermission != .denied && viewModel.termHasExpired {
                TermExpiredBanner(viewModel: viewModel)
            }

            VStack(spacing: 8) {
                Text("Ready to record")
                    .font(.body)
                    .foregroundStyle(.secondary)

                // Model status line
                if viewModel.isModelReady {
                    Label("small.en model downloaded", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if let progress = viewModel.downloadProgress {
                    Label(
                        "Fallback model: downloading (\(Int(progress * 100))%)",
                        systemImage: "arrow.down.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Label("Fallback model: not downloaded", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                // Microphone permission status
                Label("Microphone available", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                // Phase 4: Calendar status line
                if viewModel.calendarPermission == .granted {
                    Label("Calendar connected", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if viewModel.calendarPermission == .denied {
                    Label("Calendar off \u{2014} manual pick", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Phase 5: iCloud inbox pending count (UI-SPEC Surface 4)
            if viewModel.inboxPendingCount > 0 {
                HStack(spacing: 4) {
                    Label("iCloud Inbox: \(viewModel.inboxPendingCount) pending", systemImage: "icloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Phase 5: Inbox processing states (downloading/transcribing/failed)
            if viewModel.inboxProcessingState != .idle {
                inboxProcessingView
            }

            Button {
                Task {
                    await viewModel.requestMicrophonePermission()
                    await viewModel.startRecording()
                }
            } label: {
                Label("Record", systemImage: "mic.fill")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Start recording")

            // Phase 4/5: Term label + Manage Courses + Manage Permissions buttons
            VStack(spacing: 8) {
                if !viewModel.currentTermLabel.isEmpty {
                    Text("Term: \(viewModel.currentTermLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button {
                        viewModel.overlayState = .manageCourses
                    } label: {
                        Label("Manage Courses", systemImage: "folder.badge.gearshape")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // Phase 5: Manage Permissions button (ONBD-05)
                    Button {
                        // Per UI-SPEC: presents PermissionsSheet
                        // Wire to sheet presentation in parent view
                        viewModel.showPermissionsSheet()
                    } label: {
                        Label("Manage Permissions", systemImage: "lock.shield")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(24)
    }

    // MARK: - Recording State (P-09)

    private var recordingState: some View {
        VStack(spacing: 16) {
            // Timer (CAPT-04)
            Text(timeString(viewModel.elapsedTime))
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)

            // Live waveform (P-D5: Canvas inside TimelineView)
            waveformView
                .frame(height: 48)

            // Mic level meter (CAPT-05)
            micMeterView(level: viewModel.micLevel)

            // Buttons
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.pauseRecording() }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .controlSize(.regular)
                .accessibilityLabel("Pause recording")

                Button {
                    Task { await viewModel.stopRecording() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .controlSize(.regular)
                .tint(.red)
                .accessibilityLabel("Stop recording and transcribe")
            }
        }
        .padding(24)
    }

    // MARK: - Paused State (P-12)

    private var pausedState: some View {
        VStack(spacing: 16) {
            // Frozen timer
            Text(timeString(viewModel.elapsedTime))
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            // Dimmed frozen waveform
            waveformView
                .frame(height: 48)
                .opacity(0.4)

            // Empty mic meter
            micMeterView(level: -160)

            // Paused summary
            Text("Paused — \(viewModel.pauseCount) pauses, \(Int(viewModel.totalPausedSeconds))s total")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Buttons
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.resumeRecording() }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Resume recording")

                Button {
                    Task { await viewModel.stopRecording() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .controlSize(.regular)
                .tint(.red)
                .accessibilityLabel("Stop recording and transcribe")
            }
        }
        .padding(24)
    }

    // MARK: - Transcribing State (P-11)

    private var transcribingState: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Transcribing…")
                    .font(.headline)
            }

            // ETA estimate (rough: ~3x realtime for whisper.cpp, ~1x for SpeechAnalyzer)
            Text("Est. ~\(max(1, Int(viewModel.elapsedTime / 20))) min")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                // Disabled — enforces O-02 no concurrent run
            } label: {
                Label("Record", systemImage: "mic.fill")
            }
            .controlSize(.large)
            .disabled(true)
        }
        .padding(24)
    }

    // MARK: - Completed State

    private var completedState: some View {
        VStack(spacing: 16) {
            Label("Transcript ready", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text("Opened in vault")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await viewModel.dismissCompletion() }
            } label: {
                Text("Done")
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    // MARK: - Error State (P-18)

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.dismissCompletion() }
            } label: {
                Text("Dismiss")
            }
            .controlSize(.regular)
        }
        .padding(24)
    }

    // MARK: - Waveform View (P-D5)

    /// Canvas-based live waveform rendering.
    ///
    /// Per P-D5: uses Canvas inside TimelineView for efficient rendering.
    /// Reads pre-computed waveformBuffer from the view model — MainActor
    /// only renders, does not compute.
    private var waveformView: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard !viewModel.waveformBuffer.isEmpty else { return }

                let barWidth: CGFloat = 3
                let spacing: CGFloat = 2
                let totalBarWidth = barWidth + spacing
                let maxBars = Int(size.width / totalBarWidth)
                let barCount = min(maxBars, viewModel.waveformBuffer.count)

                // Center the waveform vertically
                let centerY = size.height / 2

                // Draw 2-row retro-style amplitude bars
                for index in 0..<barCount {
                    let level = viewModel.waveformBuffer[viewModel.waveformBuffer.count - barCount + index]
                    // Map dB (-160 to 0) to amplitude (0 to 1)
                    let amplitude = normalizeLevel(level)
                    let barHeight = max(2, CGFloat(amplitude) * size.height * 0.45)

                    let x = CGFloat(index) * totalBarWidth
                    let rect = CGRect(
                        x: x,
                        y: centerY - barHeight,
                        width: barWidth,
                        height: barHeight * 2
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .color(.accentColor)
                    )
                }
            }
        }
    }

    // MARK: - Mic Meter View (CAPT-05)

    /// 3-segment mic level meter: green (healthy) / yellow (approaching clip) / red (clipping).
    ///
    /// Per CAPT-05: confirms lecturer is audible without extra clicks.
    private func micMeterView(level: Float) -> some View {
        let amplitude = normalizeLevel(level)

        return GeometryReader { geometry in
            HStack(spacing: 2) {
                // Green segment (0% - 60%)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .opacity(amplitude > 0.0 ? 1.0 : 0.2)
                    .frame(width: geometry.size.width * 0.33)

                // Yellow segment (60% - 85%)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.yellow)
                    .opacity(amplitude > 0.6 ? 1.0 : 0.2)
                    .frame(width: geometry.size.width * 0.33)

                // Red segment (85% - 100%)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .opacity(amplitude > 0.85 ? 1.0 : 0.2)
                    .frame(width: geometry.size.width * 0.33)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Helper Functions

    /// Formats seconds as HH:MM:SS with monospaced digits.
    private func timeString(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    /// Normalizes a dB level (-160 to 0) to a 0.0-1.0 amplitude range.
    ///
    /// -160 dB = silence (0.0), 0 dB = clipping (1.0).
    private func normalizeLevel(_ level: Float) -> Float {
        // Map -160..0 dB to 0..1
        let clamped = max(-160, min(0, level))
        return (clamped + 160) / 160
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Idle") {
    MenuBarPopover(viewModel: MenuBarViewModel(
        session: PipelineWiring.makeRecordingSession(),
        orchestrator: PipelineWiring.makeOrchestrator(
            modelPath: SmallEnDownloader.modelStoragePath
        ),
        downloader: SmallEnDownloader()
    ))
    .frame(width: 280)
}
#endif
