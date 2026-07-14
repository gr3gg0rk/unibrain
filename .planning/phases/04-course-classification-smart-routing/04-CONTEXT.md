# Phase 4: Course Classification + Smart Routing - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Every recording auto-routes to the correct course folder based on Angelica's Apple Calendar schedule — the competitive moat. Phase 4 wires real EventKit (macOS + iOS adapters behind `#if os()` guards), a vault-side title→course-code mapping table (`.unibrain/courses.json`), multi-term folder structure (`{vault}/{term}/{course-code}/`), auto-learned mappings on first encounter, a manual picker fallback for `.multiple`/`.none` CourseClassifier results, remembered overrides (CLAS-07), the "Current term" date-ranged filter, and the permission-degradation UX (first-time sheet + ongoing banner) for when calendar Full Access is denied or unavailable. The picker fires at the orchestrator's `.classifying` step (extending Phase 2's state machine with a pause/resume capability that was explicitly deferred).

Phase 4 ships both macOS AND iOS EventKit adapters in `UnibrainProviders` — iOS is stubbed-but-compiling; Phase 5 wires iOS capture to the ready adapter. Phase 4 success criteria are macOS-testable.

**Phase 3 dependency:** Phase 4 assumes Phase 3's menu-bar popover, recording pipeline, and `~/Documents/Unibrain/` vault root exist. Phase 3's `lectures/` test folder stays in place (no migration per P-14). Phase 4 introduces the real `{vault}/{term}/{course-code}/` routing structure for new recordings.

**Phase 2 dependency:** Phase 4 assumes `CalendarEvent`, `CourseClassifier` (returns `CourseMatch`), `FolderNameSanitizer`, `PipelineInputs.events`, `PipelineOrchestrator`, and `NoteWriter` protocol all exist in `UnibrainCore`.

</domain>

<decisions>
## Implementation Decisions

### Mapping Table Source (CLAS-02)

- **M-01: Vault-side JSON at `.unibrain/courses.json`.** Mapping lives in a hidden dotfolder inside the vault root. Obsidian-idiomatic (vault is the source of truth), syncs via iCloud Drive between Angelica's devices, human-editable in any text editor. Storage location is deliberately inside the vault so iCloud sync keeps it consistent across MacBook/iPhone/iPad.
- **M-02: Auto-learn on encounter (empty default).** No first-run calendar scan. First recording during an unmapped calendar event triggers CLAS-03 auto-folder creation (sanitized event title → `FolderNameSanitizer.sanitize()`), and the mapping updates so the next recording with the same event title routes directly. Zero upfront setup.
- **M-03: Manual pick updates BOTH mapping AND recent list (CLAS-07).** When Angelica picks a course manually, the event title → course_code mapping is permanently updated (same title auto-routes next time) AND the picked course is added to a "recently used" list that floats to the top of the next picker. Best of both — recurring lectures get automated; ad-hoc picks still help via the recent shortcut. Planner can add a "one-time only" toggle later if edge cases emerge.
- **M-04: Minimal in-app Manage Courses sheet in Phase 4.** Menu-bar popover gets a "Manage Courses" button → SwiftUI sheet showing the mapping as an editable table (columns: event title, course code, course name, term). Becomes the Phase 6 Settings UI's courses tab later. Angelica never has to hand-edit JSON. Roughly 50-100 lines of SwiftUI.

### Permission Degradation UX (ONBD-02, ONBD-03)

