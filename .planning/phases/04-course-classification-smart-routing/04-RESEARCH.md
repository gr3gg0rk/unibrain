# Phase 4: Course Classification + Smart Routing - Research

**Researched:** 2026-07-15
**Domain:** EventKit calendar integration, Swift 6 actor concurrency (pause/resume), SwiftUI MenuBarExtra UI extension, file-based JSON persistence
**Confidence:** HIGH

## Summary

Phase 4 is the competitive moat — wiring Apple Calendar (EventKit) to the pipeline so recordings auto-route to the correct course folder. The core technical challenge is four-fold: (1) an EventKit adapter layer behind a protocol that compiles on both macOS and iOS, (2) a pause/resume mechanism in the `PipelineOrchestrator` actor so the pipeline can park at `.classifying` when the manual picker fires, (3) a vault-side JSON mapping table (`.unibrain/courses.json`) that auto-learns event-title-to-course-code mappings, and (4) a permission-degradation UX that gracefully handles denied or write-only-only calendar access.

The existing codebase provides clean extension points. Phase 2 shipped `CalendarEvent`, `CourseClassifier`, `CourseMatch`, `FolderNameSanitizer`, `PipelineState`, `PipelineInputs`, `PipelineOrchestrator`, `VaultPathResolver`, and `NoteWriter` — all as protocols or pure-logic structs in `UnibrainCore`. Phase 3 shipped `HardcodedVaultResolver` (which Phase 4 replaces), `NSFileCoordinatorNoteWriter`, `PipelineWiring`, and the `MenuBarPopover`/`MenuBarViewModel` surface. Phase 4 replaces the hardcoded resolver with a schedule-aware one, extends the orchestrator state machine, and adds new SwiftUI surfaces to the menu-bar popover.

The riskiest change is the `.awaitingUserChoice` orchestrator extension. `CheckedContinuation` is the right Swift 6 primitive for parking an actor mid-run, but there is a known Swift issue (SR-14875) where resuming continuations from within actor isolation contexts can hang. The safer pattern is to store the continuation as actor state and resume it from outside the actor (the UI layer calls a `resume(selection:)` method). The second risk is that `.sheet` on `MenuBarExtra(.window)` is unreliable on macOS — the recommended approach is inline view-state switching within the popover, not a modal `.sheet`.

**Primary recommendation:** Use `CheckedContinuation` stored as an optional actor property for pipeline pause/resume. Use inline view-state switching in the popover (not `.sheet`) for the course picker. Query EventKit with `predicateForEvents(withStart: termStart, end: termEnd, calendars: nil)` then Swift-filter by ±30min recording window. Treat `.writeOnly` as denied (degrade to manual picker).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Mapping Table (CLAS-02):**
- M-01: Vault-side JSON at `.unibrain/courses.json` — lives inside vault root so iCloud Drive syncs it between devices
- M-02: Auto-learn on encounter (empty default) — first recording during unmapped event triggers folder creation + mapping update; no first-run calendar scan
- M-03: Manual pick updates BOTH mapping AND recent list — recurring lectures get automated; ad-hoc picks help via recent shortcut
- M-04: Minimal in-app Manage Courses sheet (~50-100 lines SwiftUI) — editable table view in menu-bar popover, becomes Phase 6 Settings courses tab

**Permission Degradation (ONBD-02, ONBD-03):**
- P-01: First-time sheet + ongoing banner — one-time explanation sheet on first denied recording; compact tappable banner on subsequent recordings
- P-02: Permission request fires on first recording — just-in-time mic + calendar together
- P-03: macOS + iOS EventKit adapters BOTH ship in Phase 4 — iOS compiles but untested on device
- P-04: All calendars queried inclusively — `calendars: nil` in predicate; no per-calendar toggle
- P-05: Verify `.fullAccess` explicitly — treat `.writeOnly` as denied (same degradation flow)

**Manual Picker (CLAS-04):**
- MP-01: Sheet on menu-bar popover — compact ~280pt width matching Phase 3 popover
- MP-02: Recent (5) + All Courses (current term) — MRU ordering, search field at top
- MP-03: Create New + Skip escape hatches — Create New makes folder+mapping; Skip routes to `{vault}/{term}/_unsorted/`
- MP-04: Picker fires at `.classifying` step — orchestrator pauses, resumes on user selection
- MP-05: Multi-match shows events with details — title + time range + location as distinct rows

**Current Term (CLAS-05, CLAS-06):**
- CT-01: Single term + date range — `{ label, startDate, endDate }` in `.unibrain/courses.json`
- CT-02: EventKit query filters to `[term.startDate, term.endDate]` — ±30min window applied as Swift-side filter
- CT-03: Auto-detect term-end nudge — non-blocking banner when `today > currentTerm.endDate`
- CT-04: Folder path uses sanitized term label — `{vault}/{term}/{course-code}/`

### Claude's Discretion

- Course code derivation from unrecognized event titles (sanitized title vs slugified vs pattern-extracted)
- `courses.json` schema shape (field names, nesting, versioning — `schema_version: 1` recommended)
- EventKit predicate composition (single predicate vs Swift-side filtering)
- `EKEvent` -> `CalendarEvent` adapter specifics (recurring event handling)
- `.awaitingUserChoice` orchestrator state design (new top-level case vs sub-state; pause/resume mechanics)
- macOS System Settings deep-link URL scheme
- First-time-sheet microcopy
- "Recent" courses ordering (MRU vs MFU — MRU recommended)
- Manage Courses sheet exact layout
- Folder sanitizer output for term label (preserve "Fall 2026" vs slugify to "fall-2026")

### Deferred Ideas (OUT OF SCOPE)

