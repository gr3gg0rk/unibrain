import SwiftUI

/// Onboarding wizard shell — page-style TabView with progress dots.
///
/// Per ONB-02 and RESEARCH.md Pattern 6: Uses `TabView` with
/// `.tabViewStyle(.page(indexDisplayMode: .always))` and
/// `.indexViewStyle(.page(backgroundDisplayMode: .always))`.
///
/// Per ONB-01: macOS gets 6 pages (Welcome, Vault, Mic, Calendar, Term, Ready).
/// iOS gets 5 pages (Term skipped — inherited via courses.json).
///
/// The `@Bindable var viewModel` drives page state and all wizard actions.
struct OnboardingFlow: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        TabView(selection: $viewModel.currentPage) {
            OnboardingWelcomePage()
                .tag(0)

            OnboardingVaultPage(viewModel: viewModel)
                .tag(1)

            OnboardingMicPage(viewModel: viewModel)
                .tag(2)

            OnboardingCalendarPage(viewModel: viewModel)
                .tag(3)

            #if os(macOS)
            OnboardingTermPage(viewModel: viewModel)
                .tag(4)

            OnboardingReadyPage(viewModel: viewModel)
                .tag(5)
            #else
            OnboardingReadyPage(viewModel: viewModel)
                .tag(4)
            #endif
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        #if os(macOS)
        .frame(width: 480, height: 600)
        #endif
    }
}
