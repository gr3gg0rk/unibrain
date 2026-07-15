---
phase: 4
slug: course-classification-smart-routing
status: draft
shadcn_initialized: false
preset: none
created: 2026-07-15
---

# Phase 4 — UI Design Contract

> Visual and interaction contract for course classification + smart routing UI surfaces.
> Generated from 04-CONTEXT.md decisions M-01..M-04, P-01..P-05, MP-01..MP-05, CT-01..CT-04.
> Inherits Phase 3 design tokens (native SwiftUI, SF Pro, SF Symbols, 280pt popover, semantic system colors).

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (native SwiftUI — no shadcn/web tooling applicable) |
| Preset | not applicable |
| Component library | SwiftUI (Apple-built — `.sheet`, `List`, `Section`, `TextField`, `Button`, `Label`, `Banner`) |
| Icon library | SF Symbols (system — inherits Phase 3 set + `calendar.badge.exclamationmark`, `magnifyingglass`, `plus.circle`, `folder`, `chevron.right`, `exclamationmark.triangle.fill`) |
| Font | SF Pro (system default — `.body`, `.headline`, `.caption`, `.subheadline` semantic roles) |
| Platform | macOS 26 Tahoe (deployment target D-05); iOS 17 (P-03 adapter ships but UI is macOS-only in Phase 4) |

**Design language:** Native macOS menu-bar app. Follows Apple Human Interface Guidelines for `MenuBarExtra` popover surfaces and `.sheet` modifiers. No custom theming layer — uses standard semantic colors so the app automatically respects Light/Dark mode and system accent color preferences. Phase 4 extends Phase 3's popover with classification surfaces; no Phase 3 tokens change.

**Inheritance:** All Phase 3 design tokens (spacing scale, typography, color, tone) carry forward unchanged. Phase 4 adds new surfaces within the same design language.

---

## Spacing Scale

Inherited from Phase 3 — unchanged. SwiftUI points (pt). All multiples of 4pt.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4pt | Icon gaps, inline label padding, picker row leading inset |
| sm | 8pt | Compact row spacing, button gap horizontal, banner internal padding |
| md | 12pt | Default element vertical spacing, picker section gap (**12pt exception** — 280pt popover width requires finer granularity between sm(8) and lg(16); Apple HIG uses 12pt as a standard token) |
| lg | 16pt | Section padding within popover, picker search field padding |
| xl | 24pt | Popover top/bottom padding, sheet top padding |
| 2xl | 32pt | Major section break (not used — surfaces are compact) |

**Popover width:** 280pt fixed (inherited from Phase 3 P-09).

**Sheet width:** Picker sheet and Manage Courses sheet inherit the 280pt popover width — they present `.sheet(style: .popover)` anchored to the menu-bar popover. Stays in the menu-bar surface (MP-01 — Angelica never leaves her current app).

**Exceptions:** none — native macOS HIG spacing tokens.

---

## Typography

Inherited from Phase 3 — unchanged. Native SF Pro via SwiftUI semantic styles. No custom fonts.

| Role | SwiftUI Style | Approx Size | Weight | Line Height |
|------|--------------|-------------|--------|-------------|
| Body / status line | `.body` | 13pt | regular | 1.4 |
| Label (button) | `.headline` | 13pt | semibold | 1.3 |
| Subheadline (picker row title) | `.subheadline` | 12pt | regular | 1.3 |
| Caption (metadata, time range) | `.caption` | 10pt | regular | 1.3 |
| Section heading (picker sections) | `.headline` | 13pt | semibold | 1.3 |

**No new typography roles introduced.** Phase 4 surfaces use the existing type scale. The picker rows use `.subheadline` for course titles (compact density for the 280pt width) and `.caption` for metadata (time range, location, term label).

---

## Color

Inherited from Phase 3 — unchanged. Native macOS semantic colors.

