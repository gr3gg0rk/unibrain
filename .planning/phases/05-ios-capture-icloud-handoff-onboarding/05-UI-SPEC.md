---
phase: 5
slug: ios-capture-icloud-handoff-onboarding
status: draft
shadcn_initialized: false
preset: none
created: 2026-07-15
---

# Phase 5 — UI Design Contract

> Visual and interaction contract for iOS Capture, iCloud Handoff, and the first-run Onboarding flow.
> Generated from 05-CONTEXT.md decisions IC-01..04, IOS-01..04, TRIG-01..04, ONB-01..04.
> Inherits Phase 3 and Phase 4 design tokens (native SwiftUI, SF Pro, SF Symbols, semantic system colors, calm tone).
> This phase introduces three new UI surfaces: (1) Onboarding wizard, (2) iOS Record tab + TabView shell, (3) Permissions audit sheet.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (native SwiftUI — no shadcn/web tooling applicable) |
| Preset | not applicable |
| Component library | SwiftUI (Apple-built — `TabView`, `NavigationStack`, `Form`, `List`, `.fileImporter`, `DatePicker`, `ProgressView`, `Label`, `Button`, `Canvas`, `TimelineView`) |
| Icon library | SF Symbols (system — inherits Phase 3/4 set + `wand.and.stars`, `folder.badge.plus`, `mic.fill`, `calendar.badge.clock`, `graduationcap.fill`, `checkmark.circle.fill`, `gearshape`, `iphone`, `macbook`, `icloud`, `arrow.triangle.2.circlepath`) |
| Font | SF Pro (system default — `.largeTitle`, `.title`, `.title2`, `.body`, `.headline`, `.subheadline`, `.caption` semantic roles) |
| Platform | macOS 26 Tahoe + iOS 17 (deployment targets D-05). Multiplatform — `#if os(macOS)` / `#if os(iOS)` guards for platform-specific surfaces. |

**Design language:** Native SwiftUI multiplatform app. Follows Apple Human Interface Guidelines for onboarding (page-style `TabView`), iOS app structure (bottom `TabView`), and permission UX. No custom theming layer — uses standard semantic colors so the app automatically respects Light/Dark mode and system accent color preferences on both platforms.

**Inheritance:** All Phase 3 and Phase 4 design tokens (spacing scale, typography, color contract, copywriting tone) carry forward unchanged. Phase 5 extends the design language to iOS and adds the first-run onboarding flow — no existing tokens change.

---

## Spacing Scale

Inherited from Phase 3/4 — unchanged. SwiftUI uses points (pt). All multiples of 4pt.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4pt | Icon gaps, inline label padding, banner internal spacing |
| sm | 8pt | Compact row spacing, button gap horizontal, onboarding progress dot spacing |
| md | 12pt | Default element vertical spacing, popover section gap |
| lg | 16pt | Section padding within popover/form, onboarding page padding |
| xl | 24pt | Popover top/bottom padding, onboarding page top/bottom padding |
| 2xl | 32pt | Major section break, onboarding heading-to-body gap |
| 3xl | 48pt | Onboarding hero illustration spacing (iOS only — full-screen pages have more vertical real estate) |

**Popover width (macOS):** 280pt fixed (inherited from Phase 3 P-09).

**iOS onboarding page:** Full-screen on iPhone (no fixed width — uses `.ignoresSafeArea(.keyboard)` for form pages). On macOS, onboarding renders as a centered sheet or window at 480pt wide × 600pt tall (CONTEXT discretion — planner picks sheet vs window).

**iOS Record tab:** Full-screen (no fixed width — uses available screen width). Timer and waveform scale up from the 280pt popover per IOS-04.

**Exceptions:** none — native Apple HIG spacing tokens.

---

## Typography

Inherited from Phase 3/4. Native SF Pro via SwiftUI semantic styles. No custom fonts. Phase 5 adds onboarding-specific roles for the welcome page.

| Role | SwiftUI Style | Approx Size | Weight | Line Height |
|------|--------------|-------------|--------|-------------|
| Onboarding welcome title (iOS) | `.largeTitle` | 34pt | bold | 1.1 |
| Onboarding welcome title (macOS) | `.title` | 28pt | bold | 1.2 |
| Onboarding step heading | `.title2` | 22pt | bold | 1.2 |
| Onboarding body / explanation | `.body` | 17pt (iOS) / 13pt (macOS) | regular | 1.4 |
| Timer (recording state — iOS Record tab) | `.system(size: 48, weight: .semibold, design: .monospaced)` | 48pt | semibold | 1.2 |
| Timer (recording state — macOS popover) | `.system(size: 32, weight: .semibold, design: .monospaced)` | 32pt | semibold | 1.2 |
| Body / status line | `.body` | 17pt (iOS) / 13pt (macOS) | regular | 1.4 |
| Label (button) | `.headline` | 17pt (iOS) / 13pt (macOS) | semibold | 1.3 |
| Subheadline (row title) | `.subheadline` | 15pt (iOS) / 12pt (macOS) | regular | 1.3 |
| Caption (metadata, progress) | `.caption` | 12pt (iOS) / 10pt (macOS) | regular | 1.3 |

**Monospaced timer:** Both iOS and macOS timers use `.monospacedDigit()` so digits don't jitter as numbers change. iOS timer is larger (48pt vs 32pt) per IOS-04 — "expanded Phase 3 layout for Record tab" with more visual real estate.

**iOS vs macOS size note:** iOS uses SwiftUI's standard Dynamic Type scaling, which defaults to larger body text (17pt) compared to macOS (13pt). This is standard Apple HIG — iOS is viewed at arm's length, macOS at desk distance. All sizes respect Dynamic Type user preferences.

