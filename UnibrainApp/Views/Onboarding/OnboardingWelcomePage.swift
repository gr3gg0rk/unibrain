import SwiftUI

/// Onboarding page 1: Welcome.
///
/// Per UI-SPEC Surface 1 Page 1: App icon centered, "unibrain" in largeTitle,
/// value prop text, "Get Started" button advancing to page 2.
struct OnboardingWelcomePage: View {

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            #if os(macOS)
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
            #else
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 72))
                .foregroundStyle(.accentColor)
            #endif

            // App name
            Text("unibrain")
                #if os(iOS)
                .font(.largeTitle)
                #else
                .font(.title)
                #endif
                .fontWeight(.semibold)

            // Value prop
            Text("Every recording lands in the right course folder, automatically.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Get Started button advances the TabView via tag/binding in parent.
            // The parent's TabView binding is driven by currentPage.
            // Since Welcome is page 0, we use a hint to the user.
            Text("Swipe or tap Get Started to begin")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}