- Full Settings UI -> Phase 6 (CLOUD-01)
- Per-calendar toggle -> Phase 6 Settings
- First-run onboarding flow -> Phase 5 (ONBD-01)
- iOS capture activation -> Phase 5 (CAPT-03)
- iCloud Drive `_inbox/` pickup -> Phase 5
- "Regenerate with whisper.cpp" action -> Phase 6 polish
- Embeddings index / semantic search -> Phase 2 v2 (EMBD-01..04)
- Syllabus parsing -> Phase 2 v2 (SYLL-01..03)
- Confidence score in CourseMatch -> v2
- One-time-only manual pick toggle -> Phase 6 polish
- Multi-speaker diarization -> v2
- Cloud ASR providers -> Phase 6 (CLOUD-03..06)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLAS-01 | EventKit queries calendar events overlapping `recordingStart +/- 30min` | EventKit adapter in `UnibrainProviders` wrapping `EKEventStore`; term-range predicate + Swift-side ±30min filter. See Architecture Pattern 1. |
| CLAS-02 | Maps matched event title -> course folder via settings-driven mapping table | `.unibrain/courses.json` Codable schema in `UnibrainCore`; `CourseMappingStore` actor reads/writes. See Architecture Pattern 3. |
| CLAS-03 | Auto-creates sanitized course folder for unrecognized event titles | `FolderNameSanitizer.sanitize()` already exists from Phase 2; auto-learn flow updates mapping on first encounter (M-02). |
| CLAS-04 | Manual course picker fallback (recent + search) | Inline view-state switching in `MenuBarPopover` (not `.sheet`); `CoursePickerView` in `UnibrainApp/Views/`. See Pitfall 2. |
| CLAS-05 | Multi-term folder structure `{vault}/{term}/{course-code}/` | `ScheduleAwareVaultResolver` replaces `HardcodedVaultResolver`; builds path from sanitized term + course code. |
| CLAS-06 | "Current term" setting filters past-term events | Term range predicate in EventKit query (CT-02); `currentTerm` stored in `courses.json`. |
| CLAS-07 | Manual override remembered per course | M-03: mapping update + recent list update on manual pick; `CourseMappingStore` handles both writes. |
| ONBD-02 | Mic permission required (Phase 3 path, hard-fail) | Already handled in Phase 3 `MenuBarViewModel.requestMicrophonePermission()`. Phase 4 adds calendar alongside. |
| ONBD-03 | Calendar permission optional (degrades to manual picker) | P-01/P-05: `EKEventStore.authorizationStatus(for: .event)` check; `.writeOnly` treated as denied; permission sheet + banner. See Architecture Pattern 5. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Swift 6 strict concurrency** — all new code uses `actor`, `Sendable`, `async/await`. EventKit adapter must be `Sendable` or wrapped in an actor.
- **Immutability** — prefer `let` over `var`; use `struct` with value semantics by default.
- **File organization** — many small files > few large files; 200-400 lines typical, 800 max.
- **Error handling** — typed throws (Swift 6+); structured `ProviderError` variants, never raw strings.
- **Security** — Keychain for secrets (not applicable in Phase 4 — no API keys); input validation at boundaries (FolderNameSanitizer already mitigates path traversal T-2-01).
- **Testing** — Swift Testing framework (`@Test`, `#expect`); 80%+ coverage; protocol-based DI for mock injection.
- **GSD Workflow** — all work via GSD commands; no direct repo edits outside GSD workflow.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Calendar event fetching | API / Backend (EventKit adapter in UnibrainProviders) | — | EventKit is a system framework, not UI. Adapter wraps `EKEventStore` behind a protocol. |
| Permission status check + request | API / Backend (EventKit adapter) | UI (permission sheet display) | Status check is data-layer; request prompt is system dialog triggered from data layer. |
| Course mapping persistence | Database / Storage (.unibrain/courses.json) | — | File-based JSON in vault root. `Codable` + `FileManager`. |
| Course classification matching | API / Backend (UnibrainCore) | — | Pure logic already exists (`CourseClassifier.match`). Phase 4 provides events. |
| Pipeline pause/resume | API / Backend (PipelineOrchestrator actor) | UI (triggers resume) | Orchestrator owns state; UI calls `resume(selection:)`. |
| Manual picker UI | Browser / Client (SwiftUI in UnibrainApp) | — | View-state switching inside MenuBarExtra popover. |
| Vault path resolution | Database / Storage (VaultPathResolver) | — | Replaces HardcodedVaultResolver with schedule-aware routing. |
| Settings deep-link | Browser / Client (NSWorkspace.open) | — | macOS-only; URL scheme to System Settings privacy pane. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard | Confidence |
|---------|---------|---------|--------------|------------|
| EventKit | iOS 17+ / macOS 14+ (system) | Calendar access, event querying | Apple's only calendar framework. `EKEventStore` with `requestFullAccessToEvents` (iOS 17+ API per D-05 deployment targets). [CITED: developer.apple.com/documentation/eventkit] | HIGH |
| SwiftUI | macOS 15+ (Package.swift `.macOS(.v15)`) | UI surfaces (picker, banners, manage courses) | Already in use from Phase 3. `MenuBarExtra(.window)` style, `@Observable` view model. [VERIFIED: Package.swift line 8] | HIGH |
| Foundation | system | FileManager JSON read/write, Codable, Date | Already in use. `FileManager.default.contents(atPath:)` + `JSONEncoder`/`JSONDecoder` for courses.json. | HIGH |

### Supporting
| Library | Version | Purpose | When to Use | Confidence |
|---------|---------|---------|-------------|------------|
| Yams | 6.2.2 (SPM, existing) | YAML frontmatter serialization | Already integrated from Phase 1. Not new to Phase 4 but Phase 4 depends on it for note write-out with real course values. [VERIFIED: Package.swift line 15] | HIGH |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| EventKit | Apple Calendar EKEventStore + CloudKit | CloudKit adds cloud dependency — violates local-first. EventKit reads local calendar data store (which may sync from iCloud/Google/Exchange but the API is local). |
| File-based courses.json | Core Data / SQLite | Overkill for single-user, <100 course mappings. JSON is human-editable and iCloud-synced. [VERIFIED: CONTEXT.md M-01] |
| CheckedContinuation | AsyncStream / Combine subject | CheckedContinuation is the simplest single-shot pause/resume. AsyncStream is for continuous values; Combine adds framework overhead. |

