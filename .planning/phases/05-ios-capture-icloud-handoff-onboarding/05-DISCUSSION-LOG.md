# Phase 5: iOS Capture + iCloud Handoff + Onboarding - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 5-iOS Capture + iCloud Handoff + Onboarding
**Areas discussed:** iCloud container strategy, iOS capture UI surface, macOS pipeline trigger, Onboarding scope + cross-device

---

## iCloud container strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Picker-only (no container) | No iCloud capability entitlement. Onboarding vault picker lets Angelica choose any folder, defaults to iCloud Drive root. `_inbox/` is a subfolder of the picked vault. Security-scoped bookmark persists the choice. Works without Apple Dev Program membership. Aligns with Phase 3 P-13 + Phase 4 M-01. | ✓ |
| App's own container | Enable iCloud Documents capability + NSUbiquitousContainers entitlement. App owns `iCloud.app.unibrain/Documents/`. Zero picker friction. REQUIRES Apple Developer Program paid membership — currently deferred. | |
| Hybrid (container + vault picker) | Container holds only `_inbox/` for transit. Vault picker for user-visible Obsidian vault. Most flexible but adds both entitlement complexity AND picker complexity. | |
| You decide | Claude leans Picker-only for Phase 5 (avoids blocking on Apple Dev Program; can add container in Phase 6 polish). | |

**User's choice:** Picker-only (no container)
**Notes:** Keystone architectural decision — avoids blocking Phase 5 on the still-deferred Apple Dev Program decision (Phase 1 D-01). Tradeoff: Angelica must pick the same iCloud Drive folder on both devices for `.unibrain/courses.json` config inheritance to work.

---

## iPhone active-recording file location

| Option | Description | Selected |
|--------|-------------|----------|
| Sandbox first, move on Stop | AVAudioRecorder writes to app sandbox `tmp/recordings/{uuid}.m4a`. On Stop, app moves file to picked iCloud Drive folder's `_inbox/`. Safer; industry-standard pattern (Voice Memos, Just Press Record). | ✓ |
| Direct to iCloud Drive | AVAudioRecorder writes directly into `_inbox/`. Simpler. Risk: iCloud may evict or refuse writes under storage pressure. | |
| You decide | Claude leans Sandbox-first (Apple best practices for background recording). | |

**User's choice:** Sandbox first, move on Stop
**Notes:** Partial-file safety — if app is killed mid-recording, partial file stays in sandbox (no corrupt iCloud upload).

---

## `_inbox/` filename strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Timestamp + source prefix | `{source}-{YYYYMMDDTHHMMSS}-{shortUUID}.m4a`. Sortable, source device evident, UUID guarantees uniqueness. Matches ISO 8601. Pipeline renames to Phase 2 N-02 form when writing note. | ✓ |
| UUID only | `{UUID}.m4a`. Maximally simple. Loses sortability and source identification. | |
| You decide | Claude leans Timestamp + source prefix for debuggability. | |

**User's choice:** Timestamp + source prefix
**Notes:** Debug value — Greg/Angela can see at a glance which device a stuck file came from.

---

## `.icloud` placeholder handling

| Option | Description | Selected |
|--------|-------------|----------|
| Active download + wait | macOS pipeline calls `URL.startDownloadingUbiquitousItem()`, polls until downloaded, then processes. Popover shows progress. Most responsive. | ✓ |
| Passive (lazy iCloud download) | Skip placeholders silently. iCloud eventually downloads. Simpler but unpredictable latency (hours). | |
| Active + timeout fallback | Trigger download, cap wait at e.g. 5 min, defer on timeout. Balance of responsiveness + non-blocking. | |
| You decide | Claude leans Active + timeout fallback. | |

**User's choice:** Active download + wait
**Notes:** Amends Phase 2 A-03 (which treats `.icloud` as hard error) for the Phase 5 iCloud-handoff path specifically. Phase 2's hard-error stays for non-iCloud destinations. Planner must extend `NoteWriterError` or add `InboxWatcherError` to distinguish "download in progress" from "true skip" cases.

---

## iOS app structure

| Option | Description | Selected |
|--------|-------------|----------|
| Voice-Memos-style single screen | Full-screen single-purpose Record view. Most idiomatic iOS capture UX. Settings + Recent deferred. | |
| TabView (Record / Recent / Settings) | Three-tab TabView at bottom. Record = capture UI. Recent = note list. Settings = Phase 6 entry. More room for growth. | ✓ |
| NavigationStack (push pages) | Record as root, push to other screens. More flexible, less structure. | |
| You decide | Claude leans Voice-Memos-style. | |

