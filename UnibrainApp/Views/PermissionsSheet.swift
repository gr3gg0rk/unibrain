import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import UnibrainCore
import UnibrainProviders

/// Post-onboarding permissions audit sheet (ONBD-05).
///
/// Per ONB-04 and UI-SPEC Surface 3: Shows live mic/calendar/vault status
/// with Settings deep-links. Accessible from the main UI after onboarding.
///
/// Per accessibility color-independence requirement: Status rows use
/// `checkmark.circle.fill` (green, granted) or `xmark.circle.fill` (red, denied)
/// — shape + text label carry meaning, not color alone.
struct PermissionsSheet: View {

    // MARK: - State

    /// Live mic permission status (re-read on appear).
    @State private var micStatus: PermissionState = .notDetermined

    /// Live calendar permission status (re-read on appear).
    @State private var calendarStatus: PermissionState = .notDetermined

    /// Current vault folder path from BookmarkStore.
    @State private var vaultPath: String = "(not set)"

    /// Controls the folder picker re-presentation.
    @State private var showingFolderPicker = false

    /// Binding to dismiss the sheet.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Permissions")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Sections
            Form {
                // MARK: Microphone Section
                Section {
                    HStack {
                        permissionStatusIcon(micStatus)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Microphone")
                                .font(.subheadline)
                            Text(permissionStatusText(micStatus, grantedText: "Granted", deniedText: "Denied", notDeterminedText: "Not Requested"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Settings") {
                            openMicrophoneSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Text("Required for recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("MICROPHONE")
                }

                // MARK: Calendar Section
                Section {
                    HStack {
                        permissionStatusIcon(calendarStatus)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar")
                                .font(.subheadline)
                            Text(permissionStatusText(calendarStatus, grantedText: "Connected", deniedText: "Off — Manual Pick", notDeterminedText: "Not Requested"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Settings") {
                            openCalendarSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Text("Auto-routes recordings to courses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("CALENDAR")
                }

                // MARK: Vault Section
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
                    Text("Where notes are saved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("VAULT")
                }
            }
            .formStyle(.grouped)

            Spacer()

            // Done button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(minWidth: 400, minHeight: 450)
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
                    vaultPath = url.lastPathComponent
                }
            case .failure:
                break
            }
        }
    }

    // MARK: - Status Helpers

    /// Returns the appropriate SF Symbol icon for a permission status.
    ///
    /// Per accessibility color-independence: uses distinct icon shapes
    /// (checkmark.circle.fill vs xmark.circle.fill) — not color alone.
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

    /// Returns the human-readable status text.
    private func permissionStatusText(
        _ status: PermissionState,
        grantedText: String,
        deniedText: String,
        notDeterminedText: String
    ) -> String {
        switch status {
        case .granted:
            return grantedText
        case .denied:
            return deniedText
        case .notDetermined:
            return notDeterminedText
        }
    }

    // MARK: - Status Refresh

    /// Re-reads mic/calendar/vault status when the sheet appears.
    ///
    /// Per UI-SPEC: Status updates on sheet dismiss/appear (user may have
    /// toggled permissions in System Settings between appearances).
    private func refreshStatus() {
        // Mic status
        Task {
            await checkMicStatus()
            await checkCalendarStatus()
            checkVaultStatus()
        }
    }

    /// Checks current microphone authorization status.
    private func checkMicStatus() async {
        #if os(macOS) || os(iOS)
        let granted = AVAudioApplication.shared.recordPermission == .granted
        micStatus = granted ? .granted : .denied
        #endif
    }

    /// Checks current calendar authorization status.
    private func checkCalendarStatus() async {
        #if os(macOS) || os(iOS)
        let adapter = EventKitCalendarAdapter()
        let status = await adapter.checkAuthorization()
        calendarStatus = PermissionState.from(status)
        #endif
    }

    /// Reads the current vault path from BookmarkStore.
    private func checkVaultStatus() {
        if let url = BookmarkStore.resolve() {
            vaultPath = url.lastPathComponent
            url.stopAccessingSecurityScopedResource()
        } else {
            vaultPath = "(not set)"
        }
    }

    // MARK: - Settings Deep-Links

    /// Opens System Settings to Privacy > Microphone.
    private func openMicrophoneSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    /// Opens System Settings to Privacy > Calendars.
    private func openCalendarSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
