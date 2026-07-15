---
phase: 04-course-classification-smart-routing
verified: 2026-07-15T12:00:00Z
status: gaps_found
score: 2/5 must-haves verified
behavior_unverified: 1
behavior_unverified_items:
  - truth: "Past-term events are excluded from classification when a current term is set (CLAS-06)"
    test: "Set a term with endDate in the past, then fetch events for a recording made during an old-term timeslot"
    expected: "Recording routes to the current-term folder (or no match), NOT to a past-term folder"
    why_human: "The term-range predicate is applied in EventKitCalendarAdapter.fetchEvents() at the adapter boundary. Logic is present and wired, but the full chain (adapter -> MenuBarViewModel.stopRecording -> orchestrator) has never been exercised on a real device with real calendar events. Verified at the component level via tests; full-chain behavior requires macOS device."
re_verification: # No previous — initial verification
  previous_status: N/A
  previous_score: N/A
  gaps_closed: []
  gaps_remaining: []
  regressions: []
gaps:
  - truth: "User starts a recording during a scheduled lecture and the resulting note lands in {vault}/{term}/{course-code}/YYYY-MM-DD-{COURSE}-Lecture.md automatically (CLAS-01, CLAS-02, CLAS-05)"
    status: failed
    reason: "ScheduleAwareVaultResolver exists and is tested in isolation (9 tests pass), but PipelineWiring.makeOrchestrator() still constructs HardcodedVaultResolver — the running app never wires ScheduleAwareVaultResolver into the orchestrator. UnibrainApp.swift calls PipelineWiring.makeOrchestrator(modelPath:) at line 32, which constructs HardcodedVaultResolver at PipelineWiring.swift line 29. The production app routes every recording to ~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md with course UNCLASSIFIED — Phase 3 behavior unchanged."
    artifacts:
      - path: "Sources/UnibrainProviders/Pipeline/PipelineWiring.swift"
        issue: "Line 29: `let resolver = HardcodedVaultResolver()` — Phase 4 ScheduleAwareVaultResolver never wired. makeOrchestrator signature accepts no vaultRoot/termLabel/mapping parameters — no API surface to construct ScheduleAwareVaultResolver."
      - path: "UnibrainApp/UnibrainApp.swift"
        issue: "Line 32: calls PipelineWiring.makeOrchestrator(modelPath:) which returns orchestrator with HardcodedVaultResolver. No Phase 4 resolver construction in this file."
    missing:
      - "Add a new PipelineWiring factory (e.g., makeScheduleAwareOrchestrator(modelPath:vaultRoot:termLabel:mapping:) -> PipelineOrchestrator) OR extend makeOrchestrator to accept resolver parameters"
      - "Update UnibrainApp.swift to load CourseMappingStore.allMappings() + CourseMappingStore.currentTerm() at startup and construct ScheduleAwareVaultResolver with them"
      - "Refresh the resolver snapshot on each recording (or when mappings change) so newly-learned courses route correctly"
  - truth: "When the user manually picks a course for a recording, that override is remembered for the next recording of the same course (CLAS-07)"
    status: failed
    reason: "MenuBarViewModel.selectCourse() calls CourseMappingStore.upsert + addRecent (verified at code level), but the orchestrator that processes the recording is wired to HardcodedVaultResolver which does not consult CourseMappingStore. Even if upsert succeeds, the NEXT recording still routes via HardcodedVaultResolver and ignores the learned mapping. The persistence is correct; the consumption is missing."
    artifacts:
      - path: "Sources/UnibrainProviders/Pipeline/PipelineWiring.swift"
        issue: "HardcodedVaultResolver ignores CourseMatch entirely — see line 43 'The match parameter is intentionally ignored'."
      - path: "UnibrainApp/Views/CoursePickerView.swift"
        issue: "recentCourses and filteredCourses computed properties return hardcoded `[]` at lines 183-184. CoursePickerView receives only `mode` and `viewModel` — it never reads from the CoursePickerViewModel that handleClassificationPause constructs. Picker shows empty course list."
    missing:
      - "Wire ScheduleAwareVaultResolver into the orchestrator so mappings persist + route on next recording"
      - "Pass CoursePickerViewModel from MenuBarViewModel into CoursePickerView (or expose allCourses/recentCourses via MenuBarViewModel properties) so the picker renders real data"
  - truth: "User starts a recording during a scheduled lecture and the resulting note lands in the correct folder automatically — the picker must actually fire when CourseClassifier returns .multiple/.none"
    status: failed
    reason: "MenuBarViewModel.handleClassificationPause(match:) is defined but NEVER CALLED. The orchestrator transitions to .awaitingUserChoice state (verified in PipelineOrchestratorPauseTests — 3 tests pass), but no code in MenuBarViewModel.stopRecording() or anywhere else observes orchestrator.currentState for the .awaitingUserChoice transition. The stopRecording method launches Task.detached { try await orchestrator.run(inputs:) } and only branches on success vs error — it has no way to detect the pause. The pipeline hangs indefinitely at .awaitingUserChoice in the production app."
    artifacts:
      - path: "UnibrainApp/ViewModels/MenuBarViewModel.swift"
        issue: "Lines 325-336: Task.detached awaits orchestrator.run() with only onTranscriptionComplete / onTranscriptionError callbacks. No observer for .awaitingUserChoice state. handleClassificationPause defined at line 425 but called only from tests."
      - path: "UnibrainApp/MenuBarPopover.swift"
        issue: "No state observation wiring between orchestrator.currentState changes and viewModel.handleClassificationPause()"
    missing:
      - "Add a state observer (e.g., polling Task, AsyncStream, or Combine publisher) in MenuBarViewModel that detects orchestrator.currentState == .awaitingUserChoice and calls handleClassificationPause with the CourseMatch that caused the pause"
      - "Alternatively, refactor orchestrator.run() to surface a 'paused' callback or return value before completion"
  - truth: "When calendar Full Access is denied (or only Write-Only is granted), the app degrades gracefully: a clear in-app explanation AND a manual course picker (recent courses + search) lets the user pick the right destination (ONBD-02, ONBD-03, CLAS-04)"
    status: failed
    reason: "The permission degradation code path is partially wired (PermissionDeniedSheet exists, PermissionState.from maps .writeOnly to .denied correctly, openSystemSettings uses NSWorkspace.open), but two prerequisites fail: (a) CoursePickerView returns hardcoded empty arrays for recentCourses/filteredCourses — even when the picker overlay appears, the user sees an empty list with no courses to pick; (b) the overlay never actually appears for the .awaitingUserChoice case because handleClassificationPause is never called (see previous gap)."
    artifacts:
      - path: "UnibrainApp/Views/CoursePickerView.swift"
        issue: "Lines 182-184: `private var recentCourses: [CourseSummary] { [] }` and `private var filteredCourses: [CourseSummary] { [] }` — hardcoded empty. The view receives no course data."
      - path: "UnibrainApp/Views/ManageCoursesView.swift"
        issue: "Line 154: `mappings = [:]` — loadMappings unconditionally returns empty. Manage Courses view shows empty table even if courses.json has mappings."
    missing:
      - "Wire CoursePickerView to receive CoursePickerViewModel (or expose its data via MenuBarViewModel)"
      - "Wire ManageCoursesView.loadMappings to read from CourseMappingStore via MenuBarViewModel"
      - "Ensure the picker actually displays when .awaitingUserChoice fires (depends on handleClassificationPause call gap)"
