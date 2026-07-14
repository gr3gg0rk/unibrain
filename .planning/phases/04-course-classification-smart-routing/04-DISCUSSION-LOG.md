# Phase 4: Course Classification + Smart Routing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 4-Course Classification + Smart Routing
**Areas discussed:** Mapping table source, Permission degradation UX, Manual picker design, Current term mechanism

---

## Mapping Table Source

### Q1: Where does the title→course-code mapping live in Phase 4?

| Option | Description | Selected |
|--------|-------------|----------|
| @AppStorage JSON | JSON blob in UserDefaults; Phase 4 ships minimal table-sheet editor; Phase 6 replaces. Angelica can't edit outside app. | |
| Vault-side JSON | `.unibrain/courses.json` in vault root; iCloud-synced; human-editable. Obsidian-idiomatic. | ✓ |
| Frontmatter index note | `{vault}/.unibrain/Course-Index.md` YAML frontmatter list. Obsidian renders as readable note. Most native but more parsing. | |
| You decide | Claude picks based on constraints. | |

**User's choice:** Vault-side JSON
**Notes:** iCloud sync between Angelica's devices was the deciding factor; vault-as-source-of-truth philosophy.

### Q2: How does the mapping table get populated on Angelica's first recordings?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-learn on encounter | Empty default. First recording during event triggers CLAS-03 auto-folder + mapping update. Zero upfront setup. | ✓ |
| First-run calendar scan | App scans next 30 days, surfaces distinct titles, Angelica maps each upfront. Pre-seeds. | |
| Hybrid: auto + nudge | Empty default; after 3 recordings, "Review detected courses" sheet. | |
| You decide | Claude picks based on workflow. | |

**User's choice:** Auto-learn on encounter
**Notes:** Zero upfront friction was preferred. Auto-learn + Manage Courses sheet (Q4) handles refinements.

### Q3: When Angelica manually picks a course (CLAS-04), what gets "remembered" (CLAS-07)?

| Option | Description | Selected |
|--------|-------------|----------|
| Update mapping | Event title → course_code permanently updated. Same title auto-routes next time. Risk: one-off events also get mapped. | |
| Recent courses list | Picked course floats to top of next picker. Same title still triggers picker. Safer; Angelica taps once to confirm. | |
| Both | Mapping updates AND recent list updates. Best of both. | ✓ |
| You decide | Claude picks based on usage. | |

**User's choice:** Both
**Notes:** Recurring case gets automated (mapping update); ad-hoc picks still help (recent list). Planner can add "one-time only" toggle later if edge cases emerge.

### Q4: In Phase 4 (no Settings UI), how can Angelica view/edit the course mapping?

| Option | Description | Selected |
|--------|-------------|----------|
| Hand-edit JSON only | No in-app editor. `.unibrain/courses.json` in TextEdit/Obsidian. Minimal scope. | |
| Minimal in-app sheet | "Manage Courses" button in popover → editable SwiftUI table. Becomes Phase 6 Settings tab. | ✓ |
| Read-only view + JSON edit | Popover shows read-only list; edits via JSON file. | |
| You decide | Claude picks. | |

**User's choice:** Minimal in-app sheet
**Notes:** "Angelica never touches JSON" principle. ~50-100 lines SwiftUI; becomes Phase 6 courses tab.

---

## Permission Degradation UX

### Q1: When Angelica denies calendar Full Access, how does Phase 4 surface the degradation?

| Option | Description | Selected |
|--------|-------------|----------|
| First-time sheet + banner | One-time explanation sheet with System Settings deep-link; ongoing compact banner in popover. Most thoughtful. | ✓ |
| Always-on banner | No first-time sheet. Persistent "Calendar off — tap to enable" banner on every recording. Simple, slightly naggy. | |
| Silent degrade | No banner. Manual picker for every recording. Settings deep-link in future Permissions screen. Least intrusive. | |
| You decide | Claude picks. | |

**User's choice:** First-time sheet + banner
**Notes:** Explains WHY manual picking is happening without nagging.

### Q2: In Phase 4 (no onboarding yet), when does the EventKit permission request fire?

