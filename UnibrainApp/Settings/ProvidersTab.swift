import SwiftUI
import UnibrainCore
import UnibrainProviders

#if os(macOS)

/// Providers tab of the macOS Settings window.
///
/// Per SET-02: 4 sections — LLM Provider (Summarization), ASR Provider
/// (Transcription), Vision Provider (Image Description), TTS Provider
/// (Text-to-Speech). Each section has a ProviderPickerRow with inline Picker
/// and an APIKeyEntryRow below the picker when a cloud provider is selected.
///
/// Per CLOUD-01: per-modality selectors (Local default for LLM/ASR, Off for
/// Vision/TTS on first launch per CLOUD-02).
///
/// Per CLOUD-07: API keys stored in macOS Keychain via APIKeyStore.
struct ProvidersTab: View {

    // MARK: - Per-Modality State

    /// LLM provider selection (default: .local per CLOUD-02).
    @State private var llmProvider: LLMModalityProvider = .local

    /// ASR provider selection (default: .local per CLOUD-02).
    @State private var asrProvider: ASRModalityProvider = .local

    /// Vision provider selection (default: .off — no v1 feature consumer).
    @State private var visionProvider: VisionModalityProvider = .off

    /// TTS provider selection (default: .off — no v1 feature consumer).
    @State private var ttsProvider: TTSModalityProvider = .off

    /// Shared API key store for persisting keys to Keychain.
    private let apiKeyStore = APIKeyStore()

    var body: some View {
        Form {
            // MARK: - LLM Provider Section
            Section {
                ProviderPickerRow(
                    label: "LLM Provider",
                    primaryUse: "Summarization",
                    options: LLMModalityProvider.allCases.map {
                        ($0.label, $0.rawValue)
                    },
                    selection: Binding(
                        get: { llmProvider.rawValue },
                        set: { newValue in
                            if let parsed = LLMModalityProvider(rawValue: newValue) {
                                llmProvider = parsed
                            }
                        }
                    )
                )

                if let cloud = llmProvider.cloudProvider {
                    APIKeyEntryRow(
                        provider: cloud,
                        onSave: { key in
                            try? await apiKeyStore.store(key: key, for: cloud)
                        },
                        onRemove: {
                            try? await apiKeyStore.delete(provider: cloud)
                            llmProvider = .local
                        }
                    )
                }
            } header: {
                Label("LLM \u{2014} Summarization", systemImage: "bolt.fill")
            }

            // MARK: - ASR Provider Section
            Section {
                ProviderPickerRow(
                    label: "ASR Provider",
                    primaryUse: "Transcription",
                    options: ASRModalityProvider.allCases.map {
                        ($0.label, $0.rawValue)
                    },
                    selection: Binding(
                        get: { asrProvider.rawValue },
                        set: { newValue in
                            if let parsed = ASRModalityProvider(rawValue: newValue) {
                                asrProvider = parsed
                            }
                        }
                    )
                )

                if let cloud = asrProvider.cloudProvider {
                    APIKeyEntryRow(
                        provider: cloud,
                        onSave: { key in
                            try? await apiKeyStore.store(key: key, for: cloud)
                        },
                        onRemove: {
                            try? await apiKeyStore.delete(provider: cloud)
                            asrProvider = .local
                        }
                    )
                }
            } header: {
                Label("ASR \u{2014} Transcription", systemImage: "waveform")
            }

            // MARK: - Vision Provider Section
            Section {
                ProviderPickerRow(
                    label: "Vision Provider",
                    primaryUse: "Image Description",
                    options: VisionModalityProvider.allCases.map {
                        ($0.label, $0.rawValue)
                    },
                    selection: Binding(
                        get: { visionProvider.rawValue },
                        set: { newValue in
                            if let parsed = VisionModalityProvider(rawValue: newValue) {
                                visionProvider = parsed
                            }
                        }
                    )
                )

                if let cloud = visionProvider.cloudProvider {
                    APIKeyEntryRow(
                        provider: cloud,
                        onSave: { key in
                            try? await apiKeyStore.store(key: key, for: cloud)
                        },
                        onRemove: {
                            try? await apiKeyStore.delete(provider: cloud)
                            visionProvider = .off
                        }
                    )
                }
            } header: {
                Label("Vision \u{2014} Image Description", systemImage: "eye")
            }

            // MARK: - TTS Provider Section
            Section {
                ProviderPickerRow(
                    label: "TTS Provider",
                    primaryUse: "Text-to-Speech",
                    options: TTSModalityProvider.allCases.map {
                        ($0.label, $0.rawValue)
                    },
                    selection: Binding(
                        get: { ttsProvider.rawValue },
                        set: { newValue in
                            if let parsed = TTSModalityProvider(rawValue: newValue) {
                                ttsProvider = parsed
                            }
                        }
                    )
                )

                if let cloud = ttsProvider.cloudProvider {
                    APIKeyEntryRow(
                        provider: cloud,
                        onSave: { key in
                            try? await apiKeyStore.store(key: key, for: cloud)
                        },
                        onRemove: {
                            try? await apiKeyStore.delete(provider: cloud)
                            ttsProvider = .off
                        }
                    )
                }
            } header: {
                Label("TTS \u{2014} Text-to-Speech", systemImage: "speaker.wave.2")
            }

            // MARK: - Explanation Footer
            Section {
                Text("Cloud providers require API keys stored in macOS Keychain. Local providers work offline and require no configuration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem {
            Label(SettingsTab.providers.label,
                  systemImage: SettingsTab.providers.systemImage)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ProvidersTab()
        .frame(width: 600, height: 500)
}

#endif // os(macOS)