---

# Phase 4: Course Classification + Smart Routing Verification Report

**Phase Goal:** Every recording auto-routes to the correct course folder based on the student's Apple Calendar schedule — the competitive moat — with a manual picker fallback when classification is ambiguous, multi-term folder structure, and the current-term filter that keeps past-term noise out of matching.
**Verified:** 2026-07-15T12:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | Recording during scheduled lecture lands in `{vault}/{term}/{course-code}/YYYY-MM-DD-{COURSE}-Lecture.md` | ✗ FAILED | `ScheduleAwareVaultResolver` exists (Sources/UnibrainProviders/VaultWriting/ScheduleAwareVaultResolver.swift, 120 lines, 9 macOS-only tests pass) but is NOT wired into the running app. `PipelineWiring.makeOrchestrator()` (line 29) still constructs `HardcodedVaultResolver`. Production app routes every recording to `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md` with `course: UNCLASSIFIED` (HardcodedVaultResolver lines 42-46). |
| 2 | Calendar Full Access denial degrades gracefully: explanation + Settings deep-link + manual picker | ✗ FAILED | PermissionDeniedSheet, PermissionBanner, PermissionState, and openSystemSettings exist and look correct. BUT the manual picker overlay never fires (handleClassificationPause never called from production code), AND when the overlay does render, CoursePickerView.recentCourses/filteredCourses return hardcoded `[]` (lines 182-184) — no courses visible to pick. |
| 3 | Unrecognized calendar event title triggers auto-creation of sanitized course folder | ✗ FAILED | ScheduleAwareVaultResolver.resolve() applies FolderNameSanitizer.sanitize on the unmapped event title (line 87) and calls FileManager.createDirectory recursively (line 102) — implementation is correct. But since the resolver is never wired into the orchestrator (see Truth 1), the behavior never executes in production. FolderNameSanitizer itself was verified in Phase 2. |
| 4 | "Current term" label filters out past-term calendar events from classification | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | CourseMappingStore stores/retrieves TermDefinition (verified — setCurrentTerm/currentTerm tests pass). TermRangeFilter.filterEvents applies ±30min window (3 tests pass). EventKitCalendarAdapter.fetchEvents takes a ClosedRange<Date> (verified by inspection). MenuBarViewModel.stopRecording fetches events using `term.startDate...term.endDate` (line 302). Logic is wired but the full chain (adapter → view model → orchestrator → resolver) has never run end-to-end. Behavior depends on a real EventKit calendar with past events — requires macOS device. The related Truth 1 failure also blocks end-to-end verification. |
| 5 | Manual override is remembered for the next recording | ✗ FAILED | CourseMappingStore.upsert/addRecent correctly persist to courses.json (tests 5, 6 pass). MenuBarViewModel.selectCourse calls upsert + addRecent (lines 491-495, 561-565). BUT because the orchestrator uses HardcodedVaultResolver, the persisted mapping is NEVER consulted on the next recording — HardcodedVaultResolver ignores CourseMatch entirely. Plus, CoursePickerView never displays the picker data, so the user cannot actually make a selection in the UI. |