| Role | Value (Light/Dark) | Usage |
|------|-------------------|-------|
| Dominant (60%) | `Color(nsColor: .windowBackgroundColor)` | Popover/sheet background |
| Secondary (30%) | `Color(nsColor: .controlBackgroundColor)` / `.secondaryFill` | Cards, button backgrounds, picker row selected state |
| Accent (10%) | `Color.accentColor` (user-selected system accent) | Primary CTA fill, selected picker row checkmark, "Set Term" button |
| Destructive | `Color.red` | Delete course button (Manage Courses), Skip confirmation |
| Warning / Permission denied | `Color.orange` | Permission-denied banner, term-expired banner, "Calendar off" indicator |
| Success | `Color.green` | "Calendar connected" indicator, auto-routed confirmation |
| Text primary | `Color.primary` (`.labelColor`) | All primary text |
| Text secondary | `Color.secondary` (`.secondaryLabelColor`) | Picker row metadata, banner body text |

**Accent reserved for:**
- Primary CTA in picker ("Select Course" confirm)
- Selected picker row checkmark accent
- "Set Term" button in term-expired banner
- "Open System Settings" deep-link button in permission sheet

**Warning (orange) reserved for:**
- Permission-denied banner background tint
- Term-expired banner background tint
- "Calendar off" status indicator

**Destructive (red) reserved for:**
- Delete course mapping action (Manage Courses sheet)
- "Skip" is NOT destructive — it routes to `_unsorted/`, not deletion. Skip uses secondary button style.

---

## New Surfaces & Layouts

### Surface 1: Manual Course Picker Sheet (MP-01..MP-05)

Presented as `.sheet` anchored to the menu-bar popover when `CourseClassifier` returns `.multiple` or `.none`, or when calendar permission is denied and Angelica records.

**Fixed width:** 280pt (matches popover — MP-01).

#### Variant A: Multi-Match (`.multiple` — MP-05)

When multiple calendar events overlap the recording window, the picker shows the specific events as distinct rows so Angelica picks the one she attended.

```
┌─────────────────────────────────────┐
│  Which lecture is this?             │
│                                     │
│  Matching calendar events:          │
│  ┌─────────────────────────────────┐│
│  │ CS101 Lecture                   ││
│  │ 10:00–11:30 · Watson 200        ││
│  ├─────────────────────────────────┤│
│  │ CS101 Lab                       ││
│  │ 10:00–12:00 · Watson Lab        ││
│  └─────────────────────────────────┘│
│                                     │
│  ─── Or pick from all courses ───   │
│                                     │
│  [🔍 Search courses…           ]    │
│                                     │
│  Recent                             │
│  • CS101 Intro to CS                │
│  • MATH200 Calculus II              │
│  • PHIL101 Ethics                   │
│                                     │
│  All Courses (Fall 2026)            │
│  • BIO150 Cellular Biology          │
│  • CS101 Intro to CS                │
│  • ENGL220 Shakespeare              │
│  • MATH200 Calculus II              │
│  • PHIL101 Ethics                   │
│                                     │
│  [ + Create New Course ]            │
│  [   Skip (save to _unsorted)   ]   │
└─────────────────────────────────────┘
```

#### Variant B: No Match / Permission Denied (`.none` or calendar off)

When zero events match or calendar is denied, the events section is absent. Search + course list is the primary surface.

```
┌─────────────────────────────────────┐
│  Pick a course for this recording   │
│                                     │
│  [🔍 Search courses…           ]    │
│                                     │
│  Recent                             │
│  • CS101 Intro to CS                │
│  • MATH200 Calculus II              │
│                                     │
│  All Courses (Fall 2026)            │
│  • BIO150 Cellular Biology          │
│  • CS101 Intro to CS                │
│  • ENGL220 Shakespeare              │
│                                     │
│  [ + Create New Course ]            │
│  [   Skip (save to _unsorted)   ]   │
└─────────────────────────────────────┘
```

**Component spec:**

