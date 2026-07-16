import SwiftUI

#if os(iOS)

/// Minimal Settings tab for iOS per IOS-01 Phase 5.
///
/// Per IOS-01: Phase 5 ships a minimal placeholder with only the Permissions
/// sheet entry (ONB-04). Full per-modality provider selectors arrive in Phase 6.
struct iOSSettingsTab: View {

    @State private var showingPermissions = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        PermissionsSheet()
                    } label: {
                        Label("Permissions", systemImage: "lock.shield")
                    }
                }

                Section("About") {
                    HStack {
                        Text("unibrain")
                        Spacer()
                        Text("v1.0")
                            .foregroundStyle(.secondary)
                    }

                    Text("Local-first. Your audio never leaves your devices.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#endif