**Installation:**
```bash
# No new SPM dependencies in Phase 4. EventKit is a system framework.
# Only Info.plist key additions needed:
# - NSCalendarsUsageDescription (for requestFullAccessToEvents)
# EventKit is imported via `import EventKit` behind `#if canImport(EventKit)` guards
```

**Version verification:** No new packages to verify. EventKit ships with the OS and Xcode SDK.

## Package Legitimacy Audit

> Phase 4 installs zero external packages. All dependencies are Apple system frameworks (EventKit, SwiftUI, Foundation) or already-integrated SPM packages (Yams 6.2.2 from Phase 1).

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none new) | — | — | — | — | — | — |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     MenuBarExtra (macOS)                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  MenuBarPopover (Phase 3 + Phase 4 extensions)          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │    │
│  │  │ Idle State   │  │ Recording    │  │ Classifying  │  │    │
│  │  │ +Manage Btn  │  │ (Phase 3)    │  │ +Picker View │  │    │
│  │  │ +Calendar St │  │              │  │ (inline)     │  │    │
│  │  │ +Term Label  │  │              │  │              │  │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │    │
│  └─────────┼─────────────────┼─────────────────┼───────────┘    │
└────────────┼─────────────────┼─────────────────┼────────────────┘
             │                 │                 │
             ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MenuBarViewModel                             │
│  (Phase 3 methods + Phase 4 additions:)                         │
│  + requestCalendarPermission()                                  │
│  + resumeWithSelection(_:)                                      │
│  + skipClassification()                                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                 PipelineOrchestrator (actor)                    │
│  Phase 3 flow:                                                  │
│  idle → transcribing → classifying → normalizing → writing      │
│                         ↓                                       │
│  Phase 4 extension:    [.multiple/.none] → awaitingUserChoice   │
│                                          ↓                      │
│  UI calls resume(selection:) → normalizing → writing → completed│
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
┌──────────────────┐ ┌───────────────┐ ┌──────────────────┐
│ EventKit Adapter │ │ CourseMapping │ │ ScheduleAware    │
│ (UnibrainProviders│ │ Store (actor) │ │ VaultResolver    │
│  macOS + iOS)    │ │               │ │                  │
│                  │ │ Reads/Writes: │ │ Builds path:     │
│ EKEventStore →   │ │ .unibrain/    │ │ {vault}/{term}/  │
│ [CalendarEvent]  │ │ courses.json  │ │ {course-code}/   │
│                  │ │               │ │ {date}-{COURSE}- │
│ Permission check │ │ Schema v1:    │ │ Lecture.md       │
│ .fullAccess?     │ │ mapping{}     │ │                  │
│                  │ │ recent[]      │ │ Replaces         │
│ Term-range query │ │ currentTerm{} │ │ HardcodedVault   │
│ ±30min filter    │ │               │ │ Resolver         │
└──────────────────┘ └───────────────┘ └──────────────────┘
```

Data flow trace for the primary use case (auto-route):
1. User stops recording -> MenuBarViewModel constructs PipelineInputs
2. Before construction, EventKit adapter fetches events in term range
3. Swift-side filter narrows to ±30min recording window
4. Orchestrator runs: transcribing -> classifying
5. CourseClassifier.match(events, recordingStart) returns `.single(event)`
6. ScheduleAwareVaultResolver looks up event.title in CourseMappingStore
7. If mapped: builds `{vault}/{term}/{course-code}/` path -> normalizing -> writing
8. If unmapped (M-02 auto-learn): FolderNameSanitizer creates folder, updates mapping, routes

### Recommended Project Structure
```
Sources/
├── UnibrainCore/
│   ├── Classification/
│   │   ├── CalendarEvent.swift          # (existing Phase 2)
│   │   ├── CourseClassifier.swift       # (existing Phase 2)
│   │   ├── CourseMatch.swift            # (existing Phase 2)
│   │   ├── FolderNameSanitizer.swift    # (existing Phase 2)
│   │   └── CourseMapping.swift          # NEW: Codable schema for courses.json
│   ├── Pipeline/
│   │   ├── PipelineState.swift          # MODIFY: add .awaitingUserChoice
│   │   ├── PipelineOrchestrator.swift   # MODIFY: add pause/resume via CheckedContinuation
│   │   ├── PipelineInputs.swift         # (existing, maybe extend)
│   │   └── ...
│   └── ...
├── UnibrainProviders/
│   ├── Calendar/
│   │   ├── EventKitAdapter.swift        # NEW: macOS EKEventStore -> [CalendarEvent]
│   │   └── EventKitAdapter+iOS.swift    # NEW: iOS conformance (compiles, untested)
│   ├── VaultWriting/
│   │   ├── HardcodedVaultResolver.swift # (existing Phase 3, stays for fallback)
│   │   └── ScheduleAwareVaultResolver.swift  # NEW: replaces hardcoded
│   └── ...
UnibrainApp/
├── ViewModels/
│   └── MenuBarViewModel.swift           # MODIFY: +calendar permission, +resume, +picker state
├── Views/                               # NEW directory
│   ├── CoursePickerView.swift           # NEW: inline picker (replaces .sheet)
│   ├── ManageCoursesView.swift          # NEW: mapping editor
│   ├── PermissionBanner.swift           # NEW: calendar-off banner
│   └── TermEditorView.swift            # NEW: term label+dates editor
├── MenuBarPopover.swift                 # MODIFY: +picker, +banner, +manage button
└── UnibrainApp.swift                    # MODIFY: +CoursesMappingStore injection
```