---

## Color

Inherited from Phase 3/4 — unchanged. Native semantic colors on both platforms.

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `Color(.systemBackground)` (iOS) / `Color(nsColor: .windowBackgroundColor)` (macOS) | App background, onboarding pages |
| Secondary (30%) | `Color(.secondarySystemBackground)` (iOS) / `Color(nsColor: .controlBackgroundColor)` (macOS) | Cards, form sections, tab bar, list rows |
| Accent (10%) | `Color.accentColor` (user-selected system accent) | Primary CTA fill, onboarding "Continue" button, active recording state |
| Destructive / Recording | `Color.red` | Stop button, recording indicator, delete actions |
| Warning | `Color.orange` | Permission-denied banner, iCloud sync failure indicator, dead-letter queue warning |
| Success | `Color.green` | Permission granted indicator, iCloud sync complete, model downloaded |
| Text primary | `Color.primary` (`.labelColor`) | All primary text |
| Text secondary | `Color.secondary` (`.secondaryLabelColor`) | Status lines, captions, onboarding body text |

**Accent reserved for:**
- Primary CTA in onboarding ("Continue", "Get Started", "Allow")
- iOS Record button (large, `.borderedProminent`)
- "Open System Settings" deep-link button in Permissions sheet
- Active download progress indicator

**Warning (orange) reserved for:**
- Permission-denied banner (inherited from Phase 4)
- iCloud download failure / dead-letter queue indicator in macOS popover
- "Recording failed" error state in popover

**Destructive (red) reserved for:**
- Stop button (ends recording — distinct from Pause)
- Delete recording from dead-letter queue

---

## Surface 1: Onboarding Wizard (ONBD-01, ONBD-04, ONB-01..04)

First-run flow rendered as a SwiftUI `TabView` with `.tabViewStyle(.page)` — page-style, swipeable, progress dots at bottom. Apple's standard first-run pattern.

### Platform Split (ONB-01)