- **Sheet header** (`.headline`, primary): "Which lecture is this?" (multi-match) or "Pick a course for this recording" (no-match).
- **Events list** (multi-match only): `List` with `.plain` style, each row shows event title (`.subheadline`, primary) + time range and location (`.caption`, secondary). Tapping a row selects that event's course and dismisses the sheet.
- **Search field**: `TextField` with `.searchDictationBehavior` if available, placeholder "Search courses…". Filters both Recent and All Courses sections in real-time. Shows "No courses match '{query}'" inline if empty.
- **Recent section**: Shows up to 5 most-recently-used courses (current term only — MP-02). MRU ordering (CONTEXT discretion — MRU is simpler and likely correct). Header "Recent" in `.headline`, `.secondary`.
- **All Courses section**: Alphabetical list of all courses in the current term. Header "All Courses ({term label})" in `.headline`, `.secondary`.
- **Picker row**: single-line `.subheadline` course title + `.caption` course code. Selected row shows `checkmark` in accent color. Tap selects + dismisses sheet immediately (one-tap — no separate confirm button needed; the pick IS the confirmation).
- **Create New Course button** (`.buttonStyle(.bordered)`, secondary): `plus.circle` icon + "Create New Course". Opens inline mini-form with two `TextField`s: "Course Code" and "Course Name". Save creates the folder, adds to mapping, routes recording, dismisses sheet.
- **Skip button** (`.buttonStyle(.bordered)`, secondary, NOT destructive): "Skip (save to _unsorted)". Routes to `{vault}/{term}/_unsorted/` with `course: UNCLASSIFIED` frontmatter. No confirmation dialog — Skip is reversible (Angelica can move the file in Obsidian later).

#### Variant C: Create New Course Mini-Form

Inline form revealed when "Create New Course" is tapped. Replaces the course list section.

```
┌─────────────────────────────────────┐
│  Create New Course                  │
│                                     │
│  Course Code                        │
│  [ e.g., CS101                  ]   │
│                                     │
│  Course Name                        │
│  [ e.g., Intro to CS            ]   │
│                                     │
│  [ Discard ]    [ Create + Route ]  │
└─────────────────────────────────────┘
```

- **Course Code field**: `TextField`, placeholder "e.g., CS101". Required — Save button disabled when empty. Sanitized via `FolderNameSanitizer` on save.
- **Course Name field**: `TextField`, placeholder "e.g., Intro to CS". Optional (defaults to course code if empty).
- **Discard button** (secondary): "Discard New Course" — Returns to course picker list without creating anything.
- **Create + Route button** (`.buttonStyle(.borderedProminent)`, accent): Creates `{vault}/{term}/{sanitized-code}/` folder, adds mapping to `.unibrain/courses.json`, routes recording there, dismisses entire sheet. Disabled when Course Code is empty.

---

### Surface 2: Manage Courses Sheet (M-04)

Accessible from the idle-state popover via a "Manage Courses" button. Editable table of the course mapping.

```
┌─────────────────────────────────────┐
│  Manage Courses                     │
│                                     │
│  Current Term: Fall 2026            │
│  (Aug 25 – Dec 15, 2026)            │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ Event Title      → Course Code  ││
│  ├─────────────────────────────────┤│
│  │ CS101 Lecture    → CS101        ││
│  │ CS101 Lab        → CS101-Lab    ││
│  │ Calc II Lecture  → MATH200      ││
│  │ Ethics Seminar   → PHIL101      ││
│  └─────────────────────────────────┘│
│                                     │
│  Tap a row to edit. Swipe to delete.│
│                                     │
│  [ + Add Course Mapping ]           │
│  [   Done                       ]   │
└─────────────────────────────────────┘
```

**Component spec:**

- **Sheet header** (`.headline`, primary): "Manage Courses".
- **Current term display** (`.subheadline` primary + `.caption` secondary): Shows `currentTerm.label` + date range. Tappable → opens term editor inline (same mini-form pattern as Create New Course — label, start date, end date fields).
- **Mapping table**: `List` with `.insetGrouped` (or `.inset` on macOS) style. Each row: event title (`.subheadline`, primary) + arrow (`chevron.right`, `.tertiary`) + course code (`.subheadline`, `.secondary`). Tap row → inline edit mode with two `TextField`s (event title, course code).
- **Delete**: swipe-to-delete on macOS (or `-` button in edit mode). Confirmation alert: "Delete mapping for '{event title}'? Recordings with this event title will auto-create a new folder next time." with "Delete" (destructive) and "Keep Mapping" options.
- **Add Course Mapping button** (`.buttonStyle(.bordered)`, secondary): `plus.circle` icon. Opens inline form: Event Title field + Course Code field + Course Name field.
- **Done button** (`.buttonStyle(.borderedProminent)`, accent): Saves changes to `.unibrain/courses.json`, dismisses sheet.
- **Roughly 50-100 lines of SwiftUI** (M-04) — this is a minimal editor, not a full Settings UI. Becomes Phase 6's courses tab.

---

### Surface 3: Permission-Degradation UX (P-01, P-02)

