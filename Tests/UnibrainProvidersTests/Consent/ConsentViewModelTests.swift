import Testing
import Foundation
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum ConsentViewModelTests {

    // MARK: - Test 1: shouldShowConsent returns true when no consent record exists

    @Test("ConsentViewModel.shouldShowConsent returns true when no consent record exists")
    static func shouldShowConsentReturnsTrueWhenNoRecord() async throws {
        let store = MockConsentStore()
        let vm = ConsentViewModel(consentStore: store)

        let shouldShow = await vm.shouldShowConsent(provider: .openai, modality: .llm)
        #expect(shouldShow == true, "Expected consent sheet for first-use provider×modality")
    }

    // MARK: - Test 2: shouldShowConsent returns false when consent exists

    @Test("ConsentViewModel.shouldShowConsent returns false when consent exists")
    static func shouldShowConsentReturnsFalseWhenRecordExists() async throws {
        let store = MockConsentStore()
        store.setHasConsent(.openai, .llm, true)
        let vm = ConsentViewModel(consentStore: store)

        let shouldShow = await vm.shouldShowConsent(provider: .openai, modality: .llm)
        #expect(shouldShow == false, "Expected no consent sheet after consent already granted")
    }

    // MARK: - Test 3: grantConsent persists to ConsentStore

    @Test("ConsentViewModel.grantConsent persists to ConsentStore")
    static func grantConsentPersists() async throws {
        let store = MockConsentStore()
        let vm = ConsentViewModel(consentStore: store)

        try await vm.grantConsent(provider: .anthropic, modality: .llm, alwaysAllow: true)

        let granted = store.grantedConsents["anthropic.llm"]
        #expect(granted != nil, "Expected grantConsent to write to store")
        #expect(granted?.alwaysAllow == true, "Expected alwaysAllow=true to persist")
    }

    // MARK: - Test 4: revokeConsent removes record

    @Test("ConsentViewModel.revokeConsent removes record")
    static func revokeConsentRemovesRecord() async throws {
        let store = MockConsentStore()
        store.setHasConsent(.grok, .llm, true)
        let vm = ConsentViewModel(consentStore: store)

        try await vm.revokeConsent(provider: .grok, modality: .llm)

        #expect(store.grantedConsents["grok.llm"] == nil, "Expected revokeConsent to remove record")
        #expect(store.revoked.contains("grok.llm"), "Expected revoked marker set in store")
    }

    // MARK: - Test 5: consentStatus returns correct status per state

    @Test("ConsentViewModel.consentStatus returns .neverAsked / .onceOnly / .alwaysAllowed")
    static func consentStatusReturnsCorrectStates() async throws {
        let store = MockConsentStore()
        let vm = ConsentViewModel(consentStore: store)

        // No record → .neverAsked
        let never = await vm.consentStatus(provider: .openai, modality: .llm)
        #expect(never == .neverAsked, "Expected .neverAsked when no record")

        // Record with alwaysAllow=false → .onceOnly
        store.setHasConsent(.openai, .asr, true, alwaysAllow: false)
        let once = await vm.consentStatus(provider: .openai, modality: .asr)
        #expect(once == .onceOnly, "Expected .onceOnly when alwaysAllow=false")

        // Record with alwaysAllow=true → .alwaysAllowed
        store.setHasConsent(.anthropic, .llm, true, alwaysAllow: true)
        let always = await vm.consentStatus(provider: .anthropic, modality: .llm)
        #expect(always == .alwaysAllowed, "Expected .alwaysAllowed when alwaysAllow=true")
    }
}

// MARK: - MockConsentStore

/// In-memory mock for testing ConsentViewModel.
///
/// Tracks every grant/revoke call and per-key consent state so tests can
/// assert both the public API behavior and the persistence side effects.
final class MockConsentStore: ConsentStoring, @unchecked Sendable {

    struct StoredConsent: Sendable {
        let alwaysAllow: Bool
        let firstConsentedAt: Date
    }

    private let queue = DispatchQueue(label: "MockConsentStore")
    private var _consents: [String: StoredConsent] = [:]
    private var _revoked: Set<String> = []

    /// Snapshot of currently stored consents (thread-safe copy).
    var grantedConsents: [String: StoredConsent] {
        queue.sync { _consents }
    }

    /// Set of keys explicitly revoked since store creation.
    var revoked: Set<String> {
        queue.sync { _revoked }
    }

    func setHasConsent(_ provider: CloudProvider, _ modality: Modality, _ has: Bool, alwaysAllow: Bool = false) {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        queue.sync {
            if has {
                _consents[key] = StoredConsent(alwaysAllow: alwaysAllow, firstConsentedAt: Date())
            } else {
                _consents.removeValue(forKey: key)
            }
        }
    }

    // MARK: - ConsentStoring

    func hasConsent(provider: CloudProvider, modality: Modality) async -> Bool {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        return queue.sync { _consents[key] != nil }
    }

    func consentRecord(for provider: CloudProvider, modality: Modality) async -> ConsentRecord? {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        return queue.sync {
            guard let stored = _consents[key] else { return nil }
            return ConsentRecord(
                alwaysAllow: stored.alwaysAllow,
                firstConsentedAt: stored.firstConsentedAt
            )
        }
    }

    func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        queue.sync {
            _consents[key] = StoredConsent(alwaysAllow: alwaysAllow, firstConsentedAt: Date())
            _revoked.remove(key)
        }
    }

    func revokeConsent(provider: CloudProvider, modality: Modality) async throws {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        queue.sync {
            _consents.removeValue(forKey: key)
            _revoked.insert(key)
        }
    }

    func load() async throws {}
}
