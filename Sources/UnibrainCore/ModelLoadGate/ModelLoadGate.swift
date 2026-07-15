import Foundation

/// Actor that enforces 8GB RAM discipline: only one heavy local model
/// loaded at a time.
///
/// Per D-11: deny-on-conflict policy. If `currentModel` exists and
/// differs from the requested kind, `acquire` throws `.busy`.
///
/// Per D-13: callers acquire a ``ModelLease`` before loading a model
/// and call `release()` when done.
///
/// Per D-14: no internal timeout. The caller owns the lease until
/// explicit release. Process restart reclaims RAM on crash.
///
/// Data-race safety (T-01-03): Swift 6 actor isolation serializes
/// all access to `currentModel` by language guarantee.
public actor ModelLoadGate {
    /// Shared singleton instance for app-wide model gating.
    public static let shared = ModelLoadGate()

    /// The currently held model kind, or `nil` if the gate is free.
    private var currentModel: HeavyModelKind? = nil

    public init() {}

    /// Attempt to acquire a lease for the given model kind.
    ///
    /// - If the gate is free or already holds the same kind, succeeds
    ///   and returns a ``ModelLease``.
    /// - If a different kind is held, throws ``ModelLoadGateError/busy(currentModel:)``.
    ///
    /// - Parameter kind: The heavy model kind to acquire.
    /// - Returns: A ``ModelLease`` owned by the caller.
    /// - Throws: ``ModelLoadGateError`` if a conflicting model is held.
    public func acquire(_ kind: HeavyModelKind) async throws -> ModelLease {
        if let current = currentModel, current != kind {
            throw ModelLoadGateError.busy(currentModel: current)
        }
        currentModel = kind
        return ModelLease(kind: kind, gate: self)
    }

    /// Release the gate for the given model kind.
    ///
    /// Only clears `currentModel` if it matches `kind`, preventing
    /// accidental release by a stale lease from a prior kind.
    ///
    /// - Parameter kind: The heavy model kind to release.
    public func release(_ kind: HeavyModelKind) async {
        if currentModel == kind {
            currentModel = nil
        }
    }
}