**Score:** 0/5 truths verified, 1 present-behavior-unverified, 4 failed

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `Sources/UnibrainCore/Classification/CourseMapping.swift` | CourseMappingDocument schema | ✓ VERIFIED | 91 lines, 3 Codable+Sendable structs, snake_case CodingKeys, .empty factory. Substantive. |
| `Sources/UnibrainCore/Classification/CourseMappingStore.swift` | Actor with async CRUD | ✓ VERIFIED | 180 lines, 9 async methods, atomic writes. 10 tests pass. |
| `Sources/UnibrainCore/Protocols/CalendarEventProvider.swift` | Protocol + permission enum | ✓ VERIFIED | 64 lines, 5-case enum, 3-method protocol. |
| `Sources/UnibrainCore/Classification/TermRangeFilter.swift` | ±30min filter | ✓ VERIFIED | 45 lines, pure static method, 7 tests pass. |
| `Sources/UnibrainProviders/Calendar/EventKitCalendarAdapter.swift` | EventKit adapter | ✓ VERIFIED (code-inspection only) | 133 lines, actor, macOS+iOS guard. 4 macOS-only tests not run on Linux. |
| `Sources/UnibrainCore/Classification/PermissionState.swift` | Permission state derivation | ✓ VERIFIED | 54 lines, .from factory, shouldShowFirstTimeSheet. 9 tests pass. |
| `Sources/UnibrainCore/Classification/CoursePickerViewModel.swift` | Picker view model | ✓ VERIFIED | 147 lines, 4 selection paths, search filtering. 11 tests pass. |
| `Sources/UnibrainCore/Pipeline/PipelineState.swift` | Extended with .awaitingUserChoice | ✓ VERIFIED | 9th case added at line 38. |
| `Sources/UnibrainCore/Pipeline/PipelineOrchestrator.swift` | Pause/resume via CheckedContinuation | ✓ VERIFIED | 286 lines, selectionContinuation, resume(with:), skipClassification(). 11 tests pass. |
| `Sources/UnibrainCore/Normalization/NoteNormalizer.swift` | Parameterized term/source | ✓ VERIFIED | term: and source: parameters at line 79. 18 tests pass (updated from Phase 2). |
| `Sources/UnibrainProviders/VaultWriting/ScheduleAwareVaultResolver.swift` | Schedule-aware path resolver | ⚠️ ORPHANED | 120 lines, correct path construction, 9 macOS-only tests. BUT never wired into production — PipelineWiring.makeOrchestrator still uses HardcodedVaultResolver. |
| `UnibrainApp/Views/CoursePickerView.swift` | Inline picker UI | ✗ STUB | 203 lines, structure correct (search, sections, events, buttons). BUT recentCourses (line 183) and filteredCourses (line 186) return hardcoded `[]`. No data flows into the view. |
| `UnibrainApp/Views/CoursePickerRow.swift` | Row component | ✓ VERIFIED | Simple view, accessibility label, tap gesture. |
| `UnibrainApp/Views/CreateCourseForm.swift` | Create new course form | ✓ VERIFIED | Two TextFields, sanitize, selectCourse(.newCourse). |
| `UnibrainApp/Views/ManageCoursesView.swift` | Editable mapping table | ✗ STUB | 174 lines, UI structure correct. BUT loadMappings() at line 154 returns `[:]` unconditionally — no data loads from CourseMappingStore. |
| `UnibrainApp/Views/PermissionDeniedSheet.swift` | First-time permission overlay | ✓ VERIFIED | 49 lines, copy matches UI-SPEC, Settings deep-link wired. |
| `UnibrainApp/Views/PermissionBanner.swift` | Compact ongoing banner | ✓ VERIFIED | Code present. |
| `UnibrainApp/Views/TermExpiredBanner.swift` | Term-expired nudge | ✓ VERIFIED | Code present. |
| `UnibrainApp/Views/TermEditorForm.swift` | Term label + dates editor | ✓ VERIFIED | Code present. |
| `UnibrainApp/Views/ClassificationPausedView.swift` | Loading state | ✓ VERIFIED | ProgressView + skip button. |
| `UnibrainApp/ViewModels/MenuBarViewModel.swift` | Phase 4 extensions | ✗ PARTIAL | overlayState, calendarPermission, selectCourse, skipClassification, setTerm, openSystemSettings all present. BUT handleClassificationPause never called from production code (only from tests). inputs.termLabel wired (line 318). |
| `UnibrainApp/MenuBarPopover.swift` | Overlay view-state switching | ✓ VERIFIED | body switches on overlayState first (line 22). .awaitingCourseSelection case added (line 49). |
| `UnibrainApp/UnibrainApp.swift` | DI + Info.plist + launch tasks | ⚠️ PARTIAL | CourseMappingStore + EventKitCalendarAdapter injected (lines 36-53). checkCalendarPermission + loadCurrentTerm on launch (lines 75-76). BUT orchestrator constructed via makeOrchestrator which uses HardcodedVaultResolver. |
| `UnibrainApp/Info.plist` | NSCalendarsUsageDescription | ✓ VERIFIED | Key present with correct string. |
| `Tests/UnibrainAppTests/MenuBarViewModelOverlayTests.swift` | Overlay state tests | ✓ VERIFIED | Tests pass (macOS CI only). 7 tests covering PopoverOverlay transitions. |
| `Sources/UnibrainProviders/Pipeline/PipelineWiring.swift` | Orchestrator factory | ✗ FAILED | Still wires HardcodedVaultResolver. No Phase 4 factory method exists. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| CourseMappingStore.upsert | .unibrain/courses.json | JSONEncoder + atomic write | ✓ WIRED | Verified in test 5, load sees upserted data. |
| EventKitCalendarAdapter.fetchEvents | CalendarEvent array | EKEventStore.predicateForEvents | ✓ WIRED (code-inspection) | Correct mapping at lines 121-129. macOS-only. |
| MenuBarViewModel.stopRecording | EventKitCalendarAdapter.fetchEvents | `events = try await provider.fetchEvents(in: dateRange)` | ✓ WIRED | Lines 303-308 in MenuBarViewModel. |
| PipelineWiring.makeOrchestrator | ScheduleAwareVaultResolver | Factory method | ✗ NOT_WIRED | Factory constructs HardcodedVaultResolver. ScheduleAwareVaultResolver is orphaned. |
| MenuBarViewModel.stopRecording | orchestrator.run(inputs:) | Task.detached | ✓ WIRED | Lines 325-336. inputs.termLabel set at line 318. |
| orchestrator.currentState == .awaitingUserChoice | MenuBarViewModel.handleClassificationPause | State observer | ✗ NOT_WIRED | No observer exists. handleClassificationPause defined but never called from production code. |
| CoursePickerView | CoursePickerViewModel (data) | View binding | ✗ NOT_WIRED | View has its own @State searchQuery but reads recentCourses/filteredCourses from hardcoded `[]`. Never receives the CoursePickerViewModel that handleClassificationPause constructs. |
| PermissionDeniedSheet button | NSWorkspace.open | openSystemSettings | ✓ WIRED | Line 31 calls viewModel.openSystemSettings(). |
| CoursePickerView tap | orchestrator.resume(with:) | viewModel.selectCourse | ✓ WIRED | Lines 71, 94, 119 call viewModel.selectCourse which calls overlayOrchestrator?.resume. |
| ManageCoursesView.loadMappings | CourseMappingStore.allMappings | Method call | ✅ NOT_WIRED | loadMappings returns `[:]` at line 154 — never calls store. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| CoursePickerView | recentCourses | CoursePickerViewModel | No | ⚠️ HOLLOW — view ignores the view model, returns `[]` |
| CoursePickerView | filteredCourses | CoursePickerViewModel | No | ⚠️ HOLLOW — same issue |
| ManageCoursesView | mappings | CourseMappingStore.allMappings | No | ⚠️ HOLLOW — loadMappings returns `[:]` |
| MenuBarViewModel.currentTermLabel | String | CourseMappingStore.currentTerm | Yes | ✓ FLOWING — loadCurrentTerm at line 544 fetches and sets |
| PipelineOrchestrator | resolver | ScheduleAwareVaultResolver | No | ✗ DISCONNECTED — HardcodedVaultResolver injected instead |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| CourseMappingStore round-trips JSON | `swift test --filter CourseMappingStoreTests` | 10/10 passed | ✓ PASS |
| TermRangeFilter narrows to ±30min | `swift test --filter TermRangeFilter` | 7/7 passed | ✓ PASS |
| PermissionState maps all statuses | `swift test --filter PermissionStateTests` | 9/9 passed | ✓ PASS |
| CoursePickerViewModel filters + selects | `swift test --filter CoursePickerViewModelTests` | 11/11 passed | ✓ PASS |
| Orchestrator parks + resumes + skips + cancels | `swift test --filter PipelineOrchestratorPauseTests` | 11/11 passed | ✓ PASS |
| NoteNormalizer accepts term/source params | `swift test --filter "NoteNormalizer Parameterization"` | 3/3 passed | ✓ PASS |
| ScheduleAwareVaultResolver builds paths | `swift test --filter ScheduleAwareVaultResolverTests` | 9/9 passed (macOS-only; skipped on Linux) | ✓ PASS |
| Full Phase 4 test suite (Linux runnable) | `swift test --filter "CourseMappingStoreTests\|TermRangeFilterTests\|PermissionStateTests\|CoursePickerViewModelTests\|PipelineOrchestratorPauseTests"` | 48/48 passed | ✓ PASS |
| EventKitCalendarAdapter maps EKEvent | `swift test --filter EventKitCalendarAdapterTests` | Not run (macOS-only) | ? SKIP |

