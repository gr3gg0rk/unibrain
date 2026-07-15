import Foundation

/// Protocol-level abstraction for EventKit's `EKAuthorizationStatus`.
///
/// Per P-05: The consumer treats `.writeOnly` identically to `.denied` —
/// only `.fullAccess` can read calendar events. This enum decouples
/// UnibrainCore from EventKit so pure-logic tests run on Linux CI.
///
/// Per D-02: `CalendarEventProvider` protocol lives in UnibrainCore
/// (Linux-buildable); EventKit conformances ship in UnibrainProviders.
public enum CalendarPermissionStatus: Sendable {
    /// Permission has not been requested yet.
    case notDetermined
    /// Full read/write access to calendar events.
    case fullAccess
    /// Write-only access — cannot read events. Treated as denied (P-05).
    case writeOnly
    /// User explicitly denied access.
    case denied
    /// Access restricted by MDM, Screen Time, or parental controls.
    case restricted

    /// Returns `true` only when the status grants full read access.
    ///
    /// Per P-05: `.writeOnly` returns `false` — events cannot be read.
    public var canReadEvents: Bool {
        self == .fullAccess
    }
}

/// Abstracts calendar event access so pure-logic tests run on Linux
/// without Apple frameworks (per D-02, DISC-02).
///
/// Per RESEARCH.md Pattern 1: The protocol lives in UnibrainCore
/// (Linux-buildable). The macOS/iOS EventKit conformance lives in
/// `UnibrainProviders` behind `#if os()` guards.
///
/// Per P-04: `fetchEvents` queries all calendars inclusively
/// (`calendars: nil` in the EventKit conformance).
public protocol CalendarEventProvider: Sendable {

    /// Checks the current authorization status WITHOUT requesting.
    ///
    /// - Returns: The current `CalendarPermissionStatus`.
    func checkAuthorization() async -> CalendarPermissionStatus

    /// Requests full calendar access.
    ///
    /// Per P-05: Returns `true` ONLY if `.fullAccess` is granted,
    /// not `.writeOnly`. The consumer must treat `.writeOnly` as denied.
    ///
    /// - Returns: `true` if full access is granted, `false` otherwise.
    func requestFullAccess() async throws -> Bool

    /// Fetches events in a broad date range from all calendars (P-04).
    ///
    /// Per CT-02: The caller passes a term-range `ClosedRange<Date>` here;
    /// Swift-side ±30min narrowing is applied separately via `TermRangeFilter`.
    ///
    /// - Parameter dateRange: Start and end dates for the query.
    /// - Returns: Array of `CalendarEvent` in the date range.
    /// - Throws: `ProviderError` if permission is denied or the query fails.
    func fetchEvents(in dateRange: ClosedRange<Date>) async throws -> [CalendarEvent]
}