#### First-Time Permission Explanation Sheet

Shown once (first recording where calendar Full Access is denied or only `.writeOnly` granted). Stored flag: `hasShownCalendarPermissionSheet` in `.unibrain/courses.json` or `@AppStorage`.

```
┌─────────────────────────────────────┐
│  Calendar Access Needed             │
│                                     │
│  unibrain uses your calendar to     │
│  automatically route recordings to  │
│  the right course folder.           │
│                                     │
│  Without calendar access, you'll    │
│  need to pick the course manually   │
│  each time you record.              │
│                                     │
│  [ Open System Settings ]           │
│  [ Continue with Manual Pick    ]   │
└─────────────────────────────────────┘
```

**Component spec:**

- **Sheet header** (`.headline`, primary): "Calendar Access Needed".
- **Body** (`.body`, secondary): Two paragraphs explaining (a) what calendar enables (automatic routing), (b) what happens without it (manual pick each time). No guilt-trip language — neutral, factual.
- **Open System Settings button** (`.buttonStyle(.borderedProminent)`, accent): `gear` icon. Opens macOS System Settings via `NSWorkspace.open(URL)` with `x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars` deep-link (CONTEXT discretion item).
- **Continue with Manual Pick button** (`.buttonStyle(.bordered)`, secondary): Dismisses sheet. The manual picker (Surface 1) appears immediately for this recording.

#### Ongoing Permission-Denied Banner

Compact banner shown in the popover on subsequent recordings when calendar is still denied.

```
┌─────────────────────────────────────┐
│  ⚠ Calendar off — manual pick       │
│  required. Tap to enable.           │
└─────────────────────────────────────┘
```

- **Placement**: Top of popover, between menu-bar icon area and the main recording UI. Non-blocking — recording still works.
- **Style**: `.rect(cornerRadius: 8)` fill with `.orange.opacity(0.15)` background tint. Warning icon (`exclamationmark.triangle.fill`, `.orange`) + two-line text.
- **Tap action**: Opens macOS System Settings deep-link (same URL as first-time sheet). Does NOT re-show the first-time sheet — just the deep-link.
- **Dismissal**: Auto-dismisses when calendar permission is granted (detected on next app activation via `EKEventStore` notification or `NSApplication.didBecomeActiveNotification`).

---

### Surface 4: Term-Expired Banner (CT-03)

Non-blocking banner shown when `today > currentTerm.endDate`.

```
┌─────────────────────────────────────┐
│  Fall 2026 ended — set your new     │
│  term?              [ Set Term ]    │
└─────────────────────────────────────┘
```

- **Placement**: Top of popover (same slot as permission banner — they are mutually exclusive; permission banner takes priority if both conditions are true).
- **Style**: `.rect(cornerRadius: 8)` fill with `.orange.opacity(0.15)` background tint. Same visual language as permission banner.
- **Set Term button** (`.buttonStyle(.bordered)`, accent, compact): Opens inline term editor (label + start date + end date fields, same mini-form pattern as Manage Courses term editing).
- **Non-blocking**: Recordings still work — they fall through to the manual picker if EventKit returns zero events in the expired term's range.
- **Dismissal**: Auto-dismisses when a new current term is set with `endDate >= today`.

---

## Popover State Extensions (Phase 4 additions to Phase 3 states)

Phase 4 extends `SessionDisplayState` with a new case for the classification pause:

```swift
// New case added to SessionDisplayState
case awaitingCourseSelection
```

This maps to the orchestrator's new `.awaitingUserChoice` state (MP-04). The popover renders the classification-paused layout:

```
┌─────────────────────────────────────┐
│  Transcription done.                │
│  Picking course…                    │
│                                     │
│  ◌ Analyzing calendar…              │
│                                     │
│  [ Cancel (save to _unsorted) ]     │
└─────────────────────────────────────┘
```

- **Status line** (`.headline`, primary): "Transcription done." + `.subheadline` "Picking course…"
- **Progress indicator**: `ProgressView` (indeterminate) with `.caption` "Analyzing calendar…". This state is typically brief (<1s for `.single`/`.none`; the picker sheet appears for `.multiple`/`.none`).
- **Cancel button** (secondary): "Cancel (save to _unsorted)". Routes to `_unsorted/` with `UNCLASSIFIED` frontmatter — escape hatch if Angelica doesn't want to pick.
- **Transition to picker**: When `CourseClassifier` returns `.multiple` or `.none`, the picker sheet (Surface 1) presents over this state. When `.single`, the orchestrator auto-resolves and skips to `.normalizing` → `.writing` → `.completed` (Phase 3 flow).