### Probe Execution

Step 7c: SKIPPED (no probe scripts declared in PLAN or found in repository).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| CLAS-01 | 04-02 | EventKit queries calendar events overlapping recordingStart ±30min | ✓ SATISFIED (code) | EventKitCalendarAdapter.fetchEvents + TermRangeFilter + MenuBarViewModel.stopRecording fetch. Component-level tests pass. |
| CLAS-02 | 04-01, 04-04 | Maps matched event title → course folder via mapping table | ✗ BLOCKED | CourseMappingStore lookup works in isolation. BUT ScheduleAwareVaultResolver (which consults the mapping) is never wired into the orchestrator. HardcodedVaultResolver ignores CourseMatch. |
| CLAS-03 | 04-04 | Auto-creates a course folder for unrecognized event titles | ✗ BLOCKED | ScheduleAwareVaultResolver.resolve applies FolderNameSanitizer to unmapped titles (line 87) — correct. But never invoked in production. |
| CLAS-04 | 04-03, 04-05 | Manual course picker fallback shown when zero or multiple events match | ✗ BLOCKED | CoursePickerViewModel, CoursePickerView, PopoverOverlay all exist. BUT handleClassificationPause is never called (no state observer), AND CoursePickerView displays empty data. |
| CLAS-05 | 04-04 | Multi-term folder structure: {vault}/{term}/{course-code}/ | ✗ BLOCKED | ScheduleAwareVaultResolver produces correct paths (9 tests pass). But not wired into the orchestrator. |
| CLAS-06 | 04-02 | "Current term" filters out past-term events | ⚠️ NEEDS HUMAN | Logic present at every layer (TermDefinition in store, date range passed to fetchEvents, TermRangeFilter). Component tests pass. Full-chain behavior requires macOS device. |
| CLAS-07 | 04-01, 04-05 | Manual override remembered for next recording | ✗ BLOCKED | CourseMappingStore.upsert/addRecent work correctly. BUT the next recording uses HardcodedVaultResolver which ignores mappings. |
| ONBD-02 | 04-03, 04-05 | Microphone permission — hard-fail with explanation + Settings deep-link | ✓ SATISFIED (prior phase) | requestMicrophonePermission exists. ONBD-02 is marked complete in Phase 4 traceability but the work was Phase 3. |
| ONBD-03 | 04-02, 04-03, 04-05 | Calendar permission optional — degrades to manual picker | ✗ BLOCKED | PermissionState derivation works. PermissionDeniedSheet copy is correct. BUT the degradation path never fires because handleClassificationPause is never called. Even if it did, the picker shows empty data. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `UnibrainApp/Views/CoursePickerView.swift` | 183, 186 | Hardcoded empty arrays (`return []`) | 🛑 BLOCKER | Picker displays no courses — user cannot manually pick |
| `UnibrainApp/Views/ManageCoursesView.swift` | 154 | Hardcoded empty dict (`mappings = [:]`) | 🛑 BLOCKER | Manage Courses view shows empty table |
| `Sources/UnibrainProviders/Pipeline/PipelineWiring.swift` | 29 | Phase 3 resolver still in use | 🛑 BLOCKER | All recordings route to lectures/ with UNCLASSIFIED |
| `UnibrainApp/ViewModels/MenuBarViewModel.swift` | 425 | Method defined but never called from production | 🛑 BLOCKER | Picker overlay never appears; pipeline hangs at .awaitingUserChoice |

