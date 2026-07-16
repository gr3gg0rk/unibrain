import SwiftUI
import UnibrainCore
import UnibrainProviders

#if os(macOS)

/// Reusable inline-picker row for selecting a provider per modality.
///
/// Per SET-02: Provider pickers are inline Picker (menu style) with Off |
/// Local | {cloud providers} options. Label shows modality name + primary use.
/// On change, the bound selection updates — the parent view observes and
/// persists via ProviderRouter.updateSettings().
struct ProviderPickerRow: View {
    let label: String
    let primaryUse: String
    let options: [(label: String, tag: String)]
    @Binding var selection: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(primaryUse)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.tag) { option in
                    Text(option.label).tag(option.tag)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

#endif // os(macOS)
