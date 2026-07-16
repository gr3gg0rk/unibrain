import Foundation
import UnibrainCore

/// Abstraction over ``APIKeyStore`` enabling test injection.
///
/// Cloud provider clients depend on this protocol, not on the concrete
/// `APIKeyStore` actor. Tests inject `StubAPIKeyStore` to avoid Keychain.
public protocol APIKeyStoring: Sendable {
    func fetch(provider: CloudProvider) async throws -> String?
    func store(key: String, for provider: CloudProvider) async throws
    func delete(provider: CloudProvider) async throws
}

/// Extend the real ``APIKeyStore`` actor to conform to ``APIKeyStoring``.
extension APIKeyStore: APIKeyStoring {}

/// Abstraction over ``ConsentStore`` enabling test injection.
///
/// Cloud provider clients depend on this protocol, not on the concrete
/// `ConsentStore` actor. Tests inject `StubConsentStore` /
/// `MockConsentStore` to avoid file I/O.
///
/// Phase 06-04 Task 1: `consentRecord(for:modality:)` added so
/// `ConsentViewModel.consentStatus` can read the `alwaysAllow` flag
/// without touching the concrete store.
public protocol ConsentStoring: Sendable {
    /// Returns `true` if any consent record exists for the pair.
    func hasConsent(provider: CloudProvider, modality: Modality) async -> Bool

    /// Returns the consent record for the pair, if any.
    ///
    /// Phase 06-04 Task 1: Enables `ConsentViewModel` to distinguish
    /// `.onceOnly` from `.alwaysAllowed` when reading persisted state.
    func consentRecord(for provider: CloudProvider, modality: Modality) async -> ConsentRecord?

    func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws
    func revokeConsent(provider: CloudProvider, modality: Modality) async throws
    func load() async throws
}

/// Extend the real ``ConsentStore`` actor to conform to ``ConsentStoring``.
///
/// Phase 06-04 Task 1: `consentRecord(for:modality:)` exposes the existing
/// `state.hasConsent` machinery plus a new accessor that returns the record.
/// The store already holds this data in its in-memory `state.consents` map.
extension ConsentStore: ConsentStoring {
    /// Returns the consent record for the pair, if any.
    public func consentRecord(
        for provider: CloudProvider,
        modality: Modality
    ) async -> ConsentRecord? {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        return stateSnapshot.consents[key]
    }
}