| Option | Description | Selected |
|--------|-------------|----------|
| On first recording | Mic + calendar access requested together at first Record tap. Just-in-time. | ✓ |
| On first app launch | Calendar access upfront (separate from mic). Front-loads the ask. | |
| On first Manage Courses visit | Requested only when Angelica opens the mapping sheet. No surprise prompts during recording. | |
| Manual "Connect" button | Popover has a "Connect Calendar" button; Angelica triggers explicitly. No surprises. | |

**User's choice:** On first recording
**Notes:** Just-in-time at moment of need; Phase 5 onboarding will streamline into welcome flow.

### Q3: Does Phase 4 ship iOS EventKit code, or stay macOS-focused?

| Option | Description | Selected |
|--------|-------------|----------|
| macOS-only | macOS EventKit adapter + permission flow. iOS stubbed. Phase 5 fills in iOS. | |
| macOS + iOS | Both adapters ship behind `#if os()` guards. Phase 5 wires iOS capture to ready adapter. | ✓ |
| macOS-only, no iOS stubs | Protocol abstraction + macOS only. iOS entirely Phase 5's responsibility. | |
| You decide | Claude picks. | |

**User's choice:** macOS + iOS
**Notes:** De-risks Phase 5; iOS code untested on device until Phase 5 activates it.

### Q4: Which calendars does the app query for matching events?

| Option | Description | Selected |
|--------|-------------|----------|
| All calendars | Every source (iCloud, Google, Outlook, local). Inclusive; might over-match. | ✓ |
| Default calendar only | `EKEventStore.defaultCalendarForNewEvents`. Conservative. | |
| All + per-calendar toggle | All by default; Manage Courses has multi-select toggle list. | |
| You decide | Claude picks. | |

**User's choice:** All calendars
**Notes:** Over-matching handled by manual picker fallback (.multiple case). Per-calendar toggle deferred to Phase 6 Settings.

---

## Manual Picker Design

### Q1: Where does the manual picker appear when CLAS-04 triggers?

| Option | Description | Selected |
|--------|-------------|----------|
| Sheet on popover | `.sheet` anchored to menu-bar popover. Compact, stays in menu-bar surface. | ✓ |
| Separate window | NSWindow/WindowGroup scene beside popover. More room; heavier UX. | |
| Inline popover expand | Popover grows taller to fit picker. Constrained width. | |
| You decide | Claude picks. | |

**User's choice:** Sheet on popover
**Notes:** Angelica never leaves her current app (Notes, PowerPoint).

### Q2: What does the manual picker list contain?

| Option | Description | Selected |
|--------|-------------|----------|
| Recent (5) + all (term) | Search + Recent section (5, current term) + All Courses alphabetical (current term). | ✓ |
| Flat list + highlights | No Recent section; flat alphabetical list with recently-used badged. | |
| Recent + term sections | Recent + All Current Term + Past Terms (collapsed). Most comprehensive. | |
| You decide | Claude picks. | |

**User's choice:** Recent (5) + all (term)
**Notes:** Assumes Angelica mostly re-records the same 3-5 courses.

### Q3: When no existing course matches the picker, what are Angelica's escape hatches?

| Option | Description | Selected |
|--------|-------------|----------|
| Create New + Skip | Create New Course form + Skip button (routes to `{vault}/{term}/_unsorted/`). Most flexible. | ✓ |
| Create New only | Must name a course before routing. No UNCLASSIFIED escape hatch. | |
| Skip only | Routes to `_unsorted/`; re-classify later by editing frontmatter + moving file. | |
| You decide | Claude picks. | |

**User's choice:** Create New + Skip
**Notes:** `_unsorted/` replaces Phase 3's `lectures/` for Phase 4+ unrouted recordings.

### Q4: When in the pipeline does the picker fire?

| Option | Description | Selected |
|--------|-------------|----------|
| At classify step | Pipeline pauses at `.classifying` until Angelica picks. Matches Phase 2 O-01. | ✓ |
| Right after Stop | Before transcription. Classify-first, then transcribe. | |
| Post-write Classify | Write to `_unsorted/` first; Classify action on notification. Fully async. | |
| You decide | Claude picks. | |

