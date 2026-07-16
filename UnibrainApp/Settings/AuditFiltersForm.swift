import SwiftUI
import UnibrainCore
import UnibrainProviders

// MARK: - macOS AuditFiltersForm

#if os(macOS)

/// Detailed filter form for the Audit tab.
///
/// Phase 06-06 Task 2: Per plan, AuditFiltersForm provides 5 pickers bound
/// to AuditViewModel filters. Shown as a sheet/popover when user taps
/// "More Filters" in the compact filter bar.
struct AuditFiltersForm: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        Form {
            Section("Date Range") {
                Picker("Range", selection: $viewModel.dateRange) {
                    ForEach(AuditDateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Provider") {
                Picker("Provider", selection: providerBinding) {
                    Text("All").tag(String?.none)
                    Text("OpenAI").tag(String?.some("openai"))
                    Text("Anthropic").tag(String?.some("anthropic"))
                    Text("Grok").tag(String?.some("grok"))
                    Text("Z.ai").tag(String?.some("zai"))
                    Text("Ollama").tag(String?.some("ollama"))
                    Text("whisper.cpp").tag(String?.some("whisper-cpp"))
                }
                .pickerStyle(.radioGroup)
            }

            Section("Modality") {
                Picker("Modality", selection: modalityBinding) {
                    Text("All").tag(String?.none)
                    Text("LLM").tag(String?.some("llm"))
                    Text("ASR").tag(String?.some("asr"))
                    Text("Vision").tag(String?.some("vision"))
                }
                .pickerStyle(.radioGroup)
            }

            Section("Status") {
                Picker("Status", selection: statusBinding) {
                    Text("All").tag(AuditStatus?.none)
                    Text("Success").tag(AuditStatus?.some(.success))
                    Text("Failed").tag(AuditStatus?.some(.failed))
                }
                .pickerStyle(.radioGroup)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private var providerBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedProvider },
            set: { viewModel.selectedProvider = $0 }
        )
    }

    private var modalityBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedModality },
            set: { viewModel.selectedModality = $0 }
        )
    }

    private var statusBinding: Binding<AuditStatus?> {
        Binding(
            get: { viewModel.selectedStatus },
            set: { viewModel.selectedStatus = $0 }
        )
    }
}

#endif // os(macOS)