- **P-01: First-time sheet + ongoing banner.** When the app detects calendar Full Access is denied (or only write-only granted), the first time a recording would have used calendar classification, a one-time explanation sheet appears: "Enable calendar for automatic course routing — Angelica will need to pick courses manually otherwise" with an "Open System Settings" deep-link. Subsequent recordings show a compact banner in the popover ("Calendar off — manual pick required") that's tappable to re-open Settings.
- **P-02: Permission request fires on first recording.** Just-in-time at the moment of need. When Angelica hits Record for the first time, app requests mic AND calendar access together if not yet granted (mic path inherits from Phase 3). Phase 5 onboarding (ONBD-01) will move this into a guided welcome flow.
- **P-03: macOS + iOS EventKit adapters BOTH ship in Phase 4.** Both adapters compile in `UnibrainProviders` behind `#if os(macOS)` / `#if os(iOS)` guards. iOS conformance is code-complete but untested on device (Phase 5 activates + tests iOS). De-risks Phase 5 — iOS capture just wires into the ready adapter.
- **P-04: All calendars queried inclusively.** App queries every calendar source on the device (iCloud, Google, Outlook, local) via `EKEventStore.predicateForEvents(...)` with `calendars: nil`. Over-matching is handled by the manual picker fallback (`.multiple` case). No per-calendar toggle in Phase 4 (Phase 6 Settings can add one if Angelica reports noise).
- **P-05: STATE.md blocker resolved — verify `.fullAccess` explicitly.** Planner must verify `EKEventStore.requestFullAccessToEvents(completion:)` (iOS 17+ / macOS 14+) returns `.fullAccess` specifically; treat `.writeOnly` as denied (same degradation flow). STATE.md flagged this as a known iOS version variance.

### Manual Picker Design (CLAS-04)

