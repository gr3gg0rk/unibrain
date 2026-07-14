import Foundation

/// A sendable lease representing ownership of the ``ModelLoadGate``.
///
/// Per D-13: the caller scope owns the lease. The lease is `Sendable`
/// because it holds only a `HeavyModelKind` (value type) and a
/// `ModelLoadGate` (actor, implicitly `Sendable`).
///
/// Per D-14: no internal timeout. The caller must call ``release()``
/// explicitly. A `defer` block is the recommended pattern:
///
/// ```swift
/// let lease = try await gate.acquire(.llm)
/// defer { Task { await lease.release() } }
/// // ... run inference ...
/// ```
public struct ModelLease: Sendable {
    /// The model kind this lease grants access to.
    public let kind: HeavyModelKind

    /// The gate this lease belongs to (actor reference, Sendable).
    private let gate: ModelLoadGate

    /// Internal initializer — only ``ModelLoadGate`` creates leases.
    init(kind: HeavyModelKind, gate: ModelLoadGate) {
        self.kind = kind
        self.gate = gate
    }

    /// Release the gate, allowing a different heavy model to be acquired.
    public func release() async {
        await gate.release(kind)
    }
}
