import SwiftUI
import UserNotifications
import UnibrainCore
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
///
/// Per Phase 4: injects CourseMappingStore and EventKitCalendarAdapter into
/// MenuBarViewModel for calendar-driven course routing.
///
/// Per Phase 5 ONBD-01: conditionally renders OnboardingFlow when
/// `hasCompletedOnboarding` is false.
@main
struct UnibrainApp: App {

    // MARK: - State

    #if os(macOS)
    @State private var viewModel: MenuBarViewModel
    @State private var modelDownloader: SmallEnDownloader

    /// Phase 06-05 SET-01: Shared selected-tab state for context-aware
    /// Settings opening (CF-04 → Audit; permission warning → Permissions).
    @State private var settingsSelectedTab: SettingsTab = .general

    /// Phase 06-05 SET-01: Triggers Settings window presentation.
    @State private var openSettingsRequest: Bool = false
    #endif

    /// Per ONBD-01: controls onboarding vs main UI rendering.
    @AppStorage(OnboardingViewModel.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false

    /// Onboarding view model created for the wizard flow.
    @State private var onboardingViewModel: OnboardingViewModel?

    // MARK: - Init

    init() {
        // Per Pitfall 6 (RESEARCH.md): PipelineWiring, HardcodedVaultResolver,
        // NSFileCoordinatorNoteWriter, and ScheduleAwareVaultResolver are all
        // macOS-only. iOS app does NOT need the pipeline — iPhone is capture-only.
        // iOS init only needs RecordingSession + CourseMappingStore + EventKitCalendarAdapter.
        #if os(macOS)
        let downloader = SmallEnDownloader()
        let modelPath = SmallEnDownloader.modelStoragePath

        // Phase 4: Create CourseMappingStore with vault root.
        let courseMappingStore = CourseMappingStore(
            vaultRoot: HardcodedVaultResolver.vaultRoot
        )

        let orchestrator = PipelineWiring.makeScheduleAwareOrchestrator(
            modelPath: modelPath,
            vaultRoot: HardcodedVaultResolver.vaultRoot,
            termLabel: "",
            mapping: [:]
        )
        let session = PipelineWiring.makeRecordingSession()

        let calendarProvider: any CalendarEventProvider = EventKitCalendarAdapter()

        _viewModel = State(
            initialValue: MenuBarViewModel(
                session: session,
                orchestrator: orchestrator,
                downloader: downloader,
                courseMappingStore: courseMappingStore,
                calendarProvider: calendarProvider
            )
        )
        _modelDownloader = State(initialValue: downloader)
        #endif
    }

    // MARK: - Body

    var body: some Scene {
        // Per P-08: minimal WindowGroup — future Settings entry point (Phase 6)
        WindowGroup {
            if hasCompletedOnboarding {
                #if os(iOS)
                // Per IOS-01: iOS renders iOSTabView when onboarding is complete.
                iOSTabView()
                #else
                ContentView(viewModel: viewModel)
                    .task {
                        // Per P-17: start background model download on first launch
                        await modelDownloader.startDownload()
                    }
                    .task {
                        // Request notification permission for transcription completion alerts (P-11)
                        await requestNotificationPermission()
                    }
                    .task {
                        // Phase 4: Check calendar permission and load term on launch (P-02)
                        await viewModel.checkCalendarPermission()
                        await viewModel.loadCurrentTerm()
                    }
                #endif
            } else {
                // Per ONBD-01: show onboarding on first launch.
                OnboardingFlow(viewModel: makeOnboardingViewModel())
            }
        }

        #if os(macOS)
        // Per P-08: MenuBarExtra is the PRIMARY recording surface
        // Per P-D3: icon changes based on session state.
        // Per ONBD-01: hidden during onboarding.
        MenuBarExtra {
            if hasCompletedOnboarding {
                MenuBarPopover(
                    viewModel: viewModel,
                    settingsSelectedTab: $settingsSelectedTab
                )
                .frame(width: 280)
            }
        } label: {
            if hasCompletedOnboarding {
                menuBarIcon
            } else {
                // During onboarding, show a dim icon.
                Image(systemName: "brain")
                    .foregroundStyle(.secondary)
            }
        }
        .menuBarExtraStyle(.window)
        #endif

        #if os(macOS)
        // Phase 06-05 SET-01: dedicated macOS Settings scene.
        // Per SET-02: 5-tab layout (General/Providers/Courses/Permissions/Audit).
        // Per SET-04: context-aware opening via `settingsSelectedTab` binding.
        Settings {
            SettingsScene(selectedTab: $settingsSelectedTab)
        }
        #endif
    }

    // MARK: - Onboarding VM Factory

    /// Creates the OnboardingViewModel with CourseMappingStore for term saving.
    private func makeOnboardingViewModel() -> OnboardingViewModel {
        if let existing = onboardingViewModel {
            return existing
        }
        #if os(macOS)
        let vm = OnboardingViewModel(
            courseMappingStore: CourseMappingStore(
                vaultRoot: HardcodedVaultResolver.vaultRoot
            )
        )
        #else
        // iOS: vault root is resolved from BookmarkStore after onboarding folder pick.
        // CourseMappingStore is nil during onboarding; loaded post-onboarding.
        let vm = OnboardingViewModel()
        #endif
        onboardingViewModel = vm
        return vm
    }

    // MARK: - Menu Bar Icon (P-D3)

    #if os(macOS)
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
    #endif

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
