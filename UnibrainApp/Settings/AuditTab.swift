import SwiftUI
import UnibrainCore
import UnibrainProviders

// MARK: - macOS AuditTab

#if os(macOS)

/// Full Audit tab implementation (replaces placeholder from 06-05).
///
/// Phase 06-06 Task 2: Per CF-04, surfaces per-note cloud failure history
/// with error details and timestamps. Per CLOUD-13, shows provider usage
/// per note. Includes filters (date range, provider, modality, course, status)
/// and export/clear actions.
struct AuditTabFull: View {
    @State private var viewModel = AuditViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Filters bar
            AuditFiltersBar(viewModel: $viewModel)

            Divider()

            // Main content
            if viewModel.entries.isEmpty {
                emptyState
            } else {
                auditTable
            }

            Divider()

            // Bottom toolbar
            bottomToolbar
        }
        .padding()
        .task {
            await viewModel.load()
        }
        .frame(minWidth: 500, minHeight: 300)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Audit Entries")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Cloud call history and failure details will appear here once notes are processed.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Audit Table

    private var auditTable: some View {
        Table(viewModel.filteredEntries) {
            TableColumn("Date") { entry in
                Text(entry.date, style: .date)
                    .font(.caption)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Note") { entry in
                VStack(alignment: .leading) {
                    Text(entry.noteName)
                        .font(.body)
                    Text(entry.course)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 150, ideal: 200)

            TableColumn("Provider") { entry in
                Text(entry.llmProvider ?? entry.asrProvider ?? "—")
                    .font(.caption)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Modality") { entry in
                Text(primaryModality(entry))
                    .font(.caption)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Status") { entry in
                HStack(spacing: 4) {
                    if entry.status == .success {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    Text(entry.status == .success ? "Success" : "Failed")
                        .font(.caption)
                }
            }
            .width(min: 70, ideal: 90)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            if !viewModel.failedEntries.isEmpty {
                DisclosureGroup("Failed Operations (\(viewModel.failedEntries.count))") {
                    failedOperationsList
                }
                .font(.caption)
            }

            Spacer()

            Button("Export Audit Log") {
                viewModel.exportAuditLog()
            }
            .disabled(viewModel.entries.isEmpty)

            Button("Clear History", role: .destructive) {
                viewModel.showClearConfirmation = true
            }
            .disabled(viewModel.entries.isEmpty)
        }
        .padding(.top, 8)
        .alert("Clear Audit History?", isPresented: $viewModel.showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("This will remove all audit entries from the in-memory index. Notes in the vault are not affected.")
        }
    }

    private var failedOperationsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.failedEntries) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.noteName)
                            .font(.caption)
                            .fontWeight(.medium)
                        if let error = entry.error {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Button("Retry") { viewModel.retry(entry) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    Button("Use Local") { viewModel.fallback(entry) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                .padding(.vertical, 2)
            }
        }
    }

    /// Returns the primary modality string for display.
    private func primaryModality(_ entry: AuditEntry) -> String {
        if entry.llmProvider != nil { return "LLM" }
        if entry.asrProvider != nil { return "ASR" }
        if entry.visionProvider != nil { return "Vision" }
        return "—"
    }
}

// MARK: - AuditViewModel

/// View model for the Audit tab.
@MainActor
final class AuditViewModel: ObservableObject {
    @Published var entries: [AuditEntry] = []
    @Published var dateRange: AuditDateRange = .last7Days
    @Published var selectedProvider: String? = nil
    @Published var selectedModality: String? = nil
    @Published var selectedCourse: String? = nil
    @Published var selectedStatus: AuditStatus? = nil
    @Published var showClearConfirmation = false

    /// Default vault path — in production, reads from BookmarkStore/HardcodedVaultResolver.
    private let vaultPath = URL(fileURLWithPath: NSString("~/Documents/Unibrain").expandingTildeInPath)
    private var store: AuditTrailStore?

    /// Filtered entries based on current filter selections.
    var filteredEntries: [AuditEntry] {
        // Note: filters are applied on load; this is a simple display accessor.
        entries
    }

    /// Entries with failed status.
    var failedEntries: [AuditEntry] {
        entries.filter { $0.status == .failed }
    }

    func load() async {
        let store = AuditTrailStore(vaultPath: vaultPath)
        self.store = store

        do {
            var scanned = try await store.scanVault()
            scanned = await store.filterByDate(scanned, range: dateRange)

            if let provider = selectedProvider {
                scanned = await store.filterByProvider(scanned, provider: provider)
            }
            if let modality = selectedModality {
                scanned = await store.filterByModality(scanned, modality: modality)
            }
            if let course = selectedCourse {
                scanned = await store.filterByCourse(scanned, course: course)
            }
            if let status = selectedStatus {
                scanned = await store.filterByStatus(scanned, status: status)
            }

            entries = scanned
        } catch {
            entries = []
        }
    }

    func exportAuditLog() {
        // Export to CSV — NSSavePanel handled by caller
        let csv = entries.map { entry in
            "\(entry.date.iso8601),\(entry.noteName),\(entry.course),\(entry.llmProvider ?? ""),\(entry.status.rawValue),\(entry.error ?? "")"
        }.joined(separator: "\n")

        let header = "Date,Note,Course,Provider,Status,Error\n"
        let csvContent = header + csv

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "unibrain-audit-log.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? csvContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func clearHistory() {
        entries = []
    }

    func retry(_ entry: AuditEntry) {
        // Retry triggers RegenerateSummaryUseCase — wiring deferred
    }

    func fallback(_ entry: AuditEntry) {
        // Fallback to local — wiring deferred
    }
}

// MARK: - AuditFiltersBar

/// Compact filter bar for the Audit tab.
struct AuditFiltersBar: View {
    @Binding var viewModel: AuditViewModel

    var body: some View {
        HStack(spacing: 12) {
            Picker("Range", selection: $viewModel.dateRange) {
                ForEach(AuditDateRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)

            Picker("Provider", selection: providerBinding) {
                Text("All").tag(String?.none)
                Text("OpenAI").tag(String?.some("openai"))
                Text("Anthropic").tag(String?.some("anthropic"))
                Text("Grok").tag(String?.some("grok"))
                Text("Z.ai").tag(String?.some("zai"))
                Text("Ollama").tag(String?.some("ollama"))
                Text("whisper.cpp").tag(String?.some("whisper-cpp"))
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            Picker("Status", selection: statusBinding) {
                Text("All").tag(AuditStatus?.none)
                Text("Success").tag(AuditStatus?.some(.success))
                Text("Failed").tag(AuditStatus?.some(.failed))
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Spacer()

            Button("Refresh") {
                Task { await viewModel.load() }
            }
        }
        .padding(.bottom, 8)
    }

    private var providerBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedProvider },
            set: { viewModel.selectedProvider = $0; Task { await viewModel.load() } }
        )
    }

    private var statusBinding: Binding<AuditStatus?> {
        Binding(
            get: { viewModel.selectedStatus },
            set: { viewModel.selectedStatus = $0; Task { await viewModel.load() } }
        )
    }
}

// MARK: - Date Extension

private extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}

#endif // os(macOS)