### Pattern 1: EventKit Adapter (Protocol + Platform Guards)
**What:** Wrap `EKEventStore` behind a protocol in `UnibrainCore`, conform in `UnibrainProviders` with `#if os()` guards.
**When to use:** Any time Apple-framework access needs to be abstracted for testing.
**Example:**
```swift
// In UnibrainCore — no EventKit import, testable on Linux
public protocol CalendarEventProvider: Sendable {
    func checkAuthorization() async -> CalendarPermissionStatus
    func requestFullAccess() async throws -> Bool
    func fetchEvents(in dateRange: ClosedRange<Date>) async throws -> [CalendarEvent]
}

public enum CalendarPermissionStatus: Sendable {
    case notDetermined
    case fullAccess
    case writeOnly
    case denied
    case restricted
}

// In UnibrainProviders — macOS conformance
#if os(macOS) || os(iOS)
import EventKit

public actor EventKitAdapter: CalendarEventProvider {
    private let store = EKEventStore()

    public func checkAuthorization() async -> CalendarPermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly  // P-05: treat as denied upstream
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    public func requestFullAccess() async throws -> Bool {
        // iOS 17+ / macOS 14+ API (deployment targets cover this)
        return try await store.requestFullAccessToEvents()
    }

    public func fetchEvents(in dateRange: ClosedRange<Date>) async throws -> [CalendarEvent] {
        let predicate = store.predicateForEvents(
            withStart: dateRange.lowerBound,
            end: dateRange.upperBound,
            calendars: nil  // P-04: query all calendars inclusively
        )
        // EventKit auto-expands recurring events into individual occurrences.
        let ekEvents = store.events(matching: predicate)
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
#endif
```
[CITED: developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)] [CITED: developer.apple.com/documentation/eventkit/ekeventstore/predicateforevents(withstart:end:calendars:)]

### Pattern 2: Orchestrator Pause/Resume via CheckedContinuation
**What:** Extend `PipelineOrchestrator` with `.awaitingUserChoice` state and a stored `CheckedContinuation` that the UI resumes.
**When to use:** Pipeline needs to park mid-run and wait for external (user) input.
**Example:**
```swift
// PipelineState extension
public enum PipelineState: @unchecked Sendable {
    case idle
    case transcribing
    case classifying
    case awaitingUserChoice  // NEW — pause for manual course selection
    case normalizing
    case writing
    case completed
    case failed(any Error)
    case cancelled
}

// PipelineOrchestrator extension
public actor PipelineOrchestrator {
    // Stored continuation for pause/resume
    private var selectionContinuation: CheckedContinuation<CalendarEvent, Error>?

    // In executePipeline, replace the guard-against-non-single:
    // BEFORE (Phase 2): throw if .multiple/.none
    // AFTER (Phase 4): pause and wait for user selection

    private func resolveViaUserChoice(match: CourseMatch) async throws -> CalendarEvent {
        switch match {
        case .single(let event):
            return event
        case .multiple, .none:
            state = .awaitingUserChoice
            // Park the pipeline — suspend until UI calls resume(selection:)
            return try await withCheckedThrowingContinuation { continuation in
                self.selectionContinuation = continuation
            }
        }
    }

    /// Called by the UI layer when user picks a course.
    public func resume(selection: CalendarEvent) {
        selectionContinuation?.resume(returning: selection)
        selectionContinuation = nil
    }

    /// Called by UI when user skips classification.
    public func skipClassification() {
        let unsorted = CalendarEvent(
            id: "unsorted",
            title: "Unsorted",
            startDate: Date(),
            endDate: Date()
        )
        selectionContinuation?.resume(returning: unsorted)
        selectionContinuation = nil
    }
}
```
**SR-14875 warning:** Resuming a continuation from within an actor's own method can hang. The `resume(selection:)` method is called from outside the actor (the UI layer / MainActor), so the resume happens across an actor boundary — this is the safe pattern. [CITED: forums.swift.org/t/concurrency-suspending-an-actor-async-func-until-the-actor-meets-certain-conditions/56580] [CITED: github.com/swiftlang/swift/issues/57222]

### Pattern 3: courses.json Codable Schema
**What:** Versioned JSON schema for the mapping table, stored at `{vault}/.unibrain/courses.json`.
**When to use:** Read at app launch; write on auto-learn, manual pick, term update.
**Example:**
```swift
// In UnibrainCore/Classification/CourseMapping.swift
public struct CourseMappingStore: Codable, Sendable {
    public var schemaVersion: Int
    public var currentTerm: TermDefinition
    public var mappings: [String: CourseMapping]  // eventTitle -> mapping
    public var recentCourseCodes: [String]         // MRU list, max 5

    public struct TermDefinition: Codable, Sendable {
        public var label: String       // "Fall 2026"
        public var startDate: Date     // 2026-08-25
        public var endDate: Date       // 2026-12-15
    }

    public struct CourseMapping: Codable, Sendable {
        public var courseCode: String   // "CS101"
        public var courseName: String   // "Intro to Computer Science"
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case currentTerm = "current_term"
        case mappings
        case recentCourseCodes = "recent_course_codes"
    }
}

// Usage in an actor:
public actor CourseMappingRepository {
    private let storeURL: URL
    private var cache: CourseMappingStore?

    public func load() throws -> CourseMappingStore { ... }
    public func save(_ store: CourseMappingStore) throws { ... }
    public func lookup(eventTitle: String) -> CourseMapping? { ... }
    public func upsert(eventTitle: String, mapping: CourseMapping) throws { ... }
    public func addRecent(courseCode: String) throws { ... }
}
```

### Pattern 4: ScheduleAwareVaultResolver
**What:** Replaces `HardcodedVaultResolver`. Builds path from term + course code + date.
**Example:**
```swift
public struct ScheduleAwareVaultResolver: VaultPathResolver, Sendable {
    private let vaultRoot: URL
    private let mapping: CourseMappingStore
    private let termLabel: String  // pre-sanitized or sanitize on the fly

    public func resolve(match: CourseMatch, recordingStart: Date) throws -> URL {
        let courseCode: String
        switch match {
        case .single(let event):
            // Look up mapping, or auto-create (M-02)
            if let mapped = mapping.mappings[event.title] {
                courseCode = mapped.courseCode
            } else {
                courseCode = FolderNameSanitizer.sanitize(folderName: event.title)
            }
        case .multiple, .none:
            courseCode = "_unsorted"
        }

        let sanitizedTerm = FolderNameSanitizer.sanitize(folderName: termLabel)
        let courseDir = vaultRoot
            .appendingPathComponent(sanitizedTerm)
            .appendingPathComponent(courseCode)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: recordingStart)

        return courseDir.appendingPathComponent("\(dateString)-\(courseCode)-Lecture.md")
    }
}
```

