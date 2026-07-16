import Foundation
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
import UnibrainCore
import UnibrainProviders

/// Onboarding page identifiers for the page-style TabView.
///
/// Per ONB-02: macOS gets 6 pages (Welcome, Vault, Mic, Calendar, Term, Ready).
/// Per ONB-01: iOS gets 5 pages (no Term — inherits via courses.json).
enum OnboardingPage: Int, CaseIterable, Sendable {
    case welcome = 0
    case vault = 1
    case mic = 2
    case calendar = 3
    case term = 4
    case ready = 5

    /// Returns the page list for the current platform.
    ///
    /// Per ONB-01: macOS includes all 6 pages. iOS skips the Term page
    /// (5 pages total). On iOS, if `inheritedTermLabel` is set, the Term
    /// page is suppressed because the term was inherited from macOS via
    /// courses.json.
    static var platformPages: [OnboardingPage] {
        #if os(macOS)
        return [.welcome, .vault, .mic, .calendar, .term, .ready]
        #else
        return [.welcome, .vault, .mic, .calendar, .ready]
        #endif
    }
}

/// @Observable driver for the onboarding page-style TabView state machine.
///
/// Per ONB-02: Manages a TabView(.page) wizard with progress dots.
/// Per ONBD-01: First-run flow from Welcome through Ready.
/// Per ONBD-02: Mic permission is HARD-FAIL — advance blocked if denied.
/// Per ONBD-03: Calendar permission is OPTIONAL — advance allowed regardless.
/// Per ONB-01 (macOS): Includes Term page for label + date range input.
/// Per ONB-01 (iOS): Term page suppressed — inherited via courses.json.
@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Page State

    /// Current page index in the TabView.
    var currentPage: Int = 0

    // MARK: - Vault State (ONBD-04)

    /// The user-picked vault folder URL.
    var selectedVaultURL: URL?

    // MARK: - Permission State (ONBD-02, ONBD-03)

    /// Microphone permission status (HARD-FAIL — advance blocked if not granted).
    var micPermissionStatus: PermissionState = .notDetermined

    /// Calendar permission status (OPTIONAL — advance allowed regardless).
    var calendarPermissionStatus: PermissionState = .notDetermined

    // MARK: - Term State (CT-01, macOS only)

    /// User-entered term label (e.g., "Fall 2026").
    var termLabel: String = ""

    /// Term start date (defaults to today).
    var termStartDate: Date = Date()

    /// Term end date (defaults to today + 4 months — standard semester).
    var termEndDate: Date = Calendar.current.date(
        byAdding: .month,
        value: 4,
        to: Date()
    ) ?? Date()

    // MARK: - iOS Inheritance (ONB-01)

    /// Set when iOS detects `.unibrain/courses.json` in the picked folder.
    /// Suppresses the Term page and shows the inherited term name.
    var inheritedTermLabel: String?

    // MARK: - Vault Inheritance Banner

    /// True when iOS vault pick found no courses.json — shows "set up Mac first" banner.
    var showMacFirstBanner: Bool = false

    // MARK: - Course Mapping Store (for term saving)

    private let courseMappingStore: CourseMappingStore?

    // MARK: - Init

    init(courseMappingStore: CourseMappingStore? = nil) {
        self.courseMappingStore = courseMappingStore
    }

    // MARK: - Page Navigation

    /// The list of pages for this platform.
    var pages: [OnboardingPage] {
        OnboardingPage.platformPages
    }

    /// Total page count for this platform.
    var pageCount: Int {
        pages.count
    }

    /// Advances to the next page if the current page's requirements are met.
    ///
    /// Per ONBD-02: Mic is HARD-FAIL — advance blocked from the mic page
    /// if micPermissionStatus != .granted.
    ///
    /// Returns `true` if advance succeeded, `false` if blocked.
    @discardableResult
    func advance() -> Bool {
        guard currentPage < pages.count - 1 else { return false }

        let current = pages[currentPage]
        if !canAdvance(from: current) { return false }

        currentPage += 1
        return true
    }

    /// Whether the user can advance from the given page.
    ///
    /// Encodes the HARD-FAIL / OPTIONAL logic:
    /// - Vault: requires selectedVaultURL != nil
    /// - Mic: requires micPermissionStatus == .granted (HARD-FAIL per ONBD-02)
    /// - Calendar: always allowed (OPTIONAL per ONBD-03)
    /// - Term: requires termLabel non-empty (macOS only)
    /// - Ready/Welcome: always allowed
    func canAdvance(from page: OnboardingPage) -> Bool {
        switch page {
        case .welcome:
            return true
        case .vault:
            return selectedVaultURL != nil
        case .mic:
            // ONBD-02: HARD-FAIL — mic must be granted.
            return micPermissionStatus == .granted
        case .calendar:
            // ONBD-03: OPTIONAL — advance regardless.
            return true
        case .term:
            // Term label must be non-empty.
            return !termLabel.trimmingCharacters(in: .whitespaces).isEmpty
        case .ready:
            return false
        }
    }

    // MARK: - Vault Picker (ONBD-04)

    /// Called when the user picks a vault folder via .fileImporter.
    ///
    /// Saves the security-scoped bookmark via BookmarkStore (ONB-03).
    /// On iOS, probes for `.unibrain/courses.json` to inherit term/config.
    ///
    /// - Parameter url: The user-picked folder URL.
    func pickVault(url: URL) {
        selectedVaultURL = url

        // Persist the bookmark for cross-launch access (ONB-03).
        do {
            try BookmarkStore.save(for: url)
        } catch {
            // Bookmark save failed — the URL is valid for this session
            // but won't persist. The app still works; user may need to
            // re-pick on next launch.
        }

        // iOS: detect inherited config from courses.json (ONB-01).
        detectInheritedConfig(vaultURL: url)
    }

    // MARK: - Permission Requests

    /// Requests microphone permission.
    ///
    /// Per ONBD-02: HARD-FAIL — the Continue button on the mic page stays
    /// disabled until this returns `.granted`.
    func requestMicPermission() async {
        #if os(macOS)
        let granted = await AVAudioApplication.requestRecordPermission()
        micPermissionStatus = granted ? .granted : .denied
        #elseif os(iOS)
        // Per D-05: AVAudioSession on iOS.
        let granted = await AVAudioApplication.requestRecordPermission()
        micPermissionStatus = granted ? .granted : .denied
        #endif
    }

    /// Requests calendar Full Access permission.
    ///
    /// Per ONBD-03: OPTIONAL — the Continue button is enabled regardless.
    func requestCalendarPermission() async {
        #if os(macOS) || os(iOS)
        let adapter = EventKitCalendarAdapter()
        do {
            let granted = try await adapter.requestFullAccess()
            calendarPermissionStatus = granted ? .granted : .denied
        } catch {
            calendarPermissionStatus = .denied
        }
        #endif
    }

    // MARK: - Term Management (CT-01, macOS only)

    /// Saves the current term to CourseMappingStore.
    ///
    /// Per CT-01: Writes `{ label, startDate, endDate }` to courses.json
    /// inside the picked vault folder.
    func saveTerm() async {
        guard let store = courseMappingStore else { return }
        try? await store.setCurrentTerm(
            label: termLabel,
            startDate: termStartDate,
            endDate: termEndDate
        )
    }

    // MARK: - Completion (ONBD-01)

    /// Marks onboarding as complete.
    ///
    /// Per ONBD-01: Sets `hasCompletedOnboarding = true` in UserDefaults.
    /// The app dismisses the onboarding flow and shows the main UI.
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: OnboardingViewModel.hasCompletedOnboardingKey)
    }

    // MARK: - iOS Config Inheritance (ONB-01)

    /// Probes the picked vault folder for `.unibrain/courses.json`.
    ///
    /// Per ONB-01: On iOS, if courses.json exists, reads `currentTerm` and
    /// course mappings. Sets `inheritedTermLabel` so the Term page is skipped.
    /// If courses.json is not found, sets `showMacFirstBanner` to display the
    /// "Open unibrain on your Mac first" banner.
    func detectInheritedConfig(vaultURL: URL) {
        #if os(iOS)
        let coursesJSON = vaultURL
            .appendingPathComponent(".unibrain")
            .appendingPathComponent("courses.json")

        guard FileManager.default.fileExists(atPath: coursesJSON.path) else {
            showMacFirstBanner = true
            return
        }

        // Attempt to read and decode the term.
        if let data = FileManager.default.contents(atPath: coursesJSON.path) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let doc = try? decoder.decode(CourseMappingDocument.self, from: data) {
                if !doc.currentTerm.label.isEmpty {
                    inheritedTermLabel = doc.currentTerm.label
                    // Also populate termLabel so saveTerm doesn't overwrite
                    // with empty.
                    termLabel = doc.currentTerm.label
                    termStartDate = doc.currentTerm.startDate
                    termEndDate = doc.currentTerm.endDate
                }
            }
        }
        #endif
    }

    // MARK: - Constants

    /// UserDefaults key for the onboarding completion flag.
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
}
