import Testing
import Foundation
@testable import UnibrainCore

@Suite("PermissionState")
struct PermissionStateTests {

    // MARK: - from(CalendarPermissionStatus) mapping

    @Test("from(.fullAccess) returns .granted")
    func fullAccessMapsToGranted() {
        #expect(PermissionState.from(.fullAccess) == .granted)
    }

    @Test("from(.writeOnly) returns .denied (P-05)")
    func writeOnlyMapsToDenied() {
        #expect(PermissionState.from(.writeOnly) == .denied)
    }

    @Test("from(.denied) returns .denied")
    func deniedMapsToDenied() {
        #expect(PermissionState.from(.denied) == .denied)
    }

    @Test("from(.restricted) returns .denied")
    func restrictedMapsToDenied() {
        #expect(PermissionState.from(.restricted) == .denied)
    }

    @Test("from(.notDetermined) returns .notDetermined")
    func notDeterminedMapsToNotDetermined() {
        #expect(PermissionState.from(.notDetermined) == .notDetermined)
    }

    // MARK: - shouldShowFirstTimeSheet

    @Test("shouldShowFirstTimeSheet(.denied, hasShownSheet: false) returns true")
    func firstTimeSheetOnFirstDenied() {
        #expect(
            PermissionState.shouldShowFirstTimeSheet(
                permission: .denied,
                hasShownSheet: false
            ) == true
        )
    }

    @Test("shouldShowFirstTimeSheet(.denied, hasShownSheet: true) returns false")
    func firstTimeSheetSuppressedAfterShown() {
        #expect(
            PermissionState.shouldShowFirstTimeSheet(
                permission: .denied,
                hasShownSheet: true
            ) == false
        )
    }

    @Test("shouldShowFirstTimeSheet(.granted, hasShownSheet: false) returns false")
    func firstTimeSheetSuppressedWhenGranted() {
        #expect(
            PermissionState.shouldShowFirstTimeSheet(
                permission: .granted,
                hasShownSheet: false
            ) == false
        )
    }

    @Test("shouldShowFirstTimeSheet(.notDetermined, hasShownSheet: false) returns false")
    func firstTimeSheetSuppressedWhenNotDetermined() {
        #expect(
            PermissionState.shouldShowFirstTimeSheet(
                permission: .notDetermined,
                hasShownSheet: false
            ) == false
        )
    }
}
