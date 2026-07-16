import SwiftUI
import UnibrainCore
import UnibrainProviders

#if os(macOS)

/// API key entry row with SecureField, validation checkmark, and Remove button.
///
/// Per CLOUD-07: API keys stored in macOS Keychain. Per SET-02: SecureField
/// masks input (dots). Per T-06-24: validation regex checks format before
/// storing, and a checkmark appears when the format is valid.
///
/// Shown only when a cloud provider is selected for the modality.
/// On Save, calls APIKeyStore.store(key:for:). On Remove, clears the key
/// from Keychain and the parent view resets the picker to Local/Off.
struct APIKeyEntryRow: View {

    /// The cloud provider this key is for.
    let provider: CloudProvider

    /// Called with the key when the user taps Save.
    let onSave: (String) async -> Void

    /// Called when the user taps Remove (confirms first).
    let onRemove: () async -> Void

    /// Current key text entry.
    @State private var keyText: String = ""

    /// Controls the confirmation alert for removal.
    @State private var showingRemoveAlert: Bool = false

    /// True while saving to Keychain.
    @State private var isSaving: Bool = false

    /// True after the key was successfully saved.
    @State private var didSave: Bool = false

    /// Validation result for the current keyText.
    private var isValid: Bool {
        APIKeyValidator.isValid(keyText, for: provider)
    }

    /// Human-readable provider name for labels.
    private var providerName: String {
        switch provider {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .grok: return "Grok"
        case .zai: return "Z.ai"
        case .ollama: return "Ollama"
        case .whisperCpp: return "whisper.cpp"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(providerName) API Key")
                    .font(.subheadline)

                Spacer()

                if isValid {
                    Label("", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Key format valid")
                }

                if didSave {
                    Button(role: .destructive) {
                        showingRemoveAlert = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }

            SecureField("Enter \(providerName) API key", text: $keyText)
                .textFieldStyle(.roundedBorder)
                .disabled(didSave)

            HStack {
                if !didSave {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save to Keychain")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!isValid || isSaving)
                } else {
                    Label("Stored in Keychain", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                if !keyText.isEmpty && !didSave {
                    Button("Clear") {
                        keyText = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
        .alert("Remove \(providerName) API key?", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {
                showingRemoveAlert = false
            }
            Button("Remove", role: .destructive) {
                Task { await remove() }
            }
        } message: {
            Text("The key will be deleted from macOS Keychain. The provider picker will reset to Local.")
        }
    }

    // MARK: - Actions

    private func save() async {
        guard isValid else { return }
        isSaving = true
        await onSave(keyText)
        isSaving = false
        didSave = true
        keyText = ""
    }

    private func remove() async {
        await onRemove()
        didSave = false
        keyText = ""
        showingRemoveAlert = false
    }
}

#endif // os(macOS)
