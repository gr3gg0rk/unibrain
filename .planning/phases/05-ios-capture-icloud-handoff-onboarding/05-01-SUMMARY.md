---
phase: 05-ios-capture-icloud-handoff-onboarding
plan: 01
subsystem: ui
tags: [swiftui, onboarding, keychain, security-scoped-bookmark, permissions, tabview]

# Dependency graph
requires:
  - phase: 04-course-classification-smart-routing
    provides: CourseMappingStore, PermissionState, EventKitCalendarAdapter, TermDefinition
provides:
  - BookmarkStore — Keychain-backed security-scoped bookmark persistence
  - OnboardingViewModel — page state machine for first-run wizard
  - OnboardingFlow — TabView(.page) wizard shell with platform-aware pages
  - PermissionsSheet — post-onboarding permission audit with Settings deep-links
  - Info.plist keys — NSMicrophoneUsageDescription, NSCalendarsUsageDescription, UIBackgroundModes
affects: [05-02-ios-capture, 05-03-icloud-handoff, 06-cloud-provider-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Security-scoped bookmark persistence via Keychain (T-05-01 mitigation)"
    - "TabView(.page) cross-platform onboarding wizard with #if os(macOS) term page"
    - "@AppStorage(hasCompletedOnboarding) conditional rendering in App entry"
    - "Stale bookmark detection returning nil for re-prompt (T-05-03 mitigation)"

key-files:
  created:
    - Sources/UnibrainProviders/Security/BookmarkStore.swift
    - UnibrainApp/ViewModels/OnboardingViewModel.swift
    - UnibrainApp/Views/PermissionsSheet.swift
    - UnibrainApp/Views/Onboarding/OnboardingFlow.swift
    - UnibrainApp/Views/Onboarding/OnboardingWelcomePage.swift
    - UnibrainApp/Views/Onboarding/OnboardingVaultPage.swift
    - UnibrainApp/Views/Onboarding/OnboardingMicPage.swift
    - UnibrainApp/Views/Onboarding/OnboardingCalendarPage.swift
    - UnibrainApp/Views/Onboarding/OnboardingTermPage.swift
    - UnibrainApp/Views/Onboarding/OnboardingReadyPage.swift
    - Tests/UnibrainProvidersTests/Security/BookmarkStoreTests.swift
    - Tests/UnibrainAppTests/Onboarding/OnboardingViewModelTests.swift
  modified:
    - UnibrainApp/UnibrainApp.swift
    - UnibrainApp/ContentView.swift
    - UnibrainApp/Info.plist

key-decisions:
  - "BookmarkStore stores per-device in Keychain with kSecAttrAccessibleWhenUnlocked, not UserDefaults"
  - "OnboardingViewModel uses @Observable @MainActor matching Phase 3/4 patterns"
  - "OnboardingTermPage is #if os(macOS) only — iOS inherits term via courses.json (ONB-01)"
  - "PermissionsSheet uses Form with grouped sections — standard SwiftUI pattern for settings"

patterns-established:
  - "BookmarkStore.save/resolve/clear static API — Keychain-backed security-scoped bookmark persistence"
  - "OnboardingPage enum with platformPages static var — platform-aware page list"
  - "canAdvance(from:) — per-page HARD-FAIL/OPTIONAL gate logic"

requirements-completed: [ONBD-01, ONBD-04, ONBD-05]

coverage:
  - id: D1
    description: "BookmarkStore encodes/decodes security-scoped bookmarks to/from Keychain"
    requirement: "ONBD-04"
    verification:
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Security/BookmarkStoreTests.swift#saveThenResolveReturnsSameURL"
        status: unknown
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Security/BookmarkStoreTests.swift#resolveReturnsNilWhenEmpty"
        status: unknown
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Security/BookmarkStoreTests.swift#clearRemovesBookmark"
        status: unknown
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Security/BookmarkStoreTests.swift#saveThrowsForNonExistentPath"
        status: unknown
    human_judgment: true
    rationale: "BookmarkStoreTests are behind #if os(macOS)||os(iOS) — require macOS CI runner to execute; status unknown until CI run"
  - id: D2
    description: "Onboarding wizard 6-page macOS / 5-page iOS flow with permission gates"
    requirement: "ONBD-01"
    verification:
      - kind: unit
        ref: "Tests/UnibrainAppTests/Onboarding/OnboardingViewModelTests.swift#advanceBlocksOnVaultWhenEmpty"
        status: unknown
      - kind: unit
        ref: "Tests/UnibrainAppTests/Onboarding/OnboardingViewModelTests.swift#advanceBlocksOnMicWhenNotGranted"
        status: unknown
      - kind: unit
        ref: "Tests/UnibrainAppTests/Onboarding/OnboardingViewModelTests.swift#advanceAlwaysSucceedsOnCalendar"
        status: unknown
      - kind: unit
        ref: "Tests/UnibrainAppTests/Onboarding/OnboardingViewModelTests.swift#completeOnboardingSetsFlag"
        status: unknown
    human_judgment: true
    rationale: "UnibrainAppTests target is Xcode-only, not SPM — runs on macOS CI. UI rendering is manual device verification."
  - id: D3
    description: "PermissionsSheet shows live mic/calendar/vault status with Settings deep-links"
    requirement: "ONBD-05"
    verification: []
    human_judgment: true
    rationale: "Pure SwiftUI view — manual verification on macOS/iOS device required for UI correctness"
  - id: D4
    description: "Info.plist contains NSMicrophoneUsageDescription, NSCalendarsUsageDescription, UIBackgroundModes"
    requirement: "ONBD-04"
    verification:
      - kind: unit
        ref: "UnibrainApp/Info.plist"
        status: pass
    human_judgment: false

# Metrics
duration: 7min
completed: 2026-07-16
status: complete
---

# Phase 5 Plan 01: Onboarding Wizard + BookmarkStore + PermissionsSheet Summary

**First-run onboarding wizard with Keychain-backed security-scoped bookmark persistence, 6-page macOS / 5-page iOS TabView flow, and post-onboarding permissions audit sheet**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-16T02:28:08Z
- **Completed:** 2026-07-16T02:35:08Z
- **Tasks:** 2
- **Files modified:** 15 (12 created, 3 modified)

## Accomplishments

- BookmarkStore: Keychain-backed security-scoped bookmark persistence (save/resolve/clear) with stale-bookmark detection
- OnboardingViewModel: @Observable page state machine with HARD-FAIL mic gate, OPTIONAL calendar, macOS-only term page
- Full 6-page (macOS) / 5-page (iOS) onboarding wizard: Welcome, Vault, Mic, Calendar, Term (macOS only), Ready
- PermissionsSheet: live mic/calendar/vault status display with "Open System Settings" deep-links and folder re-pick
- App entry conditional rendering via @AppStorage(hasCompletedOnboarding)
- Info.plist with NSMicrophoneUsageDescription, NSCalendarsUsageDescription, UIBackgroundModes audio

## Task Commits

Each task was committed atomically:

1. **Task 1: BookmarkStore + OnboardingViewModel + PermissionsSheet** - `a16a5a6` (feat)
2. **Task 2: Onboarding wizard views + app entry wiring** - `374b801` (feat)

## Files Created/Modified

### Created
- `Sources/UnibrainProviders/Security/BookmarkStore.swift` - Keychain-backed security-scoped bookmark persistence
- `UnibrainApp/ViewModels/OnboardingViewModel.swift` - @Observable page state machine for onboarding
- `UnibrainApp/Views/PermissionsSheet.swift` - Post-onboarding permission audit sheet
- `UnibrainApp/Views/Onboarding/OnboardingFlow.swift` - TabView(.page) wizard shell
- `UnibrainApp/Views/Onboarding/OnboardingWelcomePage.swift` - App icon + value prop + Get Started
- `UnibrainApp/Views/Onboarding/OnboardingVaultPage.swift` - .fileImporter with iCloud Drive suggestion
- `UnibrainApp/Views/Onboarding/OnboardingMicPage.swift` - Mic permission request (HARD-FAIL)
- `UnibrainApp/Views/Onboarding/OnboardingCalendarPage.swift` - Calendar permission request (OPTIONAL)
- `UnibrainApp/Views/Onboarding/OnboardingTermPage.swift` - Term label + date pickers (macOS only)
- `UnibrainApp/Views/Onboarding/OnboardingReadyPage.swift` - Completion + dismiss
- `Tests/UnibrainProvidersTests/Security/BookmarkStoreTests.swift` - Bookmark round-trip tests
- `Tests/UnibrainAppTests/Onboarding/OnboardingViewModelTests.swift` - 11 non-UI logic tests

### Modified
- `UnibrainApp/UnibrainApp.swift` - Conditional onboarding/main rendering, iOS init path
- `UnibrainApp/ContentView.swift` - Added Manage Permissions button + sheet
- `UnibrainApp/Info.plist` - Added microphone, calendar, background audio keys

## Decisions Made

- **BookmarkStore uses static methods** (not instance) — mirrors KeychainHelper convention, no state needed
- **BookmarkStoreError uses Int32 for OSStatus** instead of importing Security.OSStatus type alias — keeps Linux compilation clean
- **OnboardingPage enum with platformPages** — clean platform-aware page list via #if os(macOS)
- **UnibrainApp init wraps iOS path separately** — per Pitfall 6, PipelineWiring is macOS-only; iOS gets manual construction

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed BookmarkStoreError OSStatus typealias Linux compilation**
- **Found during:** Task 1 (BookmarkStore implementation)
- **Issue:** `OSStatus` typealias was guarded behind `#if os(macOS) || os(iOS)` but the error enum used it unconditionally, causing Equatable synthesis failure on Linux
- **Fix:** Changed to plain `Int32` type, removed the platform-guarded typealias
- **Files modified:** Sources/UnibrainProviders/Security/BookmarkStore.swift
- **Verification:** `swift build` succeeds on Linux; `swift test` passes 200 tests
- **Committed in:** a16a5a6 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minimal — compilation fix for cross-platform compatibility. No scope creep.

## Issues Encountered

None — plan executed cleanly. All SPM tests pass (200/200). Xcode target files compile on macOS CI only (not buildable from WSL2/Linux).

## User Setup Required

None - no external service configuration required. All code uses Apple built-in frameworks.

## Next Phase Readiness

- Onboarding flow is complete and ready for Plan 02 (iOS capture TabView shell) to consume
- BookmarkStore is available for Plan 02/03 to resolve the vault URL on app launch
- PermissionsSheet is ready for Plan 02's iOS Settings tab to embed
- Info.plist has all required keys for Plan 02's background audio recording
- iOS device verification deferred (requires Apple Developer Program + physical iPhone)

---
*Phase: 05-ios-capture-icloud-handoff-onboarding*
*Completed: 2026-07-16*
