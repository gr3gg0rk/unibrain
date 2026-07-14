import Foundation

/// Error thrown by ``ModelLoadGate`` when a conflicting model is held.
///
/// Per D-11: deny-on-conflict policy. When a heavy model is already
/// loaded and a different kind is requested, the gate throws `.busy`.
/// The caller decides: retry, queue, or surface to the user.
public enum ModelLoadGateError: Error, Sendable {
    /// A different heavy model is currently held by the gate.
    /// - Parameter currentModel: The model kind currently loaded, if any.
    case busy(currentModel: HeavyModelKind?)
}
