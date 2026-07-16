import Foundation
import UnibrainCore

// MARK: - ConsentStatus

/// User-facing consent state for a provider×modality pair.
///
/// Phase 06-04 Task 1: Drives the ConsentSheet presentation logic.
/// - `.neverAsked`: first-use, sheet should appear (CON-01)
/// - `.onceOnly`: consent granted for single-use only
/// - `.alwaysAllowed`: "Always allow" persisted (CON-02)
/// - `.revoked`: consent explicitly revoked in Settings
public enum ConsentStatus: Sendable, Equatable {
    case neverAsked
    case onceOnly
    case alwaysAllowed
    case revoked
}

// MARK: - ConsentViewModel

/// Manages consent state and presentation logic for cloud provider consent.
///
/// Phase 06-04 Task 1: Bridges the UI (ConsentSheet) and persistence
/// (ConsentStore). Used by ProviderRouter (Task 5) to check consent before
/// returning a cloud summarizer.
///
/// Per CON-01: First cloud call per provider×modality triggers consent sheet.
/// Per CON-02: "Always allow" scope is per-provider-per-modality.
/// Per CON-03: Consent state persists to `.unibrain/consent.json`.
///
/// `@unchecked Sendable`: all mutable state is serialized via `ConsentCache`'s
/// internal `DispatchQueue`. Safe to call from any actor including
/// `ProviderRouter` and the SwiftUI main thread.
public final class ConsentViewModel: @unchecked Sendable {

    /// Backing consent store (real or mock).
    private let consentStore: any ConsentStoring

    /// In-memory cache of consent statuses, keyed by "provider.modality".
    ///
    /// Refreshed from the store on demand. The cache lets the UI read status
    /// synchronously after the initial async load.
    private let cache = ConsentCache()

    public init(consentStore: any ConsentStoring) {
        self.consentStore = consentStore
    }

    // MARK: - Public API

    /// Returns `true` when no consent record exists for the provider×modality
    /// pair — the ConsentSheet should be presented (CON-01).
    public func shouldShowConsent(provider: CloudProvider, modality: Modality) async -> Bool {
        let hasConsent = await consentStore.hasConsent(provider: provider, modality: modality)
        return !hasConsent
    }

    /// Grants consent for the provider×modality pair.
    ///
    /// Per CON-02/CON-03: persists via ConsentStore with the `alwaysAllow`
    /// flag. When `alwaysAllow == true`, future calls for this pair skip the
    /// consent sheet entirely.
    public func grantConsent(
        provider: CloudProvider,
        modality: Modality,
        alwaysAllow: Bool
    ) async throws {
        try await consentStore.grantConsent(
            provider: provider,
            modality: modality,
            alwaysAllow: alwaysAllow
        )
        let status: ConsentStatus = alwaysAllow ? .alwaysAllowed : .onceOnly
        cache.set(status, for: provider, modality: modality)
    }

    /// Revokes consent for the provider×modality pair.
    ///
    /// Removes the record from the store; future calls for this pair will
    /// trigger the consent sheet again (returns to `.neverAsked`).
    public func revokeConsent(provider: CloudProvider, modality: Modality) async throws {
        try await consentStore.revokeConsent(provider: provider, modality: modality)
        cache.set(.neverAsked, for: provider, modality: modality)
    }

    /// Returns the current consent status for the provider×modality pair.
    public func consentStatus(
        provider: CloudProvider,
        modality: Modality
    ) async -> ConsentStatus {
        // Check the cache first (synchronous path after first load)
        if let cached = cache.get(for: provider, modality: modality) {
            // Verify cache is still valid by consulting store
            let record = await consentStore.consentRecord(for: provider, modality: modality)
            if record == nil && cached != .neverAsked {
                // Cache stale — store revoked under us
                cache.set(.neverAsked, for: provider, modality: modality)
                return .neverAsked
            }
            // Reconcile cache with the persisted record's alwaysAllow flag
            if let record {
                let resolved: ConsentStatus = record.alwaysAllow ? .alwaysAllowed : .onceOnly
                if resolved != cached {
                    cache.set(resolved, for: provider, modality: modality)
                    return resolved
                }
            }
            return cached
        }

        // Cache miss — ask store
        guard let record = await consentStore.consentRecord(for: provider, modality: modality) else {
            cache.set(.neverAsked, for: provider, modality: modality)
            return .neverAsked
        }

        let status: ConsentStatus = record.alwaysAllow ? .alwaysAllowed : .onceOnly
        cache.set(status, for: provider, modality: modality)
        return status
    }
}

// MARK: - ConsentCache

/// Thread-safe in-memory cache of ConsentStatus keyed by "provider.modality".
///
/// `@unchecked Sendable` because access is serialized via `DispatchQueue`.
/// Kept internal to this file — the public surface is `ConsentViewModel`.
final class ConsentCache: @unchecked Sendable {

    private let queue = DispatchQueue(label: "ConsentCache")
    private var storage: [String: ConsentStatus] = [:]

    func get(for provider: CloudProvider, modality: Modality) -> ConsentStatus? {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        return queue.sync { storage[key] }
    }

    func set(_ status: ConsentStatus, for provider: CloudProvider, modality: Modality) {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        queue.sync { storage[key] = status }
    }
}