**User's choice:** TabView (Record / Recent / Settings)
**Notes:** Phase 5 ships Record + Recent (read-only); Settings tab is Phase 6 hook with minimal placeholder (Permissions sheet entry only).

---

## Lock-screen / Dynamic Island indicator

| Option | Description | Selected |
|--------|-------------|----------|
| Now Playing + remote commands | `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`. Standard iOS audio-app pattern. Lock screen, Control Center, AirPods, Apple Watch. | ✓ |
| Live Activity + Dynamic Island | `ActivityKit` Live Activity widget on lock screen + Dynamic Island pill. More prominent. iOS 16.1+ / 17.2+. More code. | |
| Both | Ship both — belt-and-suspenders. Most code; covers all iOS versions from 17 baseline. | |
| You decide | Claude leans Now Playing only. | |

**User's choice:** Now Playing + remote commands
**Notes:** Live Activity / Dynamic Island deferred to Phase 6 polish. Satisfies CAPT-03 "lock-screen recording indicator."

---

## Audio-session interruption behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Pause + auto-resume | Delegate handles begin/end interruption; auto-resume on end. Seamless for Angelica; .m4a stays contiguous. | ✓ |
| Stop + surface for restart | Interruption stops recording cleanly. User manually restarts. Mirrors Voice Memos. More predictable. | |
| Pause + notify (manual resume) | Interruption pauses; notification with "tap to resume." Hybrid; safer than auto-resume. | |
| You decide | Claude leans Pause + notify (manual resume). | |

