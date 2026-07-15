import Foundation

/// UI-derivable permission state derived from `CalendarPermissionStatus`.
///
/// Per ONBD-03: The UI layer (UnibrainApp) consumes this enum to decide
/// whether calendar-driven features are available, degraded, or awaiting
/// a permission request.
///
/// Per P-05: `.writeOnly`, `.denied`, and `.restricted` all collapse to
/// `.denied` because only `.fullAccess` can read calendar events.
/// Writing the note still works without calendar — the picker fires.
public enum PermissionState: Sendable, Equatable {
    /// Permission not yet requested — UI shows "request access" affordance.
    case notDetermined
    /// Full calendar read/write access — calendar features fully active.
    case granted
    /// Denied, write-only, or restricted — all degrade to manual picker (P-05).
    case denied

    /// Derives the UI-derivable permission state from the raw authorization status.
    ///
    /// Per P-05: `.writeOnly` is treated identically to `.denied` —
    /// only `.fullAccess` grants calendar read access.
    ///
    /// - Parameter status: The current `CalendarPermissionStatus`.
    /// - Returns: The corresponding `PermissionState` for UI consumption.
    public static func from(_ status: CalendarPermissionStatus) -> PermissionState {
        switch status {
        case .fullAccess:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .writeOnly, .denied, .restricted:
            return .denied
        }
    }

    /// Determines whether the one-time explanation sheet should be shown.
    ///
    /// Per P-01: The first time a recording completes with denied permission,
    /// the UI shows an explanatory sheet explaining why the calendar-driven
    /// routing is degraded. Subsequent recordings show a compact banner instead.
    ///
    /// - Parameters:
    ///   - permission: The current derived `PermissionState`.
    ///   - hasShownSheet: Whether the sheet has already been shown in a prior session.
    /// - Returns: `true` only when permission is `.denied` AND the sheet hasn't shown yet.
    public static func shouldShowFirstTimeSheet(
        permission: PermissionState,
        hasShownSheet: Bool
    ) -> Bool {
        permission == .denied && !hasShownSheet
    }
}