No `TBD`, `FIXME`, or `XXX` debt markers found in Swift source files.

### Human Verification Required

The following items need macOS device testing — they cannot be verified from WSL2 Linux:

### 1. Term Filter End-to-End (CLAS-06)

**Test:** Set a current term with an endDate in the past via the Term Editor. Create a calendar event from a past term that overlaps the current recording time. Record a 30-second clip and stop.
**Expected:** The past-term event is excluded from classification. The recording either does not match (triggers picker) or routes to a current-term folder — never to a past-term folder.
**Why human:** The term-range predicate logic is verified at the component level (TermRangeFilter tests, EventKitCalendarAdapter code inspection). But the full chain (EventKit → adapter → MenuBarViewModel → orchestrator → resolver) has never run on a device. Plus, Truth 1 failure (resolver not wired) blocks end-to-end verification. This should be re-tested after gaps close.

### 2. EventKit Permission Flow

**Test:** On first launch, tap Record. Verify the system permission dialog appears with the NSCalendarsUsageDescription string. Grant Full Access. Verify "Calendar connected" appears in idle state.
**Expected:** Permission dialog shows the Info.plist string. Status updates correctly.
**Why human:** EventKit permission API only works on macOS/iOS. Code is correct by inspection but runtime behavior is unverifiable from Linux.

