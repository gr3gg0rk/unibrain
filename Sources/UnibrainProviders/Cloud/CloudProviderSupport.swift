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
public protocol ConsentStoring: Sendable {
    func hasConsent(provider: CloudProvider, modality: Modality) async -> Bool
    func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws
    func revokeConsent(provider: CloudProvider, modality: Modality) async throws
    func load() async throws
}

/// Extend the real ``ConsentStore`` actor to conform to ``ConsentStoring``.
extension ConsentStore: ConsentStoring {}
