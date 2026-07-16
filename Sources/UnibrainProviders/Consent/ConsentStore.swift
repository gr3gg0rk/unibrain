import Foundation
import UnibrainCore

/// Actor managing `.unibrain/consent.json` for iCloud-synced consent state.
///
/// Phase 06-01 Task 3: Per CON-03, consent state lives in vault and syncs via
/// iCloud Drive. Actor isolation ensures thread-safe concurrent access.
///
/// Per T-06-02 (mitigate): Uses atomic writes (.atomic option) to prevent
/// iCloud sync corruption. Schema version enables future migration.
public actor ConsentStore {

    /// Path to the vault root (containing `.unibrain/` directory).
    private let vaultPath: URL

    /// In-memory consent state (loaded from disk on init, persisted on changes).
    private var state: ConsentState

    /// Initializes ConsentStore with vault path.
    ///
    /// - Parameter vaultPath: URL to the vault root directory.
    public init(vaultPath: URL) {
        self.vaultPath = vaultPath
        self.state = ConsentState()
    }

    // MARK: - Public API

    /// Checks if user has granted consent for provider+modality pair.
    ///
    /// - Parameters:
    ///   - provider: Cloud provider identifier.
    ///   - modality: AI modality (llm, asr, vision, tts).
    /// - Returns: `true` if consent record exists, `false` otherwise.
    public func hasConsent(provider: CloudProvider, modality: Modality) -> Bool {
        return state.hasConsent(provider: provider, modality: modality)
    }

    /// Returns a snapshot of the current consent state.
    ///
    /// Phase 06-04 Task 1: Exposed so the ``ConsentStoring`` protocol
    /// extension can read `alwaysAllow` flags without touching private state.
    public var stateSnapshot: ConsentState { state }

    /// Grants consent for provider+modality pair.
    ///
    /// Updates in-memory state and persists to `.unibrain/consent.json`
    /// with atomic write for iCloud safety.
    ///
    /// - Parameters:
    ///   - provider: Cloud provider identifier.
    ///   - modality: AI modality.
    ///   - alwaysAllow: `true` for "Always allow", `false` for "Only this once".
    /// - Throws: ``ConsentError`` if file write fails.
    public func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws {
        state.grant(provider: provider, modality: modality, alwaysAllow: alwaysAllow)
        try await save()
    }

    /// Revokes consent for provider+modality pair.
    ///
    /// Removes consent record from state and persists to disk.
    ///
    /// - Parameters:
    ///   - provider: Cloud provider identifier.
    ///   - modality: AI modality.
    /// - Throws: ``ConsentError`` if file write fails.
    public func revokeConsent(provider: CloudProvider, modality: Modality) async throws {
        state.revoke(provider: provider, modality: modality)
        try await save()
    }

    /// Loads consent state from `.unibrain/consent.json` if it exists.
    ///
    /// Called during app startup to restore previous consent decisions.
    /// If file doesn't exist (first launch), leaves state empty.
    ///
    /// - Throws: ``ConsentError`` if file exists but is malformed.
    public func load() async throws {
        let consentPath = vaultPath.appendingPathComponent(".unibrain/consent.json")

        guard FileManager.default.fileExists(atPath: consentPath.path) else {
            return // First launch — no consent file yet
        }

        let data = try Data(contentsOf: consentPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.state = try decoder.decode(ConsentState.self, from: data)
    }

    // MARK: - Private Helpers

    /// Persists consent state to `.unibrain/consent.json` with atomic write.
    ///
    /// Per T-06-02 (mitigate): Uses `.atomic` option to prevent iCloud sync
    /// corruption. Creates `.unibrain/` directory if it doesn't exist.
    private func save() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(state)

        let unibrainDir = vaultPath.appendingPathComponent(".unibrain")
        try FileManager.default.createDirectory(at: unibrainDir, withIntermediateDirectories: true)

        let consentPath = unibrainDir.appendingPathComponent("consent.json")
        try data.write(to: consentPath, options: .atomic)
    }
}

// MARK: - ConsentError

/// Errors thrown by consent store operations.
///
/// Phase 06-01 Task 3: Semantic error types for consent persistence failures.
public enum ConsentError: Error, Sendable {
    /// JSON encoding/decoding failed.
    case serializationError(Error?)
    /// File I/O failed (read/write).
    case fileError(Error?)
}