### 3. ScheduleAwareVaultResolver Path Creation

**Test:** After gaps close (resolver wired), record during a scheduled lecture. Verify the note appears at `{vault}/{term}/{course-code}/YYYY-MM-DD-{COURSE}-Lecture.md` with real frontmatter values.
**Expected:** Correct path structure, sanitized folders, real course/term in frontmatter.
**Why human:** FileManager directory creation requires macOS. Component tests pass but end-to-end requires device.

### 4. Picker Overlay Rendering

**Test:** After gaps close (handleClassificationPause wired + data flowing), trigger a .none or .multiple match. Verify the picker appears inline (not as .sheet). Verify Recent + All Courses sections show real data.
**Expected:** Inline overlay with course list, not a detached window.
**Why human:** SwiftUI rendering requires macOS. Pitfall 2 (FB11984872) noted .sheet unreliability on MenuBarExtra — must verify inline switching works.

### Gaps Summary

Phase 4 produced all the right *components* — the pure-logic layer (CourseMappingStore, TermRangeFilter, PermissionState, CoursePickerViewModel) is fully implemented with passing tests, and the pipeline extensions (PipelineState.awaitingUserChoice, orchestrator pause/resume, NoteNormalizer parameterization, ScheduleAwareVaultResolver) are correct in isolation. 48 Linux-runnable tests pass. 9 macOS-only ScheduleAwareVaultResolver tests pass on CI.

