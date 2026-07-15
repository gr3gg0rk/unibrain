import SwiftUI
import UserNotifications
import UnibrainProviders

// MARK: - UnibrainApp

/// Main app entry point.
///
/// Per P-08: the menu-bar popover IS the primary recording surface.
/// The WindowGroup is minimal — app state indicator + future Settings (Phase 6).
///
/// Per P-D3: the menu-bar icon changes based on session state.
///
/// Per P-17: background model download starts automatically on first launch.
@main
struct UnibrainApp: App {

    // MARK: - State

    @State private var viewModel: MenuBarViewModel
    @State private var modelDownloader: SmallEnDownloader

    // MARK: - Init

    init() {
        let downloader = SmallEnDownloader()
        let modelPath = SmallEnDownloader.modelStoragePath
        let orchestrator = PipelineWiring.makeOrchestrator(modelPath: modelPath)
        let session = PipelineWiring.makeRecordingSession()

        _viewModel = State(
            initialValue: MenuBarViewModel(
                session: session,
                orchestrator: orchestrator,
                downloader: downloader
            )
        )
        _modelDownloader = State(initialValue: downloader)
    }

    // MARK: - Body

    var body: some Scene {
        // Per P-08: minimal WindowGroup — future Settings entry point (Phase 6)
        WindowGroup {
            ContentView(viewModel: viewModel)
                .task {
                    // Per P-17: start background model download on first launch
                    await modelDownloader.startDownload()
                }
                .task {
                    // Request notification permission for transcription completion alerts (P-11)
                    await requestNotificationPermission()
                }
        }

        #if os(macOS)
        // Per P-08: MenuBarExtra is the PRIMARY recording surface
        // Per P-D3: icon changes based on session state
        MenuBarExtra {
            MenuBarPopover(viewModel: viewModel)
                .frame(width: 280)
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    // MARK: - Menu Bar Icon (P-D3)

    /// State-driven menu-bar icon per P-D3:
    /// - Idle: brain (secondary)
    /// - Recording: brain.fill (red)
    /// - Paused: brain.fill (yellow)
    /// - Transcribing: brain.fill (accent)
    /// - Completed/Error: brain (secondary)
    @ViewBuilder
    private var menuBarIcon: some View {
        switch viewModel.sessionState {
        case .idle:
            Image(systemName: "brain")
                .foregroundStyle(.secondary)
        case .recording:
            Image(systemName: "brain.fill")
                .foregroundStyle(.red)
        case .paused:
            Image(systemName: "brain.fill")
                .foregroundStyle(.yellow)
        case .transcribing:
            Image(systemName: "brain.fill")
                .foregroundStyle(.accentColor)
        case .completed, .error:
            Image(systemName: "brain")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Notification Permission

    /// Requests notification permission for transcription completion alerts.
    ///
    /// Per P-11: macOS system notification fires when transcription completes.
    /// This requests `.alert` permission on first launch.
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            if !granted {
                // User denied — notifications won't fire, but the app still works.
                // The popover state transition to .completed serves as fallback feedback.
            }
        } catch {
            // Non-critical — notification errors don't block recording.
        }
    }
}
