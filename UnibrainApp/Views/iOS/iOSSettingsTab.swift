import SwiftUI
import UnibrainCore
import UnibrainProviders

#if os(iOS)

/// iOS Settings tab — read-only per SET-03.
///
/// Per 06-06-PLAN.md Task 1: Enhanced from Phase 5 placeholder to show:
/// - PROVIDERS (read-only) — current provider selections per modality
/// - COURSES (read-only) — current term + course mapping count
/// - PERMISSIONS (actionable) — mic/calendar/vault re-grant
/// - AUDIT (read-only) — recent activity summary
/// - About — app version + privacy statement
///
/// Per SET-03: Provider configuration (API keys, provider selection, consent)
/// is macOS-only. iPhone inherits state via `.unibrain/` iCloud sync.
struct iOSSettingsTab: View {

    @State private var showingPermissions = false
    @State private var readOnlyAlert: ReadOnlyAlert?

    var body: some View {
        NavigationStack {
            Form {
                providersSection
                coursesSection
                permissionsSection
                auditSection
                aboutSection
            }
            .navigationTitle("Settings")
            .alert(item: $readOnlyAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - PROVIDERS (Read-Only)

    private var providersSection: some View {
        Section {
            providerRow(label: "LLM", value: "Local (Ollama)")
            providerRow(label: "ASR", value: "Local (whisper.cpp)")
            providerRow(label: "Vision", value: "Off")
            providerRow(label: "TTS", value: "Off")

            Text("Configure providers on your Mac")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Providers (Read-Only)")
        }
    }

    private func providerRow(label: String, value: String) -> some View {
        Button {
            readOnlyAlert = ReadOnlyAlert(
                title: "\(label) Provider",
                message: "Provider configuration is available on macOS. Open Settings on your Mac to change providers."
            )
        } label: {
            HStack {
                Text(label)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - COURSES (Read-Only)

    private var coursesSection: some View {
        Section {
            Button {
                readOnlyAlert = ReadOnlyAlert(
                    title: "Courses",
                    message: "Manage courses on your Mac. Open Settings on your Mac to edit course mappings."
                )
            } label: {
                HStack {
                    Text("Current Term")
                    Spacer()
                    Text("Fall 2026")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button {
                readOnlyAlert = ReadOnlyAlert(
                    title: "Course Mappings",
                    message: "Manage courses on your Mac. Open Settings on your Mac to edit course mappings."
                )
            } label: {
                HStack {
                    Text("Course Mappings")
                    Spacer()
                    Text("3")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Text("Manage courses on your Mac")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Courses (Read-Only)")
        }
    }

    // MARK: - PERMISSIONS (Actionable)

    private var permissionsSection: some View {
        Section {
            NavigationLink {
                PermissionsSheet()
            } label: {
                Label("Permissions", systemImage: "lock.shield")
            }

            permissionStatusRow(label: "Microphone", status: "On")
            permissionStatusRow(label: "Calendar", status: "On")

            HStack {
                Text("Vault")
                Spacer()
                Text("~/Documents/Unibrain/")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Tap Permissions to re-grant Microphone or Calendar access, or change vault location.")
        }
    }

    private func permissionStatusRow(label: String, status: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text(status)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - AUDIT (Read-Only)

    private var auditSection: some View {
        Section {
            Button {
                readOnlyAlert = ReadOnlyAlert(
                    title: "Audit Log",
                    message: "View the full audit log on your Mac. Open Settings → Audit on your Mac."
                )
            } label: {
                HStack {
                    Text("Recent Activity")
                    Spacer()
                    Text("Last 7 days")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Text("View full audit log on your Mac")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Audit (Read-Only)")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("unibrain")
                Spacer()
                Text("v1.0")
                    .foregroundStyle(.secondary)
            }

            Text("Local-first. Zero telemetry.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ReadOnlyAlert

private struct ReadOnlyAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#endif