- **MP-01: Sheet on menu-bar popover.** `.sheet` modifier anchored to the menu-bar popover window. Slides down over the popover when CLAS-04 triggers. Stays in the menu-bar surface — Angelica never leaves her current app (Notes, PowerPoint, etc.). Compact width (~280pt) matching Phase 3's popover.
- **MP-02: Recent (5) + All Courses (current term).** Search field at top. Below: "Recent" section showing 5 most-recently-used courses (current term only). Below that: "All Courses" alphabetical list (current term only). Tap selects + dismisses. Assumes Angelica mostly re-records the same 3-5 courses.
- **MP-03: Create New + Skip escape hatches.** "Create New Course" button at bottom of picker → small form (course code + name) → creates folder, adds to mapping, routes recording there. "Skip" button → routes to `{vault}/{term}/_unsorted/` with `course: UNCLASSIFIED` frontmatter (replaces Phase 3 P-14's `lectures/` placeholder for unrouted Phase 4+ recordings; Phase 3 test notes stay in `lectures/`).
- **MP-04: Picker fires at `.classifying` step.** Matches Phase 2 O-01 state machine: idle → transcribing → classifying → normalizing → writing → completed. When `CourseClassifier` returns `.multiple` or `.none`, pipeline pauses at `.classifying` until Angelica picks, then resumes. Phase 2 explicitly deferred `.awaitingUserChoice` pause state to Phase 4 — planner extends orchestrator with this state.
- **MP-05: Multi-match shows events with details.** When `.multiple` fires, picker shows the overlapping calendar events as distinct rows with title + time range + location (e.g., "CS101 Lecture (10:00–11:30, Watson 200)" vs "CS101 Lab (10:00–12:00, Watson Lab)"). Course list below as fallback. Angelica picks the specific event she attended.

### Current Term Mechanism (CLAS-05, CLAS-06)

- **CT-01: Single term + date range.** `currentTerm = { label: String, startDate: Date, endDate: Date }`. Stored in the same `.unibrain/courses.json` file as the mapping (one source of truth). Example: `{ label: "Fall 2026", startDate: "2026-08-25", endDate: "2026-12-15" }`.
- **CT-02: EventKit query filters to `[term.startDate, term.endDate]`.** The ±30min recording window from Phase 2 C-03 is still applied, but the EventKit query predicate uses the term range as the outer bound. Past-term events with overlapping timeslots are excluded. Planner verifies EventKit predicate composition (likely `predicateForEvents(withStart: currentTerm.startDate, end: currentTerm.endDate, calendars: nil)` then Swift-side filter by recording window ±30min).
- **CT-03: Auto-detect term-end nudge.** When app detects `today > currentTerm.endDate`, popover shows a "Fall 2026 ended — set your new term?" banner with a "Set Term" button. Recordings still work (fall through to manual picker if EventKit returns zero events in the expired term's range). Non-blocking.
- **CT-04: Folder path uses sanitized term label.** Per CLAS-05, `{vault}/{term}/{course-code}/`. Term slug = `FolderNameSanitizer.sanitize(currentTerm.label)` (e.g., "Fall 2026" → "Fall 2026"). Planner picks exact sanitizer output (spaces preserved vs slugified).

### Claude's Discretion

- **Course code derivation from unrecognized event titles** — when CLAS-03 auto-creates a folder for an unrecognized title, the resulting course_code is the sanitized event title (via Phase 2 C-05 `FolderNameSanitizer`). Planner picks whether to preserve spaces ("CS101 Intro"), slugify ("CS101-Intro"), or attempt pattern extraction ("CS101"). FolderNameSanitizer's existing rules strip unsafe chars and collapse whitespace; additional slugification is planner's call.
- **`courses.json` schema shape** — the JSON structure for the mapping table and current term. Planner picks exact field names, nesting, and versioning (`schema_version: 1` recommended for forward compat).
- **EventKit predicate composition** — exact `NSPredicate` construction for combining the term date range and the recording ±30min window. Planner verifies whether to use a single predicate or filter in Swift.
- **EKEvent → CalendarEvent adapter specifics** — Phase 2 C-01 defined the `CalendarEvent` struct shape. Phase 4's adapter maps `EKEvent` fields (title, startDate, endDate, location, eventIdentifier) to `CalendarEvent`. Recurring event handling (whether `EKEvent` returns one event or many for a recurring series) is planner's call based on Apple docs.
- **`.awaitingUserChoice` orchestrator state design** — Phase 2 O-01 deferred this to Phase 4. Planner decides whether it's a new top-level `PipelineState` case or a sub-state of `.classifying`. Pause/resume mechanics (how the orchestrator parks mid-run and resumes on user selection) is the key design decision.
- **macOS System Settings deep-link** — macOS lacks `UIApplication.openSettingsURLString`. Planner picks the equivalent (likely `NSWorkspace.open(URL)` with a `x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars` URL).
- **First-time-sheet microcopy** — exact wording of the permission-denied explanation sheet.
- **"Recent" courses ordering** — most-recently-used first vs. most-frequently-used first. MRU is simpler and likely the right default.
- **Manage Courses sheet exact layout** — table columns, edit interactions, delete confirmation. Becomes Phase 6 Settings tab.
- **Folder sanitizer output for term label** — preserve "Fall 2026" verbatim, or slugify to "fall-2026".

### Folded Todos

None — no pending todos in `.planning/STATE.md` §"Pending Todos" matched Phase 4 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Planning (in this repo)
- `.planning/PROJECT.md` — project definition, constraints, Key Decisions table. The "Core Value" mandate ("Every recording lands in the right course folder") IS Phase 4 — this is the moat. MacBook Neo macOS 26 / iOS 17 / 8GB constraints shape every decision.
- `.planning/REQUIREMENTS.md` §"Classify" — Phase 4 requirements: CLAS-01 (EventKit ±30min overlap query), CLAS-02 (title→course-code mapping via settings — M-01 puts it in `.unibrain/courses.json`), CLAS-03 (auto-create sanitized folder for unrecognized titles), CLAS-04 (manual picker with recent + search), CLAS-05 (multi-term folder structure `{vault}/{term}/{course-code}/`), CLAS-06 (Current term filter), CLAS-07 (manual override remembered).
- `.planning/REQUIREMENTS.md` §"Onboarding" — ONBD-02 (mic permission required — Phase 3 path), ONBD-03 (calendar permission optional — degrades to manual picker; P-01 makes the degradation UX concrete).
- `.planning/ROADMAP.md` §"Phase 4: Course Classification + Smart Routing" — phase goal, mode (mvp), depends-on (Phase 3), requirements, five success criteria.
- `.planning/STATE.md` §"Blockers/Concerns" — EventKit `.fullAccess` vs `.writeOnly` behavior varies by iOS version (P-05 resolves by verifying `.fullAccess` explicitly).

### Phase 1 CONTEXT (decisions carried forward)
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-05 (macOS 26 / iOS 17 deployment targets — unlocks `EKEventStore.requestFullAccessToEvents`), D-07 (three SPM targets: `UnibrainCore` Foundation-only, `UnibrainProviders` macOS/iOS-only, `UnibrainApp` Xcode app), D-08 (test target split: `UnibrainProvidersTests` macOS-only), D-15..17 (four standalone provider protocols, `ProviderError`, single-shot async/throws).

### Phase 2 CONTEXT (contracts Phase 4 wires)
- `.planning/phases/02-pure-pipeline-logic/02-CONTEXT.md` — C-01 (`CalendarEvent` struct shape: `{ id, title, startDate, endDate, location? }`), C-02 (`CourseMatch` enum: `.single` / `.multiple` / `.none`), C-03 (±30min time-overlap window), C-04 (title→course-code mapping DEFERRED to Phase 4 — M-01 resolves), C-05 (`FolderNameSanitizer` pure logic), O-01 (8-state `PipelineState` lifecycle), O-02 (`actor PipelineOrchestrator`), O-05 (`PipelineInputs.events: [CalendarEvent]` — Phase 4 populates this from EventKit).

### Phase 3 CONTEXT (vault + popover integration)
- `.planning/phases/03-macos-capture-transcribe/03-CONTEXT.md` — P-08 (menu-bar popover is primary recording surface — Phase 4's picker sheet attaches here), P-09 (popover ~280pt wide — constrains picker layout), P-13 (`~/Documents/Unibrain/` vault root default), P-14 (Phase 3 notes stay in `lectures/` — no migration), P-16 (`_inbox/` reserved for Phase 5 iCloud handoff — Phase 4's unrouted recordings go to `{vault}/{term}/_unsorted/` instead).

### Existing Code (the assets Phase 4 extends)
- `Sources/UnibrainCore/Protocols/AudioTranscriber.swift` (and siblings) — Phase 1's four standalone provider protocols. Phase 4 may add a fifth: an `EventProvider` protocol (or similar) abstracting EventKit access, in `UnibrainCore`, with macOS/iOS conformances in `UnibrainProviders`. Planner decides whether EventKit access goes through a new protocol or the `PipelineInputs.events` injection pattern from Phase 2 O-05.
- `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` — existing 12-field frontmatter schema (WRITE-02). Phase 4 writes real values for `course`, `course_name`, `term` (replacing Phase 3's placeholders `UNCLASSIFIED` / `Phase 3 Test` / `phase-3`).
- `Sources/UnibrainCore/Errors/ProviderError.swift` — Phase 1's shared error enum. Phase 4's EventKit adapter throws `ProviderError` variants for permission failures, predicate errors, etc.
- `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` — Phase 1's actor. Phase 4 doesn't load heavy models (no ASR/LLM work here), so the gate is unused in the EventKit path.
- `UnibrainApp/UnibrainApp.swift` — Phase 1's app shell with `MenuBarExtra`. Phase 3 replaced the placeholder with the recording popover; Phase 4 adds the "Manage Courses" button + picker sheet + permission-denied banner to this surface.
- `Sources/UnibrainProviders/ProtocolDefaults/ProviderDefaults.swift` — Phase 1's protocol default extensions.

### External Documentation (consult during planning)
- [EKEventStore (Apple Developer)](https://developer.apple.com/documentation/eventkit/ekeventstore) — EventKit entry point.
- [EKEventStore.requestFullAccessToEvents(completion:) (Apple Developer)](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)) — iOS 17+ / macOS 14+ permission API. P-05 verifies `.fullAccess` return value explicitly.
- [predicateForEvents(withStart:end:calendars:) (Apple Developer)](https://developer.apple.com/documentation/eventkit/ekeventstore/predicateforevents(withstart:end:calendars:)) — CT-02 term-range query predicate.
- [WWDC23: Discover Calendar and EventKit](https://developer.apple.com/videos/play/wwdc2023/10052/) — iOS 17 permission flow changes.
- [EKEvent (Apple Developer)](https://developer.apple.com/documentation/eventkit/ekevent) — event structure (title, startDate, endDate, location, eventIdentifier for stable identity).
- [NSWorkspace.open(URL) (Apple Developer)](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:)) — macOS deep-link mechanism for System Settings (P-01 deep-link).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`FrontmatterSchema`** (`Sources/UnibrainCore/Schemas/FrontmatterSchema.swift`) — already carries `course`, `course_name`, `term` fields. Phase 4 writes real values; Phase 3 wrote placeholders.
- **`ProviderError`** (`Sources/UnibrainCore/Errors/ProviderError.swift`) — Phase 4's EventKit adapter reuses this enum for `.permissionDenied`, `.underlying(any Error)`, etc. If new variants are needed (e.g., `.writeOnlyGranted`), planner extends the enum.
- **Phase 2 contracts (when shipped):**
  - `CalendarEvent` struct — Phase 4's EventKit adapter produces these from `EKEvent`.
  - `CourseClassifier.match(events:against:window:)` — Phase 4 calls this with the fetched `[CalendarEvent]`; returns `CourseMatch` for the routing decision.
  - `FolderNameSanitizer.sanitize(folderName:)` — Phase 4 calls it for CLAS-03 auto-folder-creation and term-label slugification (CT-04).
  - `PipelineInputs.events: [CalendarEvent]` — Phase 4 fetches events from EventKit and injects them.
  - `PipelineOrchestrator` — Phase 4 extends with `.awaitingUserChoice` pause state (MP-04).
  - `NoteWriter.write(_:to:)` — Phase 3's `NSFileCoordinatorNoteWriter` conformance already creates the `{vault}/{term}/{course_code}/` tree (Phase 2 A-05).

### Established Patterns
- **Swift 6 strict concurrency** (`actor`, `Sendable`, `async/await`) — Phase 4's EventKit adapter and any new state on `PipelineOrchestrator` use these idioms.
- **Protocol-abstraction layer** — EventKit access goes behind a protocol in `UnibrainCore` (planner decides between new `EventProvider` protocol vs. direct `PipelineInputs.events` injection). macOS/iOS conformances ship in `UnibrainProviders`.
- **`#if os(macOS)` / `#if os(iOS)` guards** — P-03 both adapters ship in Phase 4 behind platform guards.
- **`if #available(macOS 26, *)` / iOS 17 checks** — `requestFullAccessToEvents` is iOS 17+ / macOS 14+ (Phase 1 D-05 deployment targets cover this).
- **swift-testing framework** — `@Test`, `#expect`. Phase 4's macOS-only tests in `UnibrainProvidersTests` use this.
- **Vault-side hidden dotfolder** — `.unibrain/` prefix mirrors Obsidian's convention for app metadata inside a vault (e.g., `.obsidian/`).

### Integration Points
- **`UnibrainApp` menu-bar popover** — Phase 3 owns the recording UI. Phase 4 adds: (a) "Manage Courses" button → sheet (M-04), (b) picker `.sheet` for CLAS-04 (MP-01), (c) permission-denied banner (P-01), (d) term-expired banner (CT-03).
- **`PipelineOrchestrator.run(inputs:)`** — Phase 4's caller (likely the Phase 3 recording-session controller) constructs `PipelineInputs` with `events` fetched from EventKit. Orchestrator state machine extended with `.awaitingUserChoice` pause (MP-04).
- **`.unibrain/courses.json`** — new file in the vault root. Read at app launch (for Manage Courses + recent courses list), written on auto-learn (M-02), manual pick (M-03), and term updates (CT-01). Phase 6 Settings UI reads/writes the same file.
- **`.github/workflows/ci.yml`** — Phase 4 extends the macOS job with `UnibrainProvidersTests` cases for EventKit adapter (mocked `EKEventStore`) and `CourseClassifier` integration (real classifier + mock events).

</code_context>

<specifics>
## Specific Ideas

- **"Auto-learn on encounter" (M-02) is the keystone UX decision.** Zero upfront setup — Angelica's first recording during "CS101 Lecture" creates the folder + mapping automatically. This is the closest thing to magic in the MVP and the clearest expression of the Core Value ("every recording lands in the right folder without manual organization"). The cost: course codes may be verbose until Angelica refines them via Manage Courses (M-04). Accepted tradeoff.
- **Both-adapters-ship-in-Phase-4 (P-03) is a deliberate scope expansion.** Phase 3 was macOS-only; Phase 4 ships iOS EventKit code too, untested. This de-risks Phase 5 (iOS capture just wires in). The cost: ~30% more Phase 4 work for code that won't run until Phase 5. Justified because Phase 5's scope (background recording, iCloud handoff, onboarding) is already heavy — removing the EventKit implementation from Phase 5 lets it focus on capture + sync.
- **The `.awaitingUserChoice` orchestrator extension (MP-04) is the riskiest Phase 4 architectural change.** Phase 2 shipped fail-fast; Phase 4 adds pause/resume mid-run. Planner must design this carefully — the orchestrator can't just block on a synchronous user input. Likely pattern: orchestrator emits the `.awaitingUserChoice` state with a continuation closure; UI layer picks, then calls `orchestrator.resume(with: courseSelection)`. Swift 6 structured concurrency (`CheckedContinuation`) may be the right primitive.
- **The `_unsorted/` folder replaces Phase 3's `lectures/`** for Phase 4+ unrouted recordings (MP-03 Skip path). Phase 3 test notes stay in `lectures/` (no migration per P-14). New recordings that Skip classification land in `{vault}/{term}/_unsorted/`. Underscore prefix sorts it at the top in Obsidian.
- **The `.unibrain/` dotfolder lives inside the vault** so iCloud Drive syncs the mapping between Angelica's devices. This is intentional — she might add a course on her MacBook and have it immediately available on her iPhone (Phase 5). The folder is hidden from Obsidian's default view (dotfiles don't show unless "Detect all file extensions" is enabled).
- **CLAS-07's "remembered per course" was ambiguous in the spec.** M-03 resolves it as BOTH mapping-update AND recent-list-update. The mapping update is the automation mechanism (same title → same course next time); the recent list is the speed-Shortcut (even ad-hoc picks are one tap away next time). Both write to `.unibrain/courses.json`.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The following items were considered but explicitly belong in other phases:

- **Full Settings UI (per-modality LLM/ASR/Vision/TTS provider selectors, etc.)** → Phase 6 (CLOUD-01). Phase 4 ships only the Manage Courses sheet as a minimal in-app editor (M-04) that becomes Phase 6's courses tab.
- **Per-calendar toggle (include/exclude specific calendars from matching)** → Phase 6 Settings. Phase 4 queries all calendars inclusively (P-04).
- **First-run onboarding flow (welcome → vault picker → mic → calendar → term → ready)** → Phase 5 (ONBD-01). Phase 4 fires permission request just-in-time on first recording (P-02).
- **iOS capture activation + background recording** → Phase 5 (CAPT-03). Phase 4 ships iOS EventKit adapter (P-03) but doesn't wire it to capture.
- **iCloud Drive `_inbox/` pickup for iPhone-originated audio** → Phase 5. Phase 4 is macOS-only in practice.
- **"Regenerate with whisper.cpp" action** → Phase 6 polish (per Phase 3 deferred items).
- **Embeddings index / semantic search over transcripts** → Phase 2 (v2 requirements EMBD-01..04). Phase 4 is exact-match routing only.
- **Syllabus parsing + milestone tracking** → Phase 2 (v2 requirements SYLL-01..03). Phase 4 routes based on calendar events, not syllabus data.
- **Confidence score in CourseMatch** → v2. Angelica doesn't need a confidence bar in MVP.
- **One-time-only manual pick toggle** (pick for this recording only, don't update mapping) → Phase 6 polish if edge cases emerge (M-03).
- **Multi-speaker diarization** → v2. Phase 4 assumes single-lecturer audio (inherited from Phase 3).
- **Cloud ASR providers (OpenAI Whisper-1, etc.)** → Phase 6 (CLOUD-03..06). Phase 4 doesn't touch ASR.

### Reviewed Todos (not folded)

None — no todos existed in `.planning/STATE.md` §"Pending Todos" at discussion time.

</deferred>

---

*Phase: 4-Course Classification + Smart Routing*
*Context gathered: 2026-07-14*