### Pattern 5: macOS Settings Deep-Link
**What:** Open System Settings to Privacy > Calendars via URL scheme.
**When to use:** Permission-denied UX (P-01 first-time sheet button, ongoing banner tap).
```swift
#if os(macOS)
import AppKit

func openCalendarPrivacySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
        NSWorkspace.shared.open(url)
    }
}
#endif
```
[CITED: github.com/jaywcjlove/SystemSettings-URLs-macOS] [CITED: stackoverflow.com/questions/58330598]

### Anti-Patterns to Avoid
- **Blocking the orchestrator actor with a synchronous wait:** Never use `Thread.sleep` or a busy-wait inside the actor. Use `CheckedContinuation` so the actor suspends cooperatively and other actor methods (like `resume`) can still execute.
- **Using `.sheet` inside MenuBarExtra:** SwiftUI `.sheet` modifier is unreliable inside `MenuBarExtra(.window)` — sheets often fail to anchor or appear behind other windows. Use inline view-state switching (swap views based on `@State` enum). [CITED: stackoverflow.com/questions/79572874]
- **Querying EventKit on MainActor:** `store.events(matching:)` can block for large calendars. Always call from an actor or `Task.detached`. The `EventKitAdapter` actor handles this naturally.
- **Treating `.writeOnly` as sufficient:** `requestFullAccessToEvents` may return `granted=true` for write-only access on some iOS versions. Always check `EKEventStore.authorizationStatus(for: .event) == .fullAccess` explicitly (P-05). [CITED: developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:))]
- **Hardcoding term string in NoteNormalizer:** Phase 2 hardcoded `term: "Fall 2026"` at NoteNormalizer.swift:109. Phase 4 must thread the real `currentTerm.label` through `NoteNormalizer.normalize()` — either add a `term` parameter or pass it via `PipelineInputs`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Calendar event querying | Custom CalDAV client | `EKEventStore.predicateForEvents` + `events(matching:)` | EventKit handles all calendar sources (iCloud, Google, Exchange, local), recurring expansion, and caching. Re-implementing is thousands of lines. |
| Permission status tracking | Custom UserDefaults flags | `EKEventStore.authorizationStatus(for: .event)` | Static system API. Always current. No stale state. |
| Folder name sanitization | New sanitizer | `FolderNameSanitizer.sanitize()` (Phase 2, existing) | Already handles path traversal (T-2-01), reserved chars, max length, whitespace collapse. |
| YAML frontmatter writing | Manual string building | `YAMLEncoder().encode(note.frontmatter)` (Phase 1, existing) | Already in `NSFileCoordinatorNoteWriter`. |
| Atomic file writes | Custom POSIX rename | `NSFileCoordinator` + `Data.write(.atomic)` (Phase 3, existing) | `NSFileCoordinatorNoteWriter` already handles this + `.icloud` detection. |
| JSON serialization | Manual string templates | `JSONEncoder` / `JSONDecoder` with `Codable` | Built-in, type-safe, handles escaping. |

**Key insight:** Phase 4 wires together existing Phase 2 contracts with real Apple-framework data. The only genuinely new logic is the pause/resume continuation in the orchestrator and the JSON mapping store. Everything else is adapter code.

## Common Pitfalls

### Pitfall 1: EKAuthorizationStatus .writeOnly vs .fullAccess
**What goes wrong:** On iOS 17+/macOS 14+, `requestFullAccessToEvents` may succeed but only grant `.writeOnly` access. The app thinks it has permission, calls `store.events(matching:)`, and gets an empty array (or a silent failure) because write-only cannot read events.
**Why it happens:** Apple split calendar permissions into two tiers. The `requestFullAccessToEvents` completion's `Bool` return is `true` for both `.fullAccess` and `.writeOnly` in some contexts.
**How to avoid:** Always verify `EKEventStore.authorizationStatus(for: .event) == .fullAccess` AFTER the request completes, not just `granted == true`. Treat `.writeOnly` identically to `.denied` in the degradation flow (P-05).
**Warning signs:** Events array is always empty despite calendar having events; no error thrown.

### Pitfall 2: .sheet on MenuBarExtra Fails Silently
**What goes wrong:** Attaching `.sheet(isPresented:)` to a view inside `MenuBarExtra(.window)` — the sheet either doesn't appear, appears behind the popover window, or appears detached from the menu bar.
**Why it happens:** `MenuBarExtra`'s window has special lifecycle management. SwiftUI's sheet presentation relies on the responder chain and window level, which conflicts with the menu bar panel's transient nature. Known Apple feedback issue FB11984872.
**How to avoid:** Use inline view-state switching instead of `.sheet`. Add a `@State` enum (e.g., `PopoverOverlay`) to `MenuBarPopover` and swap views in the `body`. The picker, manage courses, and permission views all render inline within the 280pt popover frame.
**Warning signs:** Sheet works in Preview but not at runtime; sheet appears on second tap but not first; sheet appears behind other app windows.

### Pitfall 3: CheckedContinuation Resumed from Actor Context Hangs
**What goes wrong:** The orchestrator stores a `CheckedContinuation` and tries to resume it from within the same actor — the resume call deadlocks.
**Why it happens:** Swift issue SR-14875. Actor-isolated methods that resume a continuation created in the same actor can hang because the actor is blocked waiting for the continuation, and the continuation can't be resumed because the actor is blocked.
**How to avoid:** The `resume(selection:)` method is called from OUTSIDE the orchestrator actor (from `MenuBarViewModel` on `@MainActor`). The orchestrator actor only stores the continuation — it never resumes it from within its own isolation context. The `resume` call crosses an actor boundary, which is safe.
**Warning signs:** App hangs at `.awaitingUserChoice` state; spin cursor; `Task` never completes.

