import Testing
import Foundation
@testable import UnibrainApp

// Tests for OnboardingViewModel non-UI logic.
//
// Validates ONBD-01: hasCompletedOnboarding flag.
// Validates ONBD-02: mic HARD-FAIL advance blocking.
// Validates ONBD-03: calendar OPTIONAL advance.
// Validates ONB-01: iOS page list excludes Term.
// Validates CT-01: term label/date state.
//
// These tests run on Linux/macOS CI without iOS Simulator.
// UI layout / page rendering is manual-only (see VALIDATION.md).

@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {

    // MARK: - Test 1: completeOnboarding sets UserDefaults flag

    @Test("completeOnboarding sets hasCompletedOnboarding to true")
    func completeOnboardingSetsFlag() {
        let vm = OnboardingViewModel()

        // Ensure clean state.
        UserDefaults.standard.set(false, forKey: OnboardingViewModel.hasCompletedOnboardingKey)

        vm.completeOnboarding()

        let flag = UserDefaults.standard.bool(forKey: OnboardingViewModel.hasCompletedOnboardingKey)
        #expect(flag == true)

        // Cleanup.
        UserDefaults.standard.set(false, forKey: OnboardingViewModel.hasCompletedOnboardingKey)
    }

    // MARK: - Test 2: advance increments currentPage

    @Test("advance increments currentPage from welcome")
    func advanceIncrementsPage() {
        let vm = OnboardingViewModel()

        #expect(vm.currentPage == 0)

        let advanced = vm.advance()

        #expect(advanced == true)
        #expect(vm.currentPage == 1)
    }

    // MARK: - Test 3: advance blocks when vault not picked

    @Test("advance blocks on vault page when no URL selected")
    func advanceBlocksOnVaultWhenEmpty() {
        let vm = OnboardingViewModel()
        vm.currentPage = 1 // Vault page.

        #expect(vm.selectedVaultURL == nil)

        let advanced = vm.advance()

        #expect(advanced == false)
        #expect(vm.currentPage == 1) // Still on vault page.
    }

    // MARK: - Test 4: advance blocks on mic page when not granted

    @Test("advance blocks on mic page when permission not granted")
    func advanceBlocksOnMicWhenNotGranted() {
        let vm = OnboardingViewModel()
        vm.currentPage = 2 // Mic page.
        vm.micPermissionStatus = .denied

        let advanced = vm.advance()

        #expect(advanced == false)
        #expect(vm.currentPage == 2) // Still on mic page.
    }

    // MARK: - Test 5: advance allowed on mic page when granted

    @Test("advance succeeds on mic page when permission granted")
    func advanceSucceedsOnMicWhenGranted() {
        let vm = OnboardingViewModel()
        vm.currentPage = 2 // Mic page.
        vm.micPermissionStatus = .granted

        let advanced = vm.advance()

        #expect(advanced == true)
        #expect(vm.currentPage == 3)
    }

    // MARK: - Test 6: calendar is OPTIONAL — advance always works

    @Test("advance always succeeds on calendar page regardless of permission")
    func advanceAlwaysSucceedsOnCalendar() {
        // Denied calendar.
        let vm1 = OnboardingViewModel()
        vm1.currentPage = 3
        vm1.calendarPermissionStatus = .denied
        #expect(vm1.advance() == true)

        // Granted calendar.
        let vm2 = OnboardingViewModel()
        vm2.currentPage = 3
        vm2.calendarPermissionStatus = .granted
        #expect(vm2.advance() == true)
    }

    // MARK: - Test 7: term page blocks when label is empty

    @Test("advance blocks on term page when label is empty")
    @available(macOS 10.15, iOS 13.0, *)
    func advanceBlocksOnTermWhenEmpty() {
        let vm = OnboardingViewModel()
        vm.termLabel = ""

        let canAdvance = vm.canAdvance(from: .term)
        #expect(canAdvance == false)
    }

    // MARK: - Test 8: term page allows advance when label non-empty

    @Test("canAdvance on term page succeeds when label is non-empty")
    func advanceSucceedsOnTermWhenLabelSet() {
        let vm = OnboardingViewModel()
        vm.termLabel = "Fall 2026"

        let canAdvance = vm.canAdvance(from: .term)
        #expect(canAdvance == true)
    }

    // MARK: - Test 9: platform page count

    @Test("pageCount returns correct count for platform")
    func pageCountIsCorrect() {
        let vm = OnboardingViewModel()

        #if os(macOS)
        // macOS: Welcome, Vault, Mic, Calendar, Term, Ready = 6
        #expect(vm.pageCount == 6)
        #else
        // iOS: Welcome, Vault, Mic, Calendar, Ready = 5
        #expect(vm.pageCount == 5)
        #endif
    }

    // MARK: - Test 10: vault pick sets selectedVaultURL

    @Test("pickVault sets selectedVaultURL")
    func pickVaultSetsURL() {
        let vm = OnboardingViewModel()
        let url = URL(fileURLWithPath: "/tmp/test-vault-\(UUID().uuidString)")

        vm.pickVault(url: url)

        #expect(vm.selectedVaultURL != nil)
        #expect(vm.selectedVaultURL?.path == url.path)
    }

    // MARK: - Test 11: advance from vault succeeds after pick

    @Test("advance succeeds on vault page after picking URL")
    func advanceSucceedsAfterPick() {
        let vm = OnboardingViewModel()
        vm.currentPage = 1
        vm.pickVault(url: URL(fileURLWithPath: "/tmp/test-vault"))

        let advanced = vm.advance()
        #expect(advanced == true)
        #expect(vm.currentPage == 2)
    }
}