### Idle State Extension (Phase 4 additions)

Phase 3's idle state gains a secondary button:

```
┌─────────────────────────────────────┐
│  Ready to record                    │
│  • small.en model downloaded ✓      │
│  • Microphone available ✓           │
│  • Calendar connected ✓             │
│                                     │
│         ┌───────────────┐           │
│         │     Record     │           │
│         └───────────────┘           │
│                                     │
│  Term: Fall 2026                    │
│  [ Manage Courses ]                 │
└─────────────────────────────────────┘
```

- **Calendar status line** (new): `checkmark.circle.fill` (`.green`) + "Calendar connected" when Full Access granted. `exclamationmark.circle` (`.orange`) + "Calendar off — manual pick" when denied. Absent if permission not yet requested.
- **Term label** (`.caption`, `.secondary`): "Term: {currentTerm.label}". Tappable → opens term editor inline. If term expired, shows the term-expired banner (Surface 4) instead.
- **Manage Courses button** (`.buttonStyle(.bordered)`, secondary, `.controlSize(.small)`): `folder.badge.gearshape` icon + "Manage Courses". Opens Surface 2. Small/secondary — Record is still the dominant CTA.

---

## Copywriting Contract

Inherits Phase 3 tone: calm, brief, no exclamation marks. Angelica is in a lecture — she needs information, not personality.

