import SwiftUI

#if os(iOS)

/// iOS app shell with three-tab TabView per IOS-01 and UI-SPEC Surface 2.
///
/// Per IOS-01: TabView with Record (mic.fill), Recent (clock.arrow.circlepath),
/// Settings (gearshape). Default tab selection is Record (index 0).
///
/// Rendered by UnibrainApp.swift when hasCompletedOnboarding == true on iOS.
struct iOSTabView: View {

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            iOSRecordTab()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .tag(0)

            iOSRecentTab()
                .tabItem {
                    Label("Recent", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)

            iOSSettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
    }
}

#endif
