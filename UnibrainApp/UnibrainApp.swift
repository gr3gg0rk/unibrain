import SwiftUI

@main
struct UnibrainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        MenuBarExtra("Unibrain", systemImage: "brain") {
            Text("Unibrain — Phase 1 Shell")
        }
        #endif
    }
}