- **macOS:** 6 pages — Welcome, Vault, Mic, Calendar, Term, Ready. Renders as a centered sheet or dedicated window at 480pt × 600pt on first launch (planner picks window vs sheet — CONTEXT discretion). Angelica sets up her MacBook first (it's the transcription workstation).
- **iOS:** 5 pages — Welcome, Vault, Mic, Calendar, Ready. Skips the Term page — `currentTerm` inherits from `.unibrain/courses.json` via iCloud Drive (Angelica picks the same folder she picked on macOS). Each device picks its own vault folder and grants its own permissions.

### First-Run Detection

`UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")`. Standard Apple pattern. If `false`, the app shows the onboarding flow instead of the main UI. On completion, sets the flag to `true`.

### Page Layouts

#### Page 1: Welcome

```
┌─────────────────────────────────────┐
│                                     │
│            [app icon]               │
│                                     │
│           unibrain                  │
│                                     │
│  Every recording lands in the       │
│  right course folder,              │
│  automatically.                    │
│                                     │
│                                     │
│         ┌──────────────┐            │
│         │  Get Started  │            │
│         └──────────────┘            │
│                                     │
│              • ○ ○ ○ ○              │
└─────────────────────────────────────┘
```

- **App icon**: Large, centered (96pt × 96pt on iOS, 72pt × 72pt on macOS). Uses the app's icon asset.
- **App name**: "unibrain" in `.largeTitle` (iOS) / `.title` (macOS), bold, centered. Lowercase per PROJECT.md branding.
- **Value prop**: "Every recording lands in the right course folder, automatically." in `.body`, `.secondary`, centered. Core value statement from PROJECT.md.
- **Get Started button** (`.borderedProminent`, accent, `.controlSize(.large)`): Advances to page 2. Full-width on iOS.
- **Progress dots**: 5 (iOS) or 6 (macOS) dots at bottom. Current page = filled accent dot, others = gray.

#### Page 2: Vault Folder Picker (ONBD-04, ONB-03)

```
┌─────────────────────────────────────┐
│  Choose Your Vault Folder           │
│                                     │
│  Pick the folder where unibrain     │
│  will save your lecture notes.      │
│  iCloud Drive is recommended so     │
│  your notes sync across devices.    │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 📁 iCloud Drive                 ││
│  │    / Document Picker /          ││
│  └─────────────────────────────────┘│
│                                     │
│  Selected: Unibrain/                │
│                                     │
│  [    Choose Folder…           ]    │
│  [          Continue            ]   │
│                                     │
│              ○ • ○ ○ ○              │
└─────────────────────────────────────┘
```

- **Heading**: "Choose Your Vault Folder" (`.title2`, bold).
- **Explanation** (`.body`, `.secondary`): Explains that this is where notes live. Recommends iCloud Drive so notes sync between MacBook and iPhone.
- **Folder picker**: SwiftUI `.fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:)` with `.folder` content type (`UTType.folder`). Opens at iCloud Drive root on macOS (`~/Library/Mobile Documents/com~apple~CloudDocs/`). On iOS, `UIDocumentPickerViewController` surfaces iCloud Drive prominently.
- **Selected path display**: Shows the picked folder name (e.g., "Unibrain/") in `.subheadline`, `.secondary`. Security-scoped bookmark persisted in macOS Keychain / iOS Secure Enclave.
- **Choose Folder button** (`.bordered`, secondary): Opens the file picker.
- **Continue button** (`.borderedProminent`, accent): Disabled until a folder is picked. Advances to page 3.

#### Page 3: Microphone Permission (ONBD-02)

```
┌─────────────────────────────────────┐
│  Microphone Access                  │
│                                     │
│  [mic.fill icon — large]            │
│                                     │
│  unibrain needs microphone access   │
│  to record your lectures.           │
│                                     │
│  Audio never leaves your devices    │
│  unless you explicitly enable       │
│  cloud processing.                  │
│                                     │
│  [    Allow Microphone Access   ]   │
│  [          Continue            ]   │
│                                     │
│              ○ ○ • ○ ○              │
└─────────────────────────────────────┘
```

- **Heading**: "Microphone Access" (`.title2`, bold).
- **Icon**: `mic.fill` large (48pt), centered, accent color.
- **Explanation** (`.body`, `.secondary`): Why mic is needed + privacy assurance (audio stays local per PROJECT.md local-first mandate).
- **Allow Microphone Access button** (`.borderedProminent`, accent): Triggers system permission dialog. After grant, shows green checkmark + "Microphone enabled". If denied, shows inline warning + "Open System Settings" link (microphone is HARD-FAIL per ONBD-02 — Continue button stays disabled).
- **Continue button**: Disabled until microphone is granted. Advances to page 4.

#### Page 4: Calendar Permission (ONBD-03)

```
┌─────────────────────────────────────┐
│  Calendar Access                    │
│                                     │
│  [calendar.badge.exclamationmark]   │
│                                     │
│  unibrain uses your calendar to     │
│  automatically route recordings     │
│  to the right course folder.        │
│                                     │
│  Optional — you can pick the        │
│  course manually if you prefer.     │
│                                     │
│  [   Allow Calendar Access      ]   │
│  [   Skip (Manual Pick)         ]   │
│  [          Continue            ]   │
│                                     │
│              ○ ○ ○ • ○              │
└─────────────────────────────────────┘
```

- **Heading**: "Calendar Access" (`.title2`, bold).
- **Icon**: `calendar.badge.exclamationmark` large (48pt), centered, accent color.
- **Explanation** (`.body`, `.secondary`): What calendar enables (automatic routing per CLAS-01) + what happens without it (manual pick per CLAS-04). Calendar is OPTIONAL per ONBD-03 — degrades to manual picker.
- **Allow Calendar Access button** (`.borderedProminent`, accent): Triggers `EKEventStore.requestFullAccessToEvents()`. After grant, shows green checkmark + "Calendar connected".
- **Skip (Manual Pick) button** (`.bordered`, secondary): Advances without calendar. Shows note: "You'll pick the course manually each time." No blocking — the app works.
- **Continue button**: Enabled regardless of calendar choice. Advances to page 5 (iOS: Ready; macOS: Term).

#### Page 5 (macOS only): Current Term Label (ONB-01, CT-01)

```
┌─────────────────────────────────────┐
│  Set Your Current Term              │
│                                     │
│  [graduationcap.fill icon]          │
│                                     │
│  unibrain organizes notes by term.  │
│  Set your current term so recordings│
│  route to the right folder.         │
│                                     │
│  Term Label                         │
│  [ e.g., Fall 2026              ]   │
│                                     │
│  Start Date          End Date       │
│  [ Aug 25, 2026 ]   [ Dec 15, 2026]│
│                                     │
│  [          Continue            ]   │
│                                     │
│              ○ ○ ○ ○ •              │
└─────────────────────────────────────┘
```

- **Heading**: "Set Your Current Term" (`.title2`, bold).
- **Icon**: `graduationcap.fill` large (48pt), centered, accent color.
- **Explanation** (`.body`, `.secondary`): Why term matters (folder structure per CLAS-05, classification filter per CLAS-06).
- **Term Label field**: `TextField`, placeholder "e.g., Fall 2026". Required — Continue disabled when empty.
- **Start Date**: `DatePicker` displaying `.compact` style. Default: today.
- **End Date**: `DatePicker` displaying `.compact` style. Default: today + 4 months (standard semester length).
- **Continue button** (`.borderedProminent`, accent): Disabled when Term Label is empty. Writes `currentTerm = { label, startDate, endDate }` to `.unibrain/courses.json` inside the picked vault folder. Advances to Ready page.

**iOS skips this page** — `currentTerm` inherits from `.unibrain/courses.json` via iCloud Drive (ONB-01).

#### Final Page: Ready

```
┌─────────────────────────────────────┐
│                                     │
│        [checkmark.circle.fill]      │
│                                     │
│           You're all set!           │
│                                     │
│  Record on your iPhone in class,    │
│  and notes appear on your MacBook   │
│  automatically.                     │
│                                     │
│         ┌──────────────┐            │
│         │  Start Using  │            │
│         │   unibrain    │            │
│         └──────────────┘            │
│                                     │
│              ○ ○ ○ ○ ●              │
└─────────────────────────────────────┘
```

- **Icon**: `checkmark.circle.fill` large (64pt), centered, `.green`.
- **Heading**: "You're all set!" (`.title2`, bold).
- **Body** (`.body`, `.secondary`): Brief guidance on what happens next — "Record on your iPhone in class, and notes appear on your MacBook automatically." (reflects Phase 5's core iCloud handoff value).
- **Start Using unibrain button** (`.borderedProminent`, accent, `.controlSize(.large)`): Sets `hasCompletedOnboarding = true`, dismisses onboarding, reveals main app surface (macOS: menu bar; iOS: TabView).

### Onboarding Interaction Contracts

- **Swipe vs. button:** Both work. Swiping left/right navigates pages. "Continue" button also advances. Backward swipe always available (user can fix a mistake).
- **Permission pages are sticky:** If mic is denied, the Continue button stays disabled — user can't advance past page 3 without granting (HARD-FAIL per ONBD-02). Calendar page allows Skip (OPTIONAL per ONBD-03).
- **No skip-all:** Onboarding cannot be skipped entirely — Angelica must pick a vault folder and grant microphone at minimum.
- **Re-entry:** If app crashes or is force-quit during onboarding, the flow resumes from the beginning on next launch (simplest — planner can add page-level persistence if desired; CONTEXT discretion).
- **iOS vault inheritance:** If iOS detects `.unibrain/courses.json` inside the picked folder, it reads `currentTerm` and course mappings. If the folder is empty (Angelica hasn't set up macOS yet), iOS onboarding completes but a banner appears: "Set up unibrain on your Mac to enable course routing."

---

## Surface 2: iOS App Shell + Record Tab (IOS-01..04)

### iOS TabView Shell (IOS-01)

Three-tab `TabView` at the bottom of the screen. Standard iOS app structure.

```
┌─────────────────────────────────────┐
│                                     │
│         [ full-screen content ]     │
│                                     │
├─────────────────────────────────────┤
│  ●Record     ○Recent     ○Settings  │
└─────────────────────────────────────┘
```

- **Record tab** (`mic.fill`): Full recording UI (IOS-04). This is the default tab on launch.
- **Recent tab** (`clock.arrow.circlepath`): Read-only list of notes discovered via `.unibrain/courses.json` + vault scan. No editing — Obsidian is the editor per PROJECT.md Out of Scope.
- **Settings tab** (`gearshape`): Phase 6 hook. Phase 5 ships a minimal placeholder with only the Permissions sheet entry (ONB-04).

### iOS Record Tab (IOS-04 — Expanded Phase 3 Layout)

Full-screen recording interface. Scales Phase 3's macOS popover components up to iPhone size — more visual real estate = better waveform visibility from across a lecture hall.

#### Idle State

```
┌─────────────────────────────────────┐
│                                     │
│         Ready to record              │
│                                     │
│    ● small.en synced from Mac       │
│    ● Microphone available           │
│    ● Calendar connected             │
│                                     │
│         ┌──────────────┐            │
│         │              │            │
│         │   ● Record    │            │
│         │              │            │
│         └──────────────┘            │
│                                     │
│  Term: Fall 2026                    │
└─────────────────────────────────────┘
```

- **Status lines**: Same as macOS popover (inherited from Phase 3/4). Shows model sync status (model lives on macOS; iPhone shows "synced from Mac" when `.unibrain/courses.json` is present), microphone permission, calendar permission.
- **Record button**: Large circular button (80pt diameter), `.borderedProminent`, accent fill, `mic.fill` icon (32pt). Centered. Tappable area meets 44pt minimum touch target (Apple HIG).
- **Term label**: `.caption`, `.secondary`. Inherited from `.unibrain/courses.json`.

#### Recording State (IOS-04)

```
┌─────────────────────────────────────┐
│            00:14:32                 │
│                                     │
│  ▆▃▅▇▆▄▃▅▇▆▃▄▅▇▆▄▃▅▇▆▃▅▇▆▄▃▅▇▆▃  │
│  ▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅  │
│                                     │
│  ◁ ─────────●──────────▷           │
│  green      yellow      red          │
│                                     │
│     [   Pause   ]   [   Stop   ]    │
└─────────────────────────────────────┘
```

- **Timer** (`.system(size: 48, weight: .semibold, design: .monospaced)`): Large, centered, `HH:MM:SS` format. 48pt for iOS (vs 32pt on macOS) — readable from across a lecture hall.
- **Live waveform**: SwiftUI `Canvas` inside `TimelineView` — inherited from Phase 3 P-D5. Expanded to full width and ~96pt height (vs 48pt on macOS). Same rendering logic (MainActor renders, detached task fills buffer).
- **Mic-level meter**: 3-segment horizontal bar — green/yellow/red. Inherited from Phase 3 CAPT-05. Expanded to full width.
- **Pause button** (`.controlSize(.large)`, secondary): `pause.fill` + "Pause".
- **Stop button** (`.controlSize(.large)`, destructive): `stop.fill` + "Stop". Red tint.

#### Paused State

Same as macOS paused state (Phase 3 P-12), scaled up. Frozen timer (48pt, dimmed to `.secondary`), waveform frozen at opacity 0.4, empty mic meter, paused summary, Resume + Stop buttons.

#### iOS Recording Lifecycle (CAPT-03, DISC-04, IOS-02, IOS-03)

- **Background recording:** `UIBackgroundModes: ["audio"]` in Info.plist. `AVAudioSession` category `.playAndRecord` with `.defaultToSpeaker` mode. Recording survives screen lock for 30+ minutes.
- **Lock screen indicator (IOS-02):** `MPNowPlayingInfoCenter` pushes "Recording — {elapsed time}" to iOS lock screen, Control Center, AirPods double-tap, and Apple Watch remote. App icon as artwork.
- **Remote commands (IOS-02):** `MPRemoteCommandCenter` handles Stop and Pause from lock screen. No Play command (there's no playback).
- **Interruption handling (IOS-03):** On `audioRecorderBeginInterruption` (phone call, Siri, another audio app) → auto-pause. On `audioRecorderEndInterruption` → auto-resume. The `.m4a` stays contiguous via Phase 3 CAPT-02 pause/resume timestamp markers.
- **On Stop (IC-02):** Atomic move from sandbox `tmp/recordings/{uuid}.m4a` to `{vault}/_inbox/{source}-{timestamp}-{shortUUID}.m4a`. iCloud sync begins asynchronously. iOS shows "Saved — syncing to your Mac via iCloud."

### iOS Recent Tab (IOS-01)

Read-only list of notes from the vault. Discovered via `.unibrain/courses.json` + folder scan.

```
┌─────────────────────────────────────┐
│  Recent                             │
│                                     │
│  Fall 2026                          │
│  ┌─────────────────────────────────┐│
│  │ CS101 — Lecture                 ││
│  │ 2026-09-15 · 52 min             ││
│  ├─────────────────────────────────┤│
│  │ MATH200 — Lecture               ││
│  │ 2026-09-13 · 48 min             ││
│  ├─────────────────────────────────┤│
│  │ PHIL101 — Seminar               ││
│  │ 2026-09-11 · 38 min             ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

- **Empty state heading**: "No recordings yet"
- **Empty state body**: "Record a lecture and it'll appear here after your Mac processes it."
- **Row**: Course code + type (`.subheadline`, primary), date + duration (`.caption`, `.secondary`).
- **Tap**: Opens the note in a read-only `Text` view (no editing — Obsidian is the editor).
- **Refresh**: Pull-to-refresh rescans the vault.

### iOS Settings Tab (Phase 5 minimal)

```
┌─────────────────────────────────────┐
│  Settings                           │
│                                     │
│  Permissions                    >   │
│                                     │
│  About                              │
│  unibrain v1.0                      │
│  Local-first. Your audio never      │
│  leaves your devices.               │
└─────────────────────────────────────┘
```

- **Permissions row** (`chevron.right`): Opens Permissions sheet (Surface 3).
- **About section**: App version + privacy statement. No telemetry, no analytics link (there is none).

---

## Surface 3: Permissions Audit Sheet (ONBD-05, ONB-04)

Accessible post-onboarding from both platforms. Lets Angelica audit or re-grant mic/calendar access without re-running the whole onboarding flow.

### macOS Access Point

"Manage Permissions" button in the menu-bar popover idle state (extends Phase 4's idle layout). Opens a SwiftUI `.sheet` (on macOS, `.sheet` is reliable outside of `MenuBarExtra` — Pitfall 2 only affects sheets attached to `MenuBarExtra(.window)` itself; this sheet attaches to the main window or a dedicated Permissions window).

### iOS Access Point

"Permissions" row in the Settings tab. Pushes a `NavigationStack` destination or presents a `.sheet`.

### Permissions Sheet Layout

```
┌─────────────────────────────────────┐
│  Permissions                        │
│                                     │
│  MICROPHONE                         │
│  ● Microphone            Granted    │
│  Required for recording.            │
│                          [ Settings ]│
│                                     │
│  CALENDAR                           │
│  ● Calendar              Connected  │
│  Auto-routes recordings to courses. │
│                          [ Settings ]│
│                                     │
│  VAULT                              │
│  📁 Unibrain/                       │
│  Where notes are saved.             │
│                          [ Change ] │
│                                     │
│              [ Done ]               │
└─────────────────────────────────────┘
```

- **Microphone row**: Live status — green `checkmark.circle.fill` + "Granted" if permission active; red `xmark.circle.fill` + "Denied" if not. "Required for recording." in `.caption`, `.secondary`. "Settings" button opens system privacy settings deep-link.
- **Calendar row**: Live status — green + "Connected" if Full Access; orange + "Off — Manual Pick" if denied; gray + "Not Requested" if never asked. "Settings" button opens system calendar privacy settings.
- **Vault row**: Shows current vault folder path. "Change" button re-opens the folder picker from onboarding (ONB-03). Updates the security-scoped bookmark.
- **Done button** (`.borderedProminent`, accent): Dismisses the sheet.
- **Status updates on sheet dismiss:** Re-reads actual authorization via `EKEventStore` and `AVAudioApplication` (iOS 17+) / `AVCaptureDevice` (macOS) when the sheet re-appears (user may have toggled permissions in System Settings).

---

## Surface 4: macOS iCloud Handoff Queue Progress (TRIG-01..04)

Extends the macOS menu-bar popover to show iCloud handoff status. Phase 5 activates the `_inbox/` folder (reserved in Phase 3 P-16).

### Idle State Extension

```
┌─────────────────────────────────────┐
│  Ready to record                    │
│  • small.en model downloaded ✓      │
│  • Microphone available ✓           │
│  • Calendar connected ✓             │
│                                     │
│  iCloud Inbox: 2 pending            │
│  [ View Queue ]                     │
│                                     │
│         ┌───────────────┐           │
│         │     Record     │           │
│         └───────────────┘           │
│                                     │
│  Term: Fall 2026                    │
│  [ Manage Courses ]                 │
│  [ Manage Permissions ]             │
└─────────────────────────────────────┘
```

- **iCloud Inbox line** (conditional): Shows when `_inbox/` has pending files. "iCloud Inbox: {N} pending" in `.caption`, `.secondary` with `icloud` icon. Absent when inbox is empty.
- **View Queue button** (`.bordered`, secondary, small): Shows queue detail inline.
- **Manage Permissions button** (`.bordered`, secondary, small): Opens Permissions sheet (Surface 3). New in Phase 5.

### Queue Processing States

#### Downloading iPhone Recording (IC-04)

```
┌─────────────────────────────────────┐
│  ◌ Downloading iPhone recording…    │
│                                     │
│  iphone-20260915T101530-a3f8.m4a   │
│  ━━━━━━━░░░░░░░░░░░░  60%           │
│                                     │
│  Queue: 1 more pending              │
└─────────────────────────────────────┘
```

- Shows when macOS detects a `.icloud` placeholder and triggered `URL.startDownloadingUbiquitousItem()`.
- Progress: polls `URLResourceKey.ubiquitousItemDownloadingStatusKey` until `.current`.
- Filename shown for debug value (Greg can identify which recording is syncing).

#### Transcribing iPhone Recording

```
┌─────────────────────────────────────┐
│  ◌ Transcribing iPhone recording…   │
│                                     │
│  Est. ~3 min                        │
│  Queue: 1 more pending              │
└─────────────────────────────────────┘
```

- Same visual as Phase 3 transcribing state, with "iPhone recording" label to distinguish from macOS-recorded.
- Queue count shows remaining files.

#### Queue Failed (TRIG-04 — Dead-Letter)

```
┌─────────────────────────────────────┐
│  ⚠ Recording failed                 │
│                                     │
│  iphone-20260915T101530-a3f8.m4a   │
│  Failed after 3 retries.            │
│  Saved to _inbox/_failed/           │
│                                     │
│  [ Retry ]    [ Delete ]            │
└─────────────────────────────────────┘
```

- **Warning icon** (`exclamationmark.triangle.fill`, `.orange`).
- **Filename** (`.caption`, `.secondary`): For identification.
- **Failure summary** (`.body`, `.secondary`): "Failed after 3 retries." + "Saved to `_inbox/_failed/`".
- **Retry button** (`.borderedProminent`, accent): Re-enqueues the file from `_failed/` back to `_inbox/`.
- **Delete button** (`.bordered`, destructive): Permanently deletes the audio file + error sidecar. Confirmation alert: "Delete this recording permanently? This cannot be undone."

---

## Copywriting Contract

Inherits Phase 3/4 tone: calm, brief, no exclamation marks. Angelica is in a lecture or setting up her devices — she needs information, not personality.

**Exception:** The onboarding Ready page may use "You're all set!" — a single warm moment at the end of setup. After that, the app reverts to neutral tone.

| Element | Copy |
|---------|------|
| **Onboarding — Welcome app name** | "unibrain" |
| **Onboarding — Welcome value prop** | "Every recording lands in the right course folder, automatically." |
| **Onboarding — Welcome CTA** | "Get Started" |
| **Onboarding — Vault heading** | "Choose Your Vault Folder" |
| **Onboarding — Vault explanation** | "Pick the folder where unibrain will save your lecture notes. iCloud Drive is recommended so your notes sync across devices." |
| **Onboarding — Vault choose button** | "Choose Folder…" |
| **Onboarding — Vault not picked** | "Select a folder to continue" |
| **Onboarding — Mic heading** | "Microphone Access" |
| **Onboarding — Mic explanation** | "unibrain needs microphone access to record your lectures. Audio never leaves your devices unless you explicitly enable cloud processing." |
| **Onboarding — Mic allow button** | "Allow Microphone Access" |
| **Onboarding — Mic granted** | "Microphone enabled" |
| **Onboarding — Mic denied** | "Microphone access required. Tap Open System Settings to enable." |
| **Onboarding — Calendar heading** | "Calendar Access" |
| **Onboarding — Calendar explanation** | "unibrain uses your calendar to automatically route recordings to the right course folder." |
| **Onboarding — Calendar allow button** | "Allow Calendar Access" |
| **Onboarding — Calendar skip button** | "Skip (Manual Pick)" |
| **Onboarding — Calendar skip note** | "You'll pick the course manually each time." |
| **Onboarding — Calendar granted** | "Calendar connected" |
| **Onboarding — Term heading (macOS)** | "Set Your Current Term" |
| **Onboarding — Term explanation** | "unibrain organizes notes by term. Set your current term so recordings route to the right folder." |
| **Onboarding — Term label placeholder** | "e.g., Fall 2026" |
| **Onboarding — Term start date label** | "Start Date" |
| **Onboarding — Term end date label** | "End Date" |
| **Onboarding — Ready heading** | "You're all set!" |
| **Onboarding — Ready body** | "Record on your iPhone in class, and notes appear on your MacBook automatically." |
| **Onboarding — Ready CTA** | "Start Using unibrain" |
| **iOS — lock screen Now Playing title** | "Recording" |
| **iOS — lock screen Now Playing subtitle** | "{elapsed time}" (e.g., "14:32") |
| **iOS — Stop confirmation** | "Saved — syncing to your Mac via iCloud." |
| **iOS — Recent empty heading** | "No recordings yet" |
| **iOS — Recent empty body** | "Record a lecture and it'll appear here after your Mac processes it." |
| **iOS — Settings About privacy** | "Local-first. Your audio never leaves your devices." |
| **Permissions sheet — heading** | "Permissions" |
| **Permissions sheet — mic granted** | "Granted" |
| **Permissions sheet — mic denied** | "Denied" |
| **Permissions sheet — mic description** | "Required for recording." |
| **Permissions sheet — calendar connected** | "Connected" |
| **Permissions sheet — calendar off** | "Off — Manual Pick" |
| **Permissions sheet — calendar description** | "Auto-routes recordings to courses." |
| **Permissions sheet — vault description** | "Where notes are saved." |
| **Permissions sheet — vault change button** | "Change" |
| **Permissions sheet — settings button** | "Settings" |
| **Permissions sheet — done button** | "Done" |
| **macOS popover — iCloud inbox pending** | "iCloud Inbox: {N} pending" |
| **macOS popover — downloading iPhone recording** | "Downloading iPhone recording…" |
| **macOS popover — transcribing iPhone recording** | "Transcribing iPhone recording…" |
| **macOS popover — queue failed heading** | "Recording failed" |
| **macOS popover — queue failed body** | "Failed after 3 retries. Saved to `_inbox/_failed/`." |
| **macOS popover — queue retry button** | "Retry" |
| **macOS popover — queue delete button** | "Delete" |
| **macOS popover — manage permissions button** | "Manage Permissions" |
| **Destructive confirmation: Delete failed recording** | "Delete this recording permanently? This cannot be undone." |
| **Destructive confirmation: Delete confirm** | "Delete" |
| **Destructive confirmation: Delete cancel** | "Keep" |

**Pronouns:** always "your" (calendar, course, term, recordings), never "the" — reinforces ownership in a single-user app.

---

## Interaction Contracts

### Onboarding Flow (state machine)

```
Welcome ──[Get Started]──→ Vault ──[Continue]──→ Mic ──[Allow + Granted]──→ Calendar
                                   │                       │
                                   │                       └──[Denied]──→ (stuck — cannot advance)
                                   │
                                   └──[no folder picked]──→ (Continue disabled)
                                                    │
                     macOS: Calendar ──[Allow/Skip]──→ Term ──[Continue]──→ Ready ──[Start Using]──→ Main App
                     iOS:   Calendar ──[Allow/Skip]──→ Ready ──[Start Using]──→ Main App
```

- **macOS-first sequence (ONB-01):** Angelica sets up her MacBook first. When she opens iOS later, the iOS onboarding detects `.unibrain/courses.json` in the picked iCloud Drive folder and inherits `currentTerm` + course mappings.
- **iOS vault inheritance check:** After picking a folder on iOS, if `.unibrain/courses.json` exists, the Term page is skipped. If not, a post-onboarding banner appears: "Set up unibrain on your Mac to enable course routing."
- **Permission pages are non-linear:** Calendar page allows Skip. Mic page does not (HARD-FAIL). Term page allows empty label but disables Continue (planner can default to today's year/season if desired — CONTEXT discretion).

### iOS Recording Lifecycle (CAPT-03, DISC-04, IOS-02, IOS-03)

```
idle ──[tap Record]──→ recording ──[tap Stop]──→ saving ──[saved]──→ idle
                            │                                       ↑
                            ├──[tap Pause]──→ paused ──[Resume]─────┘
                            │                  │
                            ├──[lock screen]──→ background recording (continuous)
                            ├──[interruption]──→ auto-paused ──[end interruption]──→ auto-resume
                            └──[lock screen Stop]──→ saving
```

- **Background recording (CAPT-03):** `UIBackgroundModes: ["audio"]`. Screen lock does not stop recording. `MPNowPlayingInfoCenter` updates lock screen with elapsed time.
- **Remote commands (IOS-02):** Lock screen Stop and Pause buttons work via `MPRemoteCommandCenter`.
- **Interruption auto-pause/resume (IOS-03):** Phone call or Siri → auto-pause. End of interruption → auto-resume. No user action needed.
- **On Stop (IC-02):** Atomic move from sandbox `tmp/` to `{vault}/_inbox/`. Toast: "Saved — syncing to your Mac via iCloud."

### macOS iCloud Handoff Pipeline (TRIG-01..04)

```
_inbox/ file detected ──[.icloud placeholder]──→ download ──[downloaded]──→ transcribe ──→ classify ──→ write ──→ move audio ──→ dequeue
        │                              │                                                                          │
        ├──[real file]──→ transcribe   └──[download timeout]──→ retry (3x, backoff)──→ failed ──→ _inbox/_failed/    │
                                                                                                                       │
                                                              ┌──────────────────────────────────────────────────────┘
                                                              └──[transcribe/classify/write failed]──→ retry (3x) ──→ _failed/
```

- **NSMetadataQuery + launch scan (TRIG-01):** Hybrid — live watch while app is running + one-shot scan on app launch catches files that arrived while app was closed.
- **Serial FIFO queue (TRIG-02):** One file at a time. Honors Phase 2 O-02 (orchestrator rejects concurrent runs).
- **Move on success (TRIG-03):** Audio atomically moved from `_inbox/` to `{vault}/{term}/{course-code}/` alongside the note.
- **Retry with backoff (TRIG-04):** 3 retries, exponential backoff (30s, 2min, 10min). On final failure, dead-letter to `_inbox/_failed/` with `.error.json` sidecar. Popover surfaces failure with Retry/Delete.

---

## Accessibility

Inherits Phase 3/4 accessibility patterns. Phase 5 additions:

- **Onboarding pages:** each page has `.accessibilityElement(children: .contain)` with `.accessibilityLabel` describing the step ("Onboarding step 2 of 5: Choose your vault folder").
- **Onboarding buttons:** `.accessibilityLabel` + `.accessibilityHint` on every button. "Get Started" → hint: "Begins the setup process". "Allow Microphone Access" → hint: "Opens the system permission dialog".
- **Progress dots:** `.accessibilityValue("Page 2 of 5")` on the TabView.
- **iOS Record button:** `.accessibilityLabel("Start recording")`, `.accessibilityHint("Taps once to begin recording. Recording continues when screen is locked.")`.
- **iOS lock screen:** `MPNowPlayingInfoCenter` automatically provides VoiceOver-compatible metadata. Stop/Pause remote commands have accessibility labels.
- **Permissions sheet rows:** each row is a single accessibility element: `.accessibilityLabel("Microphone, granted, required for recording")`.
- **Color independence:** permission status uses icon shape (`checkmark.circle.fill` vs `xmark.circle.fill`) + text label, not color alone.
- **Dynamic Type:** all onboarding pages and iOS surfaces respect Dynamic Type. Onboarding pages scroll if content overflows at largest text size.

---

## Component Inventory (for planner)

New SwiftUI views/components Phase 5 introduces (planner allocates these as tasks):

| Component | File (suggested) | Lines (est.) | Source |
|-----------|-------------------|--------------|--------|
| `OnboardingView` | `UnibrainApp/Views/Onboarding/OnboardingView.swift` | 80-120 | ONB-02 |
| `OnboardingWelcomePage` | `UnibrainApp/Views/Onboarding/OnboardingWelcomePage.swift` | 40-50 | ONB-02 |
| `OnboardingVaultPage` | `UnibrainApp/Views/Onboarding/OnboardingVaultPage.swift` | 60-80 | ONB-03 |
| `OnboardingMicPage` | `UnibrainApp/Views/Onboarding/OnboardingMicPage.swift` | 50-60 | ONBD-02 |
| `OnboardingCalendarPage` | `UnibrainApp/Views/Onboarding/OnboardingCalendarPage.swift` | 50-60 | ONBD-03 |
| `OnboardingTermPage` | `UnibrainApp/Views/Onboarding/OnboardingTermPage.swift` | 50-60 | ONB-01, CT-01 |
| `OnboardingReadyPage` | `UnibrainApp/Views/Onboarding/OnboardingReadyPage.swift` | 30-40 | ONB-02 |
| `iOSTabView` (shell) | `UnibrainApp/Views/iOS/iOSTabView.swift` | 40-60 | IOS-01 |
| `iOSRecordTab` | `UnibrainApp/Views/iOS/iOSRecordTab.swift` | 120-150 | IOS-04 |
| `iOSRecentTab` | `UnibrainApp/Views/iOS/iOSRecentTab.swift` | 60-80 | IOS-01 |
| `iOSSettingsTab` | `UnibrainApp/Views/iOS/iOSSettingsTab.swift` | 30-40 | IOS-01 |
| `PermissionsSheet` | `UnibrainApp/Views/PermissionsSheet.swift` | 60-80 | ONB-04 |
| `iCloudQueueProgressView` | `UnibrainApp/Views/iCloudQueueProgressView.swift` | 40-60 | TRIG-01..04 |
| `FailedRecordingView` | `UnibrainApp/Views/FailedRecordingView.swift` | 40-50 | TRIG-04 |
| `ContentView` update | `UnibrainApp/ContentView.swift` | +30 | conditional onboarding/main |
| `UnibrainApp` update | `UnibrainApp/UnibrainApp.swift` | +40 | iOS TabView shell, onboarding entry |
| `MenuBarPopover` extension | `UnibrainApp/MenuBarPopover.swift` | +30 | iCloud queue + Manage Permissions |

**Estimated total new SwiftUI:** ~800-1100 lines across ~14 new view files + ~100 lines of extensions to existing files. All iOS-only views sit behind `#if os(iOS)` guards. Onboarding views are shared (with platform-conditional layout inside). macOS-specific extensions stay unguarded.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| SwiftUI (system) | `TabView` (page style + bottom tab), `NavigationStack`, `Form`, `List`, `Section`, `.fileImporter`, `DatePicker`, `ProgressView`, `Label`, `Button`, `Canvas`, `TimelineView`, `Alert` | not required (Apple framework — no third-party audit needed) |
| MediaPlayer (system) | `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` | not required (Apple framework — iOS lock screen integration) |
| Third-party SPM | (none in Phase 5 UI layer) | not applicable |

**No web registry components used.** This is a native SwiftUI app — shadcn/ui, Radix, base-ui are not applicable. Registry safety checks pass vacuously.

---

## Platform-Specific Notes (for planner)

### Info.plist Keys (iOS — planner writes actual strings)

- `UIBackgroundModes`: `["audio"]` — background recording (CAPT-03, DISC-04)
- `NSMicrophoneUsageDescription`: "unibrain needs microphone access to record your lectures." (ONBD-02)
- `NSCalendarsUsageDescription`: "unibrain uses your calendar to automatically route recordings to the right course folder." (ONBD-03)

### macOS Entitlements

- `com.apple.security.files.user-selected.read-write` — already standard for sandboxed Mac apps (security-scoped bookmark persists vault access)

### Deployment Target

- macOS 26 Tahoe (D-05) — unlocks SpeechAnalyzer, modern AVAudioSession APIs
- iOS 17 (D-05) — unlocks `@Observable`, `requestFullAccessToEvents`, modern SwiftUI

### Apple Developer Program

- IC-01 picker-only path works WITHOUT paid Apple Developer Program membership (no iCloud container entitlement needed). Phase 5 is unblocked if the Dev Program decision (FOUND-06) is still deferred.
- TestFlight to Angelica's iPhone DOES require paid membership ($99/yr). Planner flags this as a device-testing prerequisite.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS — all onboarding copy, iOS labels, permissions text, queue states have explicit copy. Tone inherited from Phase 3/4.
- [ ] Dimension 2 Visuals: PASS — every surface has ASCII mock + component spec + interaction contract
- [ ] Dimension 3 Color: PASS — semantic system colors, accent/warning/destructive reserved explicitly, iOS/macOS variants noted
- [ ] Dimension 4 Typography: PASS — SF Pro semantic styles, monospaced timer (48pt iOS / 32pt macOS), onboarding roles declared
- [ ] Dimension 5 Spacing: PASS — 4pt-multiple scale inherited from Phase 3/4, full-screen iOS pages documented
- [ ] Dimension 6 Registry Safety: PASS — native SwiftUI + MediaPlayer only, no web registry applicable

**Approval:** pending

---

*Phase: 5 — iOS Capture + iCloud Handoff + Onboarding*
*UI-SPEC generated: 2026-07-15*
*Sources: 05-CONTEXT.md (IC-01..04, IOS-01..04, TRIG-01..04, ONB-01..04) + 03-UI-SPEC.md + 04-UI-SPEC.md (inherited design tokens) + Apple HIG for TabView/fileImporter/onboarding patterns + REQUIREMENTS.md (CAPT-03, ONBD-01, ONBD-04, ONBD-05, DISC-04)*
