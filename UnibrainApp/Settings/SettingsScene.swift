import SwiftUI
import UnibrainCore
import UnibrainProviders

// MARK: - SettingsTab

/// Identifiers for each Settings tab (SET-01, SET-02).
///
/// Used for context-aware opening (CF-04, CON-01 post-failure → Audit;
/// permission warning → Permissions) and keyboard shortcuts (⌘+1..⌘+5).
public enum SettingsTab: String, CaseIterable, Sendable {
    case general
    case providers
    case courses
    case permissions
    case audit

    /// Localized label shown in the tab bar and window title.
    public var label: String {
        switch self {
        case .general: return "General"
        case .providers: return "Providers"
        case .courses: return "Courses"
        case .permissions: return "Permissions"
        case .audit: return "Audit"
        }
    }

    /// SF Symbol name used for the tab icon.
    public var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .providers: return "checkmark.shield.fill"
        case .courses: return "text.book.closed.fill"
        case .permissions: return "person.crop.rectangle.badge.checkmark"
        case .audit: return "chart.bar.doc.horizontal"
        }
    }
}

// MARK: - SettingsScene (macOS-only)

#if os(macOS)

/// SwiftUI `Settings` scene for unibrain (SET-01).
///
/// Per SET-01: dedicated macOS Settings window, separate from the menu-bar
/// popover (popover stays ~280pt, recording-focused). Opens via ⌘, keyboard
/// shortcut, menu bar "Settings…" button, or context-aware from post-failure
/// flows (CF-04 → Audit tab; permission warning → Permissions tab).
///
/// Per SET-02: 5-tab layout — General | Providers | Courses | Permissions | Audit.
/// Each tab is a separate SwiftUI view defined in its own file.
///
/// Usage from `UnibrainApp`:
/// ```swift
/// Settings {
///     SettingsScene(selectedTab: $settingsSelectedTab)
/// }
/// ```
struct SettingsScene: View {
    /// Binding to the shared selected-tab state.
    ///
    /// Per SET-04 context-aware opening: `MenuBarPopover` and failure handlers
    /// mutate this binding to focus the relevant tab when opening Settings.
    @Binding var selectedTab: SettingsTab

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralTab()
                .tabItem {
                    Label(SettingsTab.general.label,
                          systemImage: SettingsTab.general.systemImage)
                }
                .tag(SettingsTab.general)
                .keyboardShortcut("1", modifiers: .command)

            ProvidersTab()
                .tabItem {
                    Label(SettingsTab.providers.label,
                          systemImage: SettingsTab.providers.systemImage)
                }
                .tag(SettingsTab.providers)
                .keyboardShortcut("2", modifiers: .command)

            CoursesTab()
                .tabItem {
                    Label(SettingsTab.courses.label,
                          systemImage: SettingsTab.courses.systemImage)
                }
                .tag(SettingsTab.courses)
                .keyboardShortcut("3", modifiers: .command)

            PermissionsTab()
                .tabItem {
                    Label(SettingsTab.permissions.label,
                          systemImage: SettingsTab.permissions.systemImage)
                }
                .tag(SettingsTab.permissions)
                .keyboardShortcut("4", modifiers: .command)

            AuditTab()
                .tabItem {
                    Label(SettingsTab.audit.label,
                          systemImage: SettingsTab.audit.systemImage)
                }
                .tag(SettingsTab.audit)
                .keyboardShortcut("5", modifiers: .command)
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("unibrain Settings")
    }
}

// MARK: - AuditTab (placeholder — full implementation in plan 06-06)

/// Audit tab placeholder.
///
/// Per CF-04: surfaces per-note cloud failure history with error details and
/// timestamps. Full implementation lands in plan 06-06 (consent revocation +
/// audit trail UI). Placeholder shows an explanatory empty state so the tab
/// structure is complete and usable now.
struct AuditTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Audit Trail")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Cloud call history, consent records, and failure details will appear here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .tabItem {
            Label(SettingsTab.audit.label,
                  systemImage: SettingsTab.audit.systemImage)
        }
    }
}

// MARK: - Preview

#Preview("Settings Window") {
    @Previewable @State var tab: SettingsTab = .general
    return SettingsScene(selectedTab: $tab)
        .frame(width: 700, height: 480)
}

#endif // os(macOS)