| Element | Copy |
|---------|------|
| **Course Picker — multi-match heading** | "Which lecture is this?" |
| **Course Picker — no-match heading** | "Pick a course for this recording" |
| **Course Picker — events section label** | "Matching calendar events:" |
| **Course Picker — events section divider** | "Or pick from all courses" |
| **Course Picker — search placeholder** | "Search courses…" |
| **Course Picker — search empty** | "No courses match '{query}'" |
| **Course Picker — recent section header** | "Recent" |
| **Course Picker — all courses section header** | "All Courses ({term label})" |
| **Course Picker — Create New button** | "Create New Course" |
| **Course Picker — Skip button** | "Skip (save to _unsorted)" |
| **Create New Course — code field placeholder** | "e.g., CS101" |
| **Create New Course — name field placeholder** | "e.g., Intro to CS" |
| **Create New Course — save button** | "Create + Route" |
| **Create New Course — discard button** | "Discard New Course" |
| **Manage Courses — heading** | "Manage Courses" |
| **Manage Courses — term display** | "Current Term: {label}" / "({startDate} – {endDate})" |
| **Manage Courses — add mapping button** | "Add Course Mapping" |
| **Manage Courses — done button** | "Done" |
| **Manage Courses — delete confirmation** | "Delete mapping for '{event title}'? Recordings with this event title will auto-create a new folder next time." |
| **Manage Courses — delete confirm action** | "Delete" |
| **Manage Courses — delete cancel action** | "Keep Mapping" |
| **Permission sheet — heading** | "Calendar Access Needed" |
| **Permission sheet — body paragraph 1** | "unibrain uses your calendar to automatically route recordings to the right course folder." |
| **Permission sheet — body paragraph 2** | "Without calendar access, you'll need to pick the course manually each time you record." |
| **Permission sheet — enable button** | "Open System Settings" |
| **Permission sheet — dismiss button** | "Continue with Manual Pick" |
| **Permission banner — text** | "Calendar off — manual pick required. Tap to enable." |
| **Term-expired banner — text** | "{term label} ended — set your new term?" |
| **Term-expired banner — button** | "Set Term" |
| **Term editor — heading** | "Set Current Term" |
| **Term editor — label field placeholder** | "e.g., Fall 2026" |
| **Term editor — start date label** | "Start Date" |
| **Term editor — end date label** | "End Date" |
| **Term editor — save button** | "Set Current Term" |
| **Classification-paused — status line** | "Transcription done." / "Picking course…" |
| **Classification-paused — progress caption** | "Analyzing calendar…" |
| **Classification-paused — cancel** | "Cancel (save to _unsorted)" |
| **Idle — calendar connected** | "Calendar connected" |
| **Idle — calendar off** | "Calendar off — manual pick" |
| **Idle — term label** | "Term: {label}" |
| **Idle — manage courses button** | "Manage Courses" |
| **Auto-routed notification title** | "Lecture routed to {course code}" |
| **Auto-routed notification body** | "Opened in vault" |
| **Manual-pick notification title** | "Lecture routed to {course code}" |
| **Manual-pick notification body** | "Opened in vault" (same — the user doesn't need to know it was manual) |

**Notification behavior:** Phase 3's completion notification ("Lecture transcript ready — Opened in vault") is extended to include the course code in the title. Both auto-routed and manually-picked recordings show the same notification — Angelica doesn't need to know the routing method, just where it landed.

**Pronouns:** always "your" (calendar, course, term), never "the" — reinforces ownership in a single-user app.

---

## Interaction Contracts

### Classification Flow (state machine extension)

Phase 3's recording lifecycle is extended with a classification pause:

```
recording ──[Stop]──→ transcribing ──[done]──→ classifying ──[.single]──→ normalizing ──→ writing ──→ completed
                                                          │
                                                          ├──[.multiple]──→ awaitingCourseSelection ──[pick]──→ normalizing
                                                          │                        │
                                                          │                        ├──[Skip]──→ normalizing (course=UNCLASSIFIED)
                                                          │                        │
                                                          │                        └──[Cancel]──→ normalizing (course=UNCLASSIFIED)
                                                          │
                                                          └──[.none]──→ awaitingCourseSelection (same flow as .multiple)
```

- **`.single` match:** orchestrator auto-resolves using the mapped course code. No UI interruption. Transitions directly to `.normalizing`.
- **`.multiple` match:** orchestrator pauses at `.awaitingUserChoice`. Picker sheet (Surface 1, Variant A) presents. Angelica taps an event or course → orchestrator resumes with `.normalizing`.
- **`.none` match:** orchestrator pauses at `.awaitingUserChoice`. Picker sheet (Surface 1, Variant B) presents. Same resume flow.
- **Skip/Cancel:** both route to `.normalizing` with `course: UNCLASSIFIED`, `course_name: "Unsorted"`, `term: {current}`. Note written to `{vault}/{term}/_unsorted/`.

### Manual Pick → Remembered Override (CLAS-07, M-03)

When Angelica picks a course manually:
1. The event title → course_code mapping is written to `.unibrain/courses.json` (permanent — next recording with the same event title auto-routes).
2. The picked course is added to the "recent" list (floats to top of next picker).
3. If there was no calendar event (`.none` case), only the recent list is updated — no event-title mapping to write.

### Permission Request Timing (P-02)

- **First recording:** When Angelica taps Record for the first time, the app requests microphone AND calendar access together (mic inherits Phase 3 path). System permission dialogs appear sequentially (mic first, then calendar).
- **Calendar denied:** First-time sheet (Surface 3) appears on the first recording where calendar is denied. Subsequent recordings show the ongoing banner.
- **Calendar granted later:** If Angelica grants via System Settings, the app detects it on next activation (`NSApplication.didBecomeActiveNotification` or equivalent) and the banner/sheet dismisses. No app restart needed.

### Term-Expired Detection (CT-03)

- **Check timing:** On app launch and on each recording start.
- **Condition:** `Date() > currentTerm.endDate`.
- **Action:** Show term-expired banner (Surface 4) in popover. Non-blocking — recordings proceed.
- **Resolution:** Angelica sets a new term via the banner's "Set Term" button or Manage Courses → term editor. Banner dismisses on save.

### Manage Courses Access

- **From idle state:** "Manage Courses" button in the popover (new in Phase 4).
- **Not accessible during recording/transcribing/classifying:** button is hidden or disabled in non-idle states (Angelica is mid-recording — she doesn't need course management then).
- **Saves immediately:** changes to `.unibrain/courses.json` write on "Done" tap. No autosave per-field (minimizes file I/O on 8GB).

---

## Accessibility

Inherits Phase 3 accessibility patterns. Phase 4 additions:

- **Picker row labels:** each course row has `.accessibilityLabel("{course_name}, {course_code}")` and `.accessibilityHint("Selects this course for the current recording")`.
- **Event row labels (multi-match):** `.accessibilityLabel("{event_title}, {start_time} to {end_time}, {location or 'no location'}")`.
- **Banner accessibility:** permission-denied and term-expired banners have `.accessibilityAddTraits(.isHeader)` so VoiceOver announces them on popover open.
- **Search field:** `.accessibilityLabel("Search courses")`, `.accessibilityHint("Type to filter the course list")`.
- **Manage Courses table:** standard `List` accessibility — swipe-to-delete announced as "Delete, {event title} mapping".
- **Color independence:** banner warning state uses icon (`exclamationmark.triangle.fill`) + text, not orange color alone. Selected picker row uses `checkmark` icon, not color alone.
- **Dynamic Type:** all Phase 4 surfaces respect Dynamic Type. Picker rows truncate with `.lineLimit(1)` + `.truncationMode(.tail)` at largest sizes to preserve 280pt width.

---

## Component Inventory (for planner)

New SwiftUI views/components Phase 4 introduces (planner allocates these as tasks):

| Component | File (suggested) | Lines (est.) | Source |
|-----------|-------------------|--------------|--------|
| `CoursePickerSheet` | `UnibrainApp/Views/CoursePickerSheet.swift` | 120-150 | MP-01..05 |
| `CoursePickerRow` | `UnibrainApp/Views/CoursePickerRow.swift` | 30-40 | MP-02 |
| `CreateCourseForm` | `UnibrainApp/Views/CreateCourseForm.swift` | 40-50 | MP-03 |
| `ManageCoursesSheet` | `UnibrainApp/Views/ManageCoursesSheet.swift` | 60-80 | M-04 |
| `PermissionDeniedSheet` | `UnibrainApp/Views/PermissionDeniedSheet.swift` | 40-50 | P-01 |
| `PermissionBanner` | `UnibrainApp/Views/PermissionBanner.swift` | 25-35 | P-01 |
| `TermExpiredBanner` | `UnibrainApp/Views/TermExpiredBanner.swift` | 25-35 | CT-03 |
| `TermEditorForm` | `UnibrainApp/Views/TermEditorForm.swift` | 40-50 | CT-01, CT-03 |
| `ClassificationPausedView` | `UnibrainApp/Views/ClassificationPausedView.swift` | 30-40 | MP-04 |
| `SessionDisplayState` extension | `UnibrainApp/ViewModels/MenuBarViewModel.swift` | +10 | MP-04 |
| `MenuBarPopover` idle extension | `UnibrainApp/MenuBarPopover.swift` | +20 | idle Manage Courses button + calendar status |

**Estimated total new SwiftUI:** ~400-550 lines across ~9 new view files + ~30 lines of extensions to existing files. Within M-04's "~50-100 lines" estimate for Manage Courses alone; total Phase 4 UI is larger because it includes the picker, permission UX, and banners.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| SwiftUI (system) | `.sheet`, `List`, `Section`, `TextField`, `Button`, `Label`, `Alert`, `DatePicker`, `Canvas` | not required (Apple framework — no third-party audit needed) |
| Third-party SPM | (none in Phase 4 UI layer) | not applicable |

**No web registry components used.** This is a native SwiftUI app — shadcn/ui, Radix, base-ui are not applicable. Registry safety checks pass vacuously.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS — all surfaces have explicit copy, no lorem, tone inherited from Phase 3
- [ ] Dimension 2 Visuals: PASS — every surface has ASCII mock + component spec + interaction contract
- [ ] Dimension 3 Color: PASS — semantic system colors, accent/warning/destructive reserved explicitly
- [ ] Dimension 4 Typography: PASS — SF Pro semantic styles, no new roles beyond Phase 3 inheritance
- [ ] Dimension 5 Spacing: PASS — 4pt-multiple scale inherited from Phase 3, 280pt popover/sheet width
- [ ] Dimension 6 Registry Safety: PASS — native SwiftUI only, no web registry applicable

**Approval:** pending

---

*Phase: 4 — Course Classification + Smart Routing*
*UI-SPEC generated: 2026-07-15*
*Sources: 04-CONTEXT.md (M-01..M-04, P-01..P-05, MP-01..MP-05, CT-01..CT-04) + 03-UI-SPEC.md (inherited design tokens) + Apple HIG for MenuBarExtra/sheet/List patterns*