**User's choice:** Pause + auto-resume
**Notes:** CAPT-02 pause/resume timestamp markers preserved. Accepted risk: auto-resume may fail silently after long interruptions (queue processor's failure path catches this).

---

## iOS Record tab layout

| Option | Description | Selected |
|--------|-------------|----------|
| Voice Memos clone | Centered record button, timer, waveform, mic meter. Familiar. | |
| Expanded Phase 3 layout | Timer top, large live waveform center, mic-level meter, Pause/Stop buttons. Better visual real estate. | ✓ |
| Minimalist | Just record button + timer. Loses CAPT-05 mic-level visibility. | |
| You decide | Claude leans Voice Memos clone. | |

**User's choice:** Expanded Phase 3 layout
**Notes:** iOS gets a bigger visual canvas than macOS — better for confirming from across a lecture hall that the lecturer is audible.

---

## macOS pipeline trigger mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| NSMetadataQuery + launch scan | iCloud-aware watcher while running + scan on launch for missed files. Hybrid = responsive + robust. | ✓ |
| NSMetadataQuery only | Assumes app always running. Risk: missed files when app closed. | |
| Timer-based polling | `Timer.publish(every: 30s)` scans. Simple, crude, wastes CPU. | |
| You decide | Claude leans hybrid (only robust option). | |

**User's choice:** NSMetadataQuery + launch scan
**Notes:** Menu-bar apps get quit; MacBooks restart. Hybrid is the only robust option. Pairs naturally with IC-04 active download.

---

## Multi-file queue processing

| Option | Description | Selected |
|--------|-------------|----------|
| Serial FIFO queue | One file at a time. Matches Phase 2 O-02 `.alreadyRunning` rejection. Predictable. | ✓ |
| Batch-on-idle | Wait N seconds of quiet, process all at once. Risk: idle timer resets on each arrival. | |
| Concurrent (revisit O-02) | Process files concurrently. Breaks Phase 2 architecture. | |
| You decide | Claude leans Serial FIFO (only real option). | |

**User's choice:** Serial FIFO queue
**Notes:** Architecturally aligned with Phase 2 O-02.

---

## Post-success file cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Move to final course folder | Atomic move `_inbox/` → `{vault}/{term}/{course}/`. Aligns with Phase 3 P-15. `_inbox/` stays transit-only. | ✓ |
| Delete after note written | Free iCloud storage. Loses audio file permanently. | |
| Leave + sidecar marker | `_inbox/{file}.done` marker. Audio stays permanently; clutter. | |
| You decide | Claude leans Move to final course folder. | |

**User's choice:** Move to final course folder
**Notes:** Both paths inside same iCloud Drive container (IC-01) — move is fast and atomic.

---

## Pipeline failure handling

| Option | Description | Selected |
|--------|-------------|----------|
| Retry-with-backoff + dead-letter | 3 retries (30s, 2min, 10min). On final failure, move to `_inbox/_failed/` with `.error.json` sidecar. Popover surfaces with Retry/Delete buttons. | ✓ |
| One-shot + surface | Try once, surface error. Aligns with Phase 2 O-03 fail-fast. No backoff. | |
| Silent retry (no UI) | Retry indefinitely. Risk: silent stuck queue. | |
| You decide | Claude leans Retry-with-backoff + dead-letter. | |

**User's choice:** Retry-with-backoff + dead-letter
**Notes:** Queue-level retry — DISTINCT from Phase 6's cloud-provider retry (CLOUD-10) which is per-call inside the provider client. The two retry layers compose cleanly.

---

## Onboarding platform scope

| Option | Description | Selected |
|--------|-------------|----------|
| Both platforms, independently | Each device runs full onboarding. Each picks own vault. Permissions per-device. | |
| iOS-first, macOS inherits | iOS onboarding first. macOS inherits config via `.unibrain/courses.json`. | |
| macOS-first, iOS inherits | macOS onboarding first. iOS detects `.unibrain/courses.json` and inherits currentTerm + mapping. iOS still needs own vault pick + permissions. | ✓ |
| You decide | Claude leans Both platforms independently. | |

**User's choice:** macOS-first, iOS inherits
**Notes:** Reflects real-world setup sequence — Angelica opens MacBook first. iOS onboarding is ABBREVIATED: Welcome → Vault → Mic → Calendar → Ready (skips Term step).

---

## Onboarding visual structure

| Option | Description | Selected |
|--------|-------------|----------|
| PageTabView + progress dots | One full-screen page per step, swipeable, progress dots. Apple's standard first-run pattern. Ceremonial. | ✓ |
| Single Form + submit | All steps in one scrollable Form. Faster, less ceremonial. | |
| Welcome page + Form | Hybrid: welcome page then one Form. Two screens total. | |
| You decide | Claude leans Welcome page + Form. | |

**User's choice:** PageTabView + progress dots
**Notes:** iOS-idiomatic. macOS adapts to sheet on first launch.

---

## Vault folder picker mechanics

| Option | Description | Selected |
|--------|-------------|----------|
| Folder picker with iCloud default | SwiftUI `.fileImporter` with `.folder` content type. macOS NSOpenPanel opens at iCloud Drive root. iOS surfaces iCloud Drive prominently. Security-scoped bookmark in Keychain. | ✓ |
| Pre-create + confirm | App pre-creates `Unibrain/` in iCloud Drive. User confirms. Less choice, more guided. | |
| Two-step: iCloud prompt + picker | First asks "Use iCloud Drive?", then picker scoped accordingly. Explicit choice, more friction. | |
| You decide | Claude leans Folder picker with iCloud default. | |

**User's choice:** Folder picker with iCloud default
**Notes:** One-step, flexible, respects Angelica's choice. Planner researches iOS security-scoped bookmark staleness handling (bookmarks can expire if folder renamed/moved in Files app).

---

## Post-onboarding permissions access (ONBD-05)

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated Permissions sheet | macOS menu-bar popover + iOS Settings tab → SwiftUI sheet showing live mic/calendar status + "Open System Settings" deep-link per row. Updates on dismiss. | ✓ |
| Re-run onboarding button | Re-trigger PageTabView flow. Heavyweight for a status check. | |
| Deep-link only | "Open Privacy Settings" button. No in-app status display. Minimal. | |
| You decide | Claude leans Dedicated Permissions sheet (satisfies ONBD-05 "audit" wording). | |

**User's choice:** Dedicated Permissions sheet
**Notes:** Phase 5 minimum. Phase 6's full Settings UI (CLOUD-01) will fold this sheet into a tab.

---

## Claude's Discretion

User selected "You decide" on zero questions in this phase — all 12 sub-questions had a concrete user pick. Claude's discretion items in CONTEXT.md cover only the small implementation details that emerged as "planner picks" follow-ups (sandbox subfolder path, AVAudioSession category specifics, Info.plist key strings, queue persistence model, backoff schedule, dead-letter JSON schema, welcome page copy, term input UI defaults, macOS onboarding surface, iOS bookmark lifecycle, etc.).

## Deferred Ideas

See CONTEXT.md `<deferred>` section for the full list. Notable: iCloud container (Phase 6 polish), Live Activity (Phase 6 polish), iPad-optimized layout (v2), iPhone transcription (v2), AirDrop fallback (v2), Apple Watch companion (v2).
