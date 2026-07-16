import SwiftUI
import UnibrainCore
import UnibrainProviders

// MARK: - SummarizationMode Picker

/// Three-way picker for the summarization toggle (SUMM-02 / OLL-02).
///
/// `Off` is the default on first launch — summarization is opt-in.
/// `Local (Ollama)` triggers the OllamaHealthCheck flow.
/// `Cloud` is a placeholder for future cloud providers (Phase 6 plans 06-03..06-06).
public enum SummarizationMode: String, CaseIterable, Sendable {
    case off = "Off"
    case local = "Local (Ollama)"
    case cloud = "Cloud"

    public var isOllamaSelected: Bool { self == .local }
}

#if os(macOS)

/// General tab of the macOS Settings window.
///
/// Per SET-01: dedicated macOS Settings scene opened from the menu bar popover.
/// Per SET-02: General tab holds the summarization toggle plus vault/about info.
/// Per SUMM-02: default selection is `.off` — summarization is opt-in.
/// Per OLL-01: when `.local` is selected and health check fails, the callout
/// guides Angelica to install Ollama.
struct GeneralTab: View {
    @State private var summarizationMode: SummarizationMode = .off
    @State private var ollamaAvailable: Bool? = nil
    @State private var modelPulled: Bool? = nil
    @State private var isCheckingOllama: Bool = false

    private let healthCheck = OllamaHealthCheck()

    var body: some View {
        Form {
            Section("Summarization") {
                Picker("Enable Summarization", selection: $summarizationMode) {
                    ForEach(SummarizationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .onChange(of: summarizationMode) { _, newMode in
                    handleSummarizationChange(newMode)
                }

                Text("When enabled, unibrain generates a 5-8 bullet summary of each lecture transcript.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if summarizationMode == .local {
                    ollamaCalloutView
                }
            }

            Section("Vault") {
                LabeledContent("Vault Path") {
                    HStack {
                        Text(vaultPathDisplay)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Change…") {
                            // Phase 5 BookmarkStore picker opens here.
                        }
                    }
                }
            }

            Section("Current Term") {
                LabeledContent("Term") {
                    HStack {
                        Text(currentTermDisplay)
                        Button("Edit Details…") {
                            // Opens Courses tab.
                        }
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Text("Local-first. Your audio never leaves your devices. Zero telemetry. No analytics. No phone-home.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("General", systemImage: "gear") }
        .padding()
    }

    // MARK: - Subviews

    @ViewBuilder
    private var ollamaCalloutView: some View {
        switch ollamaAvailable {
        case nil, false:
            OllamaSetupCallout(
                isChecking: isCheckingOllama,
                onRecheck: { Task { await runHealthCheck() } },
                onCancel: { summarizationMode = .off }
            )
        case true:
            if modelPulled == false {
                ModelPullCallout(isPulling: false, progress: 0.0) {
                    Task { await pullModel() }
                }
            }
        }
    }

    // MARK: - Actions

    private func handleSummarizationChange(_ newMode: SummarizationMode) {
        if newMode == .local {
            Task { await runHealthCheck() }
        } else {
            ollamaAvailable = nil
            modelPulled = nil
        }
    }

    private func runHealthCheck() async {
        isCheckingOllama = true
        let ok = await healthCheck.check()
        ollamaAvailable = ok
        isCheckingOllama = false
        if ok {
            // Check whether the model is pulled by probing /api/tags.
            // The ModelPullCallout handles the missing-model branch.
            modelPulled = false // simplified for MVP — actual tags check lives in Task 5 wiring
        }
    }

    private func pullModel() async {
        // Placeholder: Task 5 wires the actual `ollama pull llama-3.2:3b` via Process.
        // For now, ModelPullCallout streams synthetic progress.
    }

    // MARK: - Display Helpers

    private var vaultPathDisplay: String {
        #if os(macOS)
        // Per Phase 5: BookmarkStore holds the user-selected vault folder.
        // Per Phase 3 P-13: default vault root is ~/Documents/Unibrain/.
        if let url = BookmarkStore.resolve() {
            url.stopAccessingSecurityScopedResource()
            return url.path
        }
        return HardcodedVaultResolver.vaultRoot.path
        #else
        return "(unknown)"
        #endif
    }

    private var currentTermDisplay: String {
        // The Courses tab writes the term; General shows a summary.
        // Read synchronously from CourseMappingStore is not available here
        // without making this an async view. The popover's MenuBarViewModel
        // tracks currentTermLabel — Settings opens in its own window, so
        // we show a static prompt that links to the Courses tab.
        "(see Courses tab)"
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    GeneralTab()
        .frame(width: 480)
}

#endif // os(macOS)