However, Phase 4 failed at the **integration layer**. Four wiring gaps prevent the components from working together in the running app:

1. **Resolver not wired** (`PipelineWiring.swift`): The factory still constructs `HardcodedVaultResolver`. `ScheduleAwareVaultResolver` exists but is orphaned. Every recording still routes to `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md` with `UNCLASSIFIED` — Phase 3 behavior unchanged.

2. **No state observer** (`MenuBarViewModel.swift`): `handleClassificationPause` is defined but never called. When the orchestrator parks at `.awaitingUserChoice`, nothing in the UI layer detects it. The pipeline hangs indefinitely.

3. **Picker view has no data** (`CoursePickerView.swift`): `recentCourses` and `filteredCourses` return hardcoded `[]`. The `CoursePickerViewModel` that `handleClassificationPause` constructs is never passed to the view.

4. **ManageCourses has no data** (`ManageCoursesView.swift`): `loadMappings()` unconditionally returns `[:]`. The mapping table is always empty in the UI.

These four gaps mean that none of the five Success Criteria are observable in the running app. The components are individually correct (verified by 57 passing tests across Linux and macOS CI), but they are not connected.

The gaps are concentrated in the integration layer — specifically in `PipelineWiring.swift` (resolver factory), `MenuBarViewModel.swift` (state observation), `CoursePickerView.swift` (data binding), and `ManageCoursesView.swift` (data loading). A single follow-up plan addressing these four wiring points would close all five truth failures.

---

_Verified: 2026-07-15T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
