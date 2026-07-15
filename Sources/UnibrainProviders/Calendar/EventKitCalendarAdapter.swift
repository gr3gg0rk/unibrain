import Foundation
#if os(macOS) || os(iOS)
import EventKit
import UnibrainCore

/// EventKit-backed conformance to `CalendarEventProvider` for macOS and iOS.
///
/// Per P-03: Both macOS and iOS adapters ship in Phase 4 behind
/// `#if os(macOS) || os(iOS)` guards. The iOS conformance is code-complete
/// but untested on device (Phase 5 activates iOS capture).
///
/// Per RESEARCH.md Pattern 1: Wraps `EKEventStore` behind the
/// `CalendarEventProvider` protocol so pure-logic tests in UnibrainCore
/// run on Linux without EventKit.
///
/// Per P-04: Queries all calendars inclusively (`calendars: nil`).
/// Per P-05: Verifies `.fullAccess` explicitly — `.writeOnly` treated as denied.
///
/// Per T-04-06 (mitigate): The adapter is an actor, so `fetchEvents` runs
/// in actor isolation and never blocks MainActor. `store.events(matching:)`
/// is synchronous but executes safely within the actor context.
///
/// No `#if os(iOS)` specific code is needed — the same EventKit API
/// works on both platforms.
public actor EventKitCalendarAdapter: CalendarEventProvider {

    /// The EventKit store. Created once, reused for all queries.
    ///
    /// `EKEventStore` is not `Sendable`, which is why this type is an actor.
    /// Actor isolation serializes all access.
    private let store = EKEventStore()

    /// Creates an adapter. No parameters needed — EKEventStore is always
    /// available on macOS/iOS.
    public init() {}

    // MARK: - CalendarEventProvider Conformance

    /// Checks the current authorization status WITHOUT requesting.
    ///
    /// Maps `EKAuthorizationStatus` to `CalendarPermissionStatus`.
    /// Per P-05: `.writeOnly` is returned as-is so the consumer can treat
    /// it as denied.
    public func checkAuthorization() async -> CalendarPermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            // Safe fallback for future cases.
            return .denied
        }
    }

    /// Requests full calendar access.
    ///
    /// Per P-05: Returns `true` ONLY if `.fullAccess` is granted.
    /// The `Bool` from `requestFullAccessToEvents()` can be `true` for
    /// write-only on some iOS versions, so we verify the authorization
    /// status explicitly after the request completes.
    ///
    /// Per RESEARCH.md Pitfall 1: Never trust just the `granted` bool —
    /// always check `authorizationStatus(for: .event) == .fullAccess`.
    ///
    /// If the request throws, we return `false` — permission denial is
    /// a user choice, not an exceptional condition.
    public func requestFullAccess() async throws -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else { return false }
            // P-05: Verify .fullAccess explicitly.
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } catch {
            return false
        }
    }

    /// Fetches events in a date range from all calendars (P-04).
    ///
    /// Per CT-02: The caller passes a term-range `ClosedRange<Date>` here.
    /// Swift-side ±30min narrowing is applied separately via `TermRangeFilter`.
    ///
    /// Per T-04-04 (mitigate): Checks `authorizationStatus == .fullAccess`
    /// before every query. Never caches permission — may be revoked via
    /// Settings while the app runs.
    ///
    /// Per P-04: `calendars: nil` queries all calendar sources inclusively
    /// (iCloud, Google, Outlook, local).
    public func fetchEvents(in dateRange: ClosedRange<Date>) async throws -> [CalendarEvent] {
        // T-04-04: Verify permission on every fetch.
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw ProviderError.underlying(
                NSError(
                    domain: "EventKit",
                    code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "Calendar full access not granted"]
                )
            )
        }

        // P-04: Query all calendars inclusively (calendars: nil).
        let predicate = store.predicateForEvents(
            withStart: dateRange.lowerBound,
            end: dateRange.upperBound,
            calendars: nil
        )

        // EventKit auto-expands recurring events into individual occurrences.
        // This is synchronous but runs in actor isolation (T-04-06 mitigation).
        let ekEvents = store.events(matching: predicate)

        // Map EKEvent → CalendarEvent at the boundary.
        return ekEvents.map { ekEvent in
            CalendarEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title ?? "Untitled",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                location: ekEvent.location
            )
        }
    }
}

#endif  // os(macOS) || os(iOS)