### Pitfall 4: EventKit Recurring Events Create Duplicate Matches
**What goes wrong:** A weekly recurring CS101 lecture returns 15 `EKEvent` objects for a semester-range query (one per occurrence). If the ±30min window overlaps two occurrences (e.g., recording near midnight), CourseClassifier returns `.multiple`.
**Why it happens:** `predicateForEvents` auto-expands recurring events. Each occurrence is a separate `EKEvent` with its own `startDate`/`endDate` but shares the same `eventIdentifier`.
**How to avoid:** The ±30min Swift-side filter (after the term-range EventKit query) naturally narrows to 1-2 occurrences for any given recording time. If two do overlap, the manual picker (`.multiple`) handles it gracefully — Angelica picks the one she's in. This is the designed behavior (MP-05).
**Warning signs:** Always getting `.multiple` for the same course; events list has same title repeated many times.

### Pitfall 5: NoteNormalizer Hardcoded Values
**What goes wrong:** Phase 2's `NoteNormalizer.normalize()` hardcodes `term: "Fall 2026"`, `source: "MacBook Air"` at lines 109/112. Phase 4 writes real term values but the normalizer overwrites them.
**Why it happens:** Phase 2 was pure-logic with no calendar context. These were documented placeholders.
**How to avoid:** Extend `NoteNormalizer.normalize()` to accept `term: String` and `source: String` as parameters (or pass them via the `CalendarEvent` / a new context struct). The orchestrator provides real values from `currentTerm.label` and `PipelineInputs.source`.
**Warning signs:** Notes always show `term: "Fall 2026"` regardless of the actual current term setting.

### Pitfall 6: Term Date Predicate vs ±30min Window Confusion
**What goes wrong:** Planner conflates the term-range EventKit predicate with the ±30min recording-overlap window, either applying only one or applying them in the wrong order.
**Why it happens:** CT-02 says "EventKit query predicate uses the term range as the outer bound" and "±30min recording window from Phase 2 C-03 is still applied, but Swift-side." Two separate filters with different purposes.
**How to avoid:** Two-stage filter: (1) EventKit `predicateForEvents(withStart: term.startDate, end: term.endDate, calendars: nil)` — fetches ALL events in the term (broad), (2) Swift filter using `CourseClassifier.match(events:allEvents, against: recordingStart, window: 1800)` — narrows to events overlapping the recording ±30min (narrow). The CourseClassifier already implements step 2.
**Warning signs:** Querying EventKit with ±30min range only — misses all-day events or events that start before the window but are still in progress.

## Code Examples

### EventKit Permission Check + Request Flow
```swift
// Source: [CITED: developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)]
// Source: [CITED: developer.apple.com/documentation/technotes/tn3153-adopting-api-changes-for-eventkit-in-ios-macos-and-watchos]

import EventKit

actor EventKitAdapter {
    private let store = EKEventStore()

    /// Checks current permission status WITHOUT requesting.
    func checkStatus() -> CalendarPermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly  // P-05: treat as denied
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Requests full access. Returns true ONLY if .fullAccess granted.
    func requestFullAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            // P-05: Verify .fullAccess specifically, not just `granted`
            guard granted else { return false }
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } catch {
            return false
        }
    }
}
```

### Term-Range EventKit Query with Swift-Side Filter
```swift
// Source: [CITED: developer.apple.com/documentation/eventkit/ekeventstore/predicateforevents(withstart:end:calendars:)]
// Source: [CITED: www.createwithswift.com/fetching-events-from-the-users-calendar/]

func fetchEventsForRecording(
    recordingStart: Date,
    term: CourseMappingStore.TermDefinition
) async throws -> [CalendarEvent] {
    // Step 1: Broad EventKit query — entire term range
    let predicate = store.predicateForEvents(
        withStart: term.startDate,
        end: term.endDate,
        calendars: nil  // P-04: all calendars
    )
    let allTermEvents = store.events(matching: predicate)

    // Step 2: Map EKEvent -> CalendarEvent
    let calendarEvents = allTermEvents.map { ekEvent in
        CalendarEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            location: ekEvent.location
        )
    }

    // Step 3: CourseClassifier.match applies the ±30min filter (C-03)
    // This is called later in the orchestrator, not here.
    return calendarEvents
}
```

