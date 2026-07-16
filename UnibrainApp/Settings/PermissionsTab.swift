import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
import UnibrainCore
import UnibrainProviders

#if os(macOS)

/// Permissions tab of the macOS Settings window (SET-04).
///
/// Folds the Phase 5 PermissionsSheet (ONB-04) into a Settings tab.
/// Per SET-04: the standalone popover sheet button is replaced by this tab.
///
/// Shows live mic/calendar/vault permission status with Settings deep-links,
/// and a full disclosure privacy statement.
struct PermissionsTab: View {

    // MARK: - State

    @State private var micStatus: PermissionState = .notDetermined
    @State private var calendarStatus: PermissionState = .notDetermined
    @State private var vaultPath: String = "(not set)"
    @State private var showingFolderPicker = false

    var body: some View {
        Form {
            // MARK: - Microphone Section
            Section {
                HStack {
                    permissionStatusIcon(micStatus)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Microphone")
                            .font(.subheadline)
                        Text(permissionStatusText(
                            micStatus,
                            grantedText: "Granted",
                            deniedText: "Denied",
                            notDeterminedText: "Not Requested"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Settings") {
                        openMicrophoneSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Text("Required for recording lectures.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("MICROPHONE")
            }

            // MARK: - Calendar Section
            Section {
                HStack {
                    permissionStatusIcon(calendarStatus)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calendar")
                            .font(.subheadline)
                        Text(permissionStatusText(
                            calendarStatus,
                            grantedText: "Connected",
                            deniedText: "Off \u{2014} Manual Pick",
                            notDeterminedText: "Not Requested"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Settings") {
                        openCalendarSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Text("Auto-routes recordings to courses based on your schedule.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("CALENDAR")
            }

            // MARK: - Vault Section
            Section {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vaultPath)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Change") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Text("Where lecture notes and recordings are saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("VAULT")
            }

            // MARK: - Full Disclosure Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Local-first by design", systemImage: "lock.shield.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text("unibrain is local-first. Your audio never leaves your devices unless you explicitly enable cloud providers. Zero telemetry. No analytics. No phone-home.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("FULL DISCLOSURE")
            }
        }
        .formStyle(.grouped)
        .tabItem {
            Label(SettingsTab.permissions.label,
                  systemImage: SettingsTab.permissions.systemImage)
        }
        .padding()
        .onAppear {
            refreshStatus()
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    try? BookmarkStore.save(for: url)
                    url.stopAccessingSecurityScopedResource()
                    vaultPath = url.path
                }
            case .failure:
                break
            }
        }
    }

    // MARK: - Status Helpers

    @ViewBuilder
    private func permissionStatusIcon(_ status: PermissionState) -> some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .notDetermined:
            Image(systemName: "circle.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func permissionStatusText(
        _ status: PermissionState,
        grantedText: String,
        deniedText: String,
        notDeterminedText: String
    ) -> String {
        switch status {
        case .granted: return grantedText
        case .denied: return deniedText
        case .notDetermined: return notDeterminedText
        }
    }

    // MARK: - Status Refresh

    private func refreshStatus() {
        Task {
            await checkMicStatus()
            await checkCalendarStatus()
            checkVaultStatus()
        }
    }

    private func checkMicStatus() async {
        #if os(macOS)
        let granted = AVAudioApplication.shared.recordPermission == .granted
        micStatus = granted ? .granted : .denied
        #endif
    }

    private func checkCalendarStatus() async {
        let adapter = EventKitCalendarAdapter()
        let status = await adapter.checkAuthorization()
        calendarStatus = PermissionState.from(status)
    }

    private func checkVaultStatus() {
        if let url = BookmarkStore.resolve() {
            vaultPath = url.path
            url.stopAccessingSecurityScopedResource()
        } else {
            // Per Phase 3 P-13: default vault root is ~/Documents/Unibrain/.
            // BookmarkStore is empty until onboarding completes; show the
            // default path so the row is never blank pre-onboarding.
            vaultPath = HardcodedVaultResolver.vaultRoot.path
        }
    }

    // MARK: - Settings Deep-Links

    private func openMicrophoneSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func openCalendarSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    PermissionsTab()
        .frame(width: 600, height: 500)
}

#endif // os(macOS)
