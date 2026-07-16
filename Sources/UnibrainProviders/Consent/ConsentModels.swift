import Foundation
import UnibrainCore

// MARK: - Consent Models

/// Consent record for a provider+modality pair.
///
/// Phase 06-01 Task 3: Per CON-02, consent is scoped per provider and modality.
/// Stores whether user granted "always allow" and when consent was first given.
public struct ConsentRecord: Codable, Sendable {
    /// Whether user chose "Always allow" vs "Only this once".
    public let alwaysAllow: Bool
    /// Timestamp of first consent (for audit trail).
    public let firstConsentedAt: Date

    public init(alwaysAllow: Bool, firstConsentedAt: Date) {
        self.alwaysAllow = alwaysAllow
        self.firstConsentedAt = firstConsentedAt
    }
}

/// Consent state persisted in `.unibrain/consent.json`.
///
/// Phase 06-01 Task 3: JSON schema with version field for forward compatibility.
/// Keys are "{provider}.{modality}" string concatenation per Claude's discretion.
public struct ConsentState: Codable, Sendable {
    /// Schema version for migration support.
    public var schemaVersion: Int
    /// Consent records keyed by "provider.modality" strings.
    public var consents: [String: ConsentRecord]

    public init(schemaVersion: Int = 1, consents: [String: ConsentRecord] = [:]) {
        self.schemaVersion = schemaVersion
        self.consents = consents
    }

    /// Generates consent key for provider+modality pair.
    ///
    /// Phase 06-01: String concatenation "provider.modality" for simple,
    /// readable keys that match CON-02 scope.
    private func consentKey(provider: CloudProvider, modality: Modality) -> String {
        return "\(provider.rawValue).\(modality.rawValue)"
    }

    /// Checks if consent exists for provider+modality pair.
    public func hasConsent(provider: CloudProvider, modality: Modality) -> Bool {
        let key = consentKey(provider: provider, modality: modality)
        return consents[key] != nil
    }

    /// Records consent for provider+modality pair.
    public mutating func grant(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) {
        let key = consentKey(provider: provider, modality: modality)
        consents[key] = ConsentRecord(
            alwaysAllow: alwaysAllow,
            firstConsentedAt: Date()
        )
    }

    /// Removes consent record for provider+modality pair.
    public mutating func revoke(provider: CloudProvider, modality: Modality) {
        let key = consentKey(provider: provider, modality: modality)
        consents.removeValue(forKey: key)
    }
}