### Inline View-State Switching (Picker within Popover)
```swift
// Source: [CITED: stackoverflow.com/questions/79572874/is-it-possible-to-present-a-menubarextra-with-popover-window-style]

// Instead of .sheet, use a @State overlay enum:
enum PopoverOverlay: Equatable {
    case none
    case coursePicker(CoursePickerMode)
    case manageCourses
    case permissionDenied
    case termEditor
}

struct MenuBarPopover: View {
    @Bindable var viewModel: MenuBarViewModel

    var body: some View {
        switch viewModel.overlayState {
        case .none:
            // Normal Phase 3 + Phase 4 idle/recording/etc views
            mainContent
        case .coursePicker(let mode):
            CoursePickerView(mode: mode, viewModel: viewModel)
        case .manageCourses:
            ManageCoursesView(viewModel: viewModel)
        case .permissionDenied:
            PermissionDeniedView(viewModel: viewModel)
        case .termEditor:
            TermEditorView(viewModel: viewModel)
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `requestAccess(to: .event)` | `requestFullAccessToEvents()` | iOS 17 / macOS 14 (2023) | Old API deprecated. Must use new two-tier API. Old returns simple Bool; new distinguishes full/write-only. |
| `EKAuthorizationStatus.authorized` | `.fullAccess` / `.writeOnly` | iOS 17 / macOS 14 (2023) | Old `.authorized` case still exists for backward compat but new cases are the active status on iOS 17+. |
| `NSWorkspace.shared.open(URL)` | Same (no change) | — | Still the correct API for macOS Settings deep-links. URL scheme `x-apple.systempreferences:` works on macOS 13+ (Ventura/System Settings). |
| `ObservableObject` + `@Published` | `@Observable` macro | iOS 17 / macOS 14 (2023) | Phase 3 already uses `@Observable`. Phase 4 view model extensions inherit this. |

**Deprecated/outdated:**
- `requestAccess(to:completion:)` — deprecated in iOS 17/macOS 14. Replaced by `requestFullAccessToEvents(completion:)` and `requestWriteOnlyAccessToEvents(completion:)`.
- `EKAuthorizationStatus.authorized` — still exists but `.fullAccess` is the active case on iOS 17+.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars` opens the correct privacy-calendars pane on macOS 15+ | Pattern 5, Pitfall N/A | Settings opens to wrong pane; users can't find calendar privacy. Fallback: open generic `x-apple.systempreferences:com.apple.preference.security`. |
| A2 | EventKit `predicateForEvents` auto-expands recurring events (no manual `EKRecurrenceRule` expansion needed) | Pattern 1, Pitfall 4 | If not, weekly lectures show as one event with recurrence rule — CourseClassifier gets one event covering the entire semester and matches every recording to it. Mitigation: test with real calendar data on macOS CI. |
| A3 | `CheckedContinuation` resumed from outside the actor does not hang (SR-14875 only applies to in-actor resumes) | Pattern 2, Pitfall 3 | If wrong, the pipeline hangs at `.awaitingUserChoice`. Mitigation: use `AsyncStream` or a simple `CheckedContinuation` stored in a separate non-actor class. |
| A4 | `.sheet` is unreliable on `MenuBarExtra(.window)` on macOS 15 | Pitfall 2 | If wrong and `.sheet` works, the inline approach still works — just more code. Low risk either way. |
| A5 | The async variant `store.requestFullAccessToEvents()` (no completion handler) is available on macOS 15 | Pattern 1 | If only the completion-handler variant is available, wrap it with `withCheckedContinuation`. |

## Open Questions (RESOLVED)

1. RESOLVED: Does `EKEventStore.requestFullAccessToEvents()` have an async variant?
   - **Resolution:** Assume the async variant exists on macOS 15+ (Swift async bridging auto-generates it from the completion-handler form). Implementation calls `try await store.requestFullAccessToEvents()` directly. If compile fails on macOS CI, fall back to wrapping the completion-handler variant via `withCheckedThrowingContinuation`. No checkpoint task needed — the compile step is the check.

2. RESOLVED: macOS 15 vs macOS 26 deployment target
   - **Resolution:** No conflict. `Package.swift` specifies `.macOS(.v15)` as the minimum; macOS 26 Tahoe is Angelica's actual device OS. `requestFullAccessToEvents` is available at macOS 14+ (iOS 17+), so it compiles at the `.v15` deployment target and runs on macOS 26.

3. RESOLVED: Info.plist NSCalendarsUsageDescription
   - **Resolution:** Plan 05 Task 2b creates `UnibrainApp/Info.plist` with the `NSCalendarsUsageDescription` key and explanation string. Without this key, `requestFullAccessToEvents` silently fails — the system dialog never appears. The Info.plist ships with the app bundle when Xcode builds the macOS target. SPM-only tests mock `CalendarEventProvider` and do not need the key.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| EventKit framework | CLAS-01, CLAS-06 calendar query | N/A (macOS CI only) | System (macOS 15 runner) | Mock `CalendarEventProvider` for Linux tests |
| EKEventStore | EventKit adapter | N/A (macOS CI only) | System | Protocol-injected mock in tests |
| SwiftUI MenuBarExtra | UI surfaces | N/A (macOS CI only) | System | Tests target `UnibrainProvidersTests` (macOS only), not UI |
| FileManager | courses.json persistence | Yes (both platforms) | System | — |
| JSONEncoder/Decoder | courses.json serialization | Yes (Foundation) | System | — |
| GitHub Actions macos-15 | CI build + test | Yes | macOS 15 runner | — |

**Missing dependencies with no fallback:**
- None. EventKit is available on macOS CI runners. Linux CI tests mock the adapter via protocol injection.