**User's choice:** At classify step
**Notes:** Phase 4 extends Phase 2's orchestrator with `.awaitingUserChoice` pause state (explicitly deferred in Phase 2 CONTEXT).

---

## Current Term Mechanism

### Q1: How is the "Current term" defined and stored?

| Option | Description | Selected |
|--------|-------------|----------|
| Single term + dates | `{label, startDate, endDate}`. EventKit query filters to `[term.startDate, term.endDate]`. Precise. | ✓ |
| Label only (loose) | String label; ±90 days of today filter. Simpler, less precise. | |
| Term history list | List of past + current terms; "current" = today's date match. Most setup, most flexibility. | |
| You decide | Claude picks. | |

**User's choice:** Single term + dates
**Notes:** Date range enables exact filtering; excludes stale recurring events from past terms.

### Q2: What happens when the current term's endDate passes?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detect + nudge | Popover banner "Fall 2026 ended — set new term?" Recordings still work via picker fallback. | ✓ |
| Silent expire | Keeps using expired term until manually updated. Simplest; relies on Angelica noticing. | |
| Hard block + modal | Blocks recording until new term set. Strictest; most friction. | |
| You decide | Claude picks. | |

**User's choice:** Auto-detect + nudge
**Notes:** Non-blocking; recordings still succeed via manual picker if EventKit returns zero events.

### Q3: Where does the current term value live?

| Option | Description | Selected |
|--------|-------------|----------|
| Same JSON file | `.unibrain/courses.json` holds mapping + current_term. One source of truth. | ✓ |
| Separate JSON | `.unibrain/current-term.json`. Cleaner separation. | |
| @AppStorage split | Term in UserDefaults; mapping in vault JSON. Different persistence layers. | |
| You decide | Claude picks. | |

**User's choice:** Same JSON file
**Notes:** Both are vault-level course metadata; belong together.

### Q4: When CourseClassifier returns .multiple, what does the picker show?

| Option | Description | Selected |
|--------|-------------|----------|
| Events with details | Overlapping events as rows with title + time + location. Course list as fallback. Most informative. | ✓ |
| Courses only | Deduplicated courses (both events → one row). Loses event detail. | |
| Auto-dedupe if same course | Auto-route if both events map to same course; only picker if different courses. | |
| You decide | Claude picks. | |

**User's choice:** Events with details
**Notes:** Angelica can distinguish "CS101 Lecture (10:00–11:30, Watson 200)" from "CS101 Lab (10:00–12:00, Watson Lab)".

---

## Claude's Discretion

Areas where Claude has flexibility (noted in CONTEXT.md `<decisions>` → Claude's Discretion section):

- Course code derivation from unrecognized event titles (sanitizer output format)
- `courses.json` exact schema shape (field names, nesting, versioning)
- EventKit predicate composition (single predicate vs. Swift-side filter)
- `EKEvent` → `CalendarEvent` adapter field mapping (including recurring event handling)
- `.awaitingUserChoice` orchestrator state design (new top-level case vs. sub-state; continuation pattern)
- macOS System Settings deep-link URL construction
- First-time-sheet microcopy
- "Recent" courses ordering (MRU vs. MFU)
- Manage Courses sheet exact layout
- Term label sanitizer output (preserve spaces vs. slugify)

## Deferred Ideas

- Full Settings UI → Phase 6 (CLOUD-01). Phase 4 ships only Manage Courses sheet.
- Per-calendar toggle → Phase 6 Settings. Phase 4 queries all inclusively.
- First-run onboarding flow → Phase 5 (ONBD-01). Phase 4 fires permission just-in-time.
- iOS capture activation → Phase 5 (CAPT-03). Phase 4 ships iOS adapter untested.
- iCloud Drive `_inbox/` pickup → Phase 5.
- "Regenerate with whisper.cpp" action → Phase 6 polish.
- Embeddings index → v2 (EMBD-01..04).
- Syllabus parsing → v2 (SYLL-01..03).
- Confidence score in CourseMatch → v2.
- One-time-only manual pick toggle → Phase 6 polish if edge cases emerge.
- Multi-speaker diarization → v2.
- Cloud ASR providers → Phase 6 (CLOUD-03..06).