**Missing dependencies with fallback:**
- EventKit on Linux CI: `UnibrainCore` tests use mock `CalendarEventProvider` conformances. `UnibrainProvidersTests` (EventKit adapter tests) run on macOS CI only. This matches Phase 1 D-08 split.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`) — existing from Phase 1 |
| Config file | None — tests run via `swift test` |
| Quick run command | `swift test --filter UnibrainCoreTests` (Linux, pure logic only) |
| Full suite command | `swift test` (macOS CI only — all targets) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLAS-01 | EventKit adapter maps EKEvent -> CalendarEvent correctly | unit (macOS) | `swift test --filter EventKitAdapterTests` | No — Wave 0 |
| CLAS-02 | CourseMappingStore JSON round-trip (encode/decode) | unit (Linux) | `swift test --filter CourseMappingStoreTests` | No — Wave 0 |
| CLAS-03 | Unmapped event title triggers FolderNameSanitizer -> folder creation | unit (Linux) | `swift test --filter ScheduleAwareVaultResolverTests` | No — Wave 0 |
| CLAS-04 | Manual picker pause/resume: orchestrator parks at .awaitingUserChoice | unit (Linux) | `swift test --filter PipelineOrchestratorPauseTests` | No — Wave 0 |
| CLAS-05 | Folder path structure {vault}/{term}/{course-code}/ | unit (Linux) | `swift test --filter ScheduleAwareVaultResolverTests` | No — Wave 0 |
| CLAS-06 | Term-range filter excludes past-term events | unit (Linux) | `swift test --filter CourseClassifierTermFilterTests` | No — Wave 0 |
| CLAS-07 | Manual pick updates mapping + recent list | unit (Linux) | `swift test --filter CourseMappingStoreTests` | No — Wave 0 |
| ONBD-03 | .writeOnly permission treated as denied | unit (macOS) | `swift test --filter EventKitAdapterPermissionTests` | No — Wave 0 |
| Integration | Orchestrator full flow: events -> classify -> pause -> resume -> write | integration (Linux) | `swift test --filter PipelineOrchestratorPauseTests` | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `swift test --filter UnibrainCoreTests` (Linux-safe subset)
- **Per wave merge:** `swift test` (full macOS CI)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `Tests/UnibrainCoreTests/ClassificationTests/CourseMappingStoreTests.swift` — covers CLAS-02, CLAS-07
- [ ] `Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorPauseTests.swift` — covers CLAS-04 (pause/resume)
- [ ] `Tests/UnibrainProvidersTests/Calendar/EventKitAdapterTests.swift` — covers CLAS-01, ONBD-03 (macOS only)
- [ ] `Tests/UnibrainProvidersTests/VaultWriting/ScheduleAwareVaultResolverTests.swift` — covers CLAS-03, CLAS-05, CLAS-06
- [ ] `Sources/UnibrainCore/Classification/CourseMapping.swift` — Codable schema (must exist before tests)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Single-user app, no auth surface (Phase 4 scope) |
| V3 Session Management | no | No sessions |
| V4 Access Control | yes | Calendar permission gating — `.fullAccess` check before reading events; `.writeOnly` treated as denied |
| V5 Input Validation | yes | `FolderNameSanitizer` (existing) validates event titles before filesystem use. JSON decoded with typed `Codable` structs — no untyped dictionary access. |
| V6 Cryptography | no | No crypto in Phase 4 (no API keys, no secrets) |
| V7 Error Handling | yes | `ProviderError` and `PipelineError` structured enums. Calendar errors surface to UI for user action, never silently swallowed. |
| V8 Data Protection | yes | courses.json may contain course names (minor PII). Stored in vault (user-controlled location). No cloud transmission. |

### Known Threat Patterns for Swift/EventKit Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal via malicious event title | Tampering | `FolderNameSanitizer` strips `/`, `:`, leading dots (existing Phase 2 mitigation T-2-01) |
| Calendar permission bypass | Information disclosure | `EKEventStore.authorizationStatus(for: .event)` check before every query; never cache permission (may be revoked via Settings) |
| Malformed courses.json | Denial of service | `Codable` decode with `try?` — malformed JSON falls back to empty default store, doesn't crash |
| Continuation leak (resume never called) | Denial of service | Timeout or cancellation handling on `CheckedContinuation` — orchestrator `cancel()` should resume with error |

## Sources

### Primary (HIGH confidence)
- Codebase inspection: `Package.swift`, `Sources/UnibrainCore/**/*.swift`, `Sources/UnibrainProviders/**/*.swift`, `UnibrainApp/**/*.swift`, `Tests/**/*.swift` — verified existing contracts, protocols, and patterns
- Phase 2 CONTEXT (C-01..C-05, O-01..O-05) — locked decisions for CalendarEvent, CourseClassifier, FolderNameSanitizer, PipelineOrchestrator
- Phase 3 CONTEXT (P-08..P-18) — locked decisions for MenuBarExtra popover, vault root, recording pipeline
- Phase 4 CONTEXT (M-01..M-04, P-01..P-05, MP-01..MP-05, CT-01..CT-04) — locked decisions for this phase
- Phase 4 UI-SPEC — full design contract for all new surfaces

### Secondary (MEDIUM confidence)
- [EKEventStore.requestFullAccessToEvents(completion:) — Apple Developer](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)) — permission API spec
- [TN3153: Adopting API changes for EventKit in iOS 17, macOS 14](https://developer.apple.com/documentation/technotes/tn3153-adopting-api-changes-for-eventkit-in-ios-macos-and-watchos) — full vs write-only migration
- [predicateForEvents(withStart:end:calendars:) — Apple Developer](https://developer.apple.com/documentation/eventkit/ekeventstore/predicateforevents(withstart:end:calendars:)) — query predicate
- [authorizationStatus(for:) — Apple Developer](https://developer.apple.com/documentation/eventkit/ekeventstore/authorizationstatus(for:)) — static permission check
- [WWDC23: Discover Calendar and EventKit](https://developer.apple.com/videos/play/wwdc2023/10052/) — iOS 17 permission flow changes
- [SystemSettings-URLs-macOS (GitHub)](https://github.com/jaywcjlove/SystemSettings-URLs-macOS) — deep-link URL scheme
- [Swift Forums: Suspending an actor async func](https://forums.swift.org/t/concurrency-suspending-an-actor-async-func-until-the-actor-meets-certain-conditions/56580) — CheckedContinuation in actor pattern
- [Swift Issue SR-14875](https://github.com/swiftlang/swift/issues/57222) — continuation resume hang caveat
- [Stack Overflow: MenuBarExtra popover sheet issue](https://stackoverflow.com/questions/79572874/is-it-possible-to-present-a-menubarextra-with-popover-window-style) — `.sheet` unreliability

### Tertiary (LOW confidence)
- [Fetching Events from the User's Calendar (Create with Swift)](https://www.createwithswift.com/fetching-events-from-the-users-calendar/) — practical EventKit tutorial
- [Getting access to the user's calendar (Create with Swift)](https://www.createwithswift.com/getting-access-to-the-users-calendar/) — permission flow walkthrough
- [FB11984872: MenuBarExtra needs programmatic close](https://github.com/feedback-assistant/reports/issues/383) — known MenuBarExtra limitation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — EventKit is a stable Apple framework; all APIs verified against Apple Developer docs
- Architecture: HIGH — extends existing Phase 2/3 contracts with clear extension points
- Pitfalls: HIGH — EventKit permission split is well-documented; MenuBarExtra `.sheet` issue confirmed by multiple sources; CheckedContinuation hang risk is known
- courses.json schema: MEDIUM — exact shape is at planner's discretion per CONTEXT.md; no external schema to verify against
- macOS Settings deep-link URL: MEDIUM — URL scheme verified via community sources but Apple does not officially document the anchor names

**Research date:** 2026-07-15
**Valid until:** 2026-08-15 (30 days — EventKit/Swift APIs are stable)
