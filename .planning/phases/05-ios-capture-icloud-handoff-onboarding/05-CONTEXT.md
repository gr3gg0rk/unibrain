# Phase 5: iOS Capture + iCloud Handoff + Onboarding - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

The iPhone becomes the second capture surface (the discreet in-class device), and the first-run onboarding flow ships end-to-end. Phase 5 delivers: (1) iOS background recording that survives 30+ minutes of locked-screen time (CAPT-03, DISC-04); (2) iCloud Drive handoff — iPhone audio appears in macOS `_inbox/` via user-picked iCloud Drive folder, and the macOS pipeline picks it up automatically (success criterion #2); (3) the full onboarding flow (welcome → vault picker → mic permission → calendar permission → current-term label → ready) on macOS with iOS inheriting config via `.unibrain/courses.json` (ONBD-01, ONBD-04); (4) a dedicated Permissions sheet accessible post-onboarding for re-grant or audit (ONBD-05); and (5) activation + on-device testing of the iOS EventKit adapter that Phase 4 shipped behind `#if os(iOS)` guards (Phase 4 P-03).

**iPhone is capture-only.** Phase 5 success criterion #2 locks: iPhone audio syncs to macOS; **macOS runs the transcription pipeline**. iPhone does NOT load whisper.cpp or SpeechAnalyzer (preserves iPhone battery/RAM; Angelica's iPhone model is unspecified). The iPhone's job is: record → save → move to iCloud → done.

**Phase 4 dependency:** Phase 5 assumes Phase 4's iOS EventKit adapter, `.unibrain/courses.json` mapping, currentTerm schema (CT-01), and `{vault}/{term}/{course-code}/` folder structure all exist. iOS capture routes via Phase 4's classifier on macOS (iPhone audio hits macOS `_inbox/`, gets classified there, lands in the right course folder).

**Phase 3 dependency:** Phase 5 reuses Phase 3's `TranscriberRouter`, `PipelineOrchestrator`, `NSFileCoordinatorNoteWriter`, menu-bar popover (macOS side), and the `_inbox/` reservation (Phase 3 P-16).

</domain>

<decisions>
## Implementation Decisions

### iCloud Container Strategy (ONBD-04, IC-01..04)

- **IC-01: Picker-only — no iCloud container entitlement.** The app does NOT use `NSUbiquitousContainers` or iCloud Documents capability. Instead, the onboarding vault picker (ONBD-03) lets Angelica pick any folder, defaulting to her iCloud Drive root (`~/Library/Mobile Documents/com~apple~CloudDocs/` on macOS; iCloud Drive location surfaced in `UIDocumentPickerViewController` on iOS). `_inbox/` is a subfolder of the picked vault. Security-scoped bookmark persists the choice per-device in Keychain. Rationale: works without Apple Developer Program paid membership (currently deferred per Phase 1 D-01); aligns with Phase 3 P-13 default vault root; Phase 4 M-01's `.unibrain/courses.json` already lives inside the vault so iCloud Drive syncs the mapping once Angelica picks the same folder on both devices.
- **IC-02: Sandbox-first recording, move on Stop.** iPhone's `AVAudioRecorder` writes to its own sandbox `tmp/recordings/{uuid}.m4a` during active recording. On Stop, the app performs an atomic move into the picked iCloud Drive folder's `_inbox/` subfolder. iCloud sync begins asynchronously after the file lands. Safer than direct-to-iCloud (no partial-file upload semantics, no iCloud write refusals under storage pressure, crash mid-recording leaves partial in sandbox instead of corrupt iCloud state). Industry-standard pattern (Voice Memos, Just Press Record).
- **IC-03: Timestamp + source-prefix filenames.** `_inbox/` audio files are named `{source}-{YYYYMMDDTHHMMSS}-{shortUUID}.m4a`, e.g., `iphone-20260915T101530-a3f8.m4a` or `macos-20260915T101530-b71c.m4a`. ISO 8601 timestamp guarantees chronological sortability; source prefix identifies origin at a glance (debug value when Greg/Angela inspect `_inbox/`); shortUUID suffix guarantees uniqueness even if two devices start recording in the same second. The pipeline renames to Phase 2 N-02 final form (`YYYY-MM-DD-{course_code}-Lecture.md` + matching `.m4a`) when writing the note.
- **IC-04: Active download + wait for `.icloud` placeholders.** When macOS detects an `_inbox/` file that is a `.icloud` placeholder (not-yet-downloaded), the pipeline calls `URL.startDownloadingUbiquitousItem()` to force iCloud to fetch the file, polls `URLResourceKey.ubiquitousItemDownloadingStatusKey` until `.current`, then proceeds. The macOS popover shows "Downloading iPhone recording…" with progress. This AMENDS Phase 2 A-03 (which currently treats `.icloud` as a hard error) specifically for the Phase 5 iCloud-handoff path — Phase 2's hard-error remains the contract for non-iCloud destinations. Planner must extend `NoteWriterError` (or define a new `InboxWatcherError`) to distinguish "download in progress" from "true .icloud skip" cases.

### iOS Capture UI Surface (CAPT-03, IOS-01..04)

- **IOS-01: TabView with Record / Recent / Settings.** iOS app shell is a three-tab `TabView` at the bottom. **Record tab** = full recording UI. **Recent tab** = read-only list of notes discovered via `.unibrain/courses.json` + vault scan (no editing — Obsidian is the editor per PROJECT.md Out of Scope). **Settings tab** = Phase 6 hook (ships minimal placeholder in Phase 5 — Permissions sheet entry only; full per-modality provider selectors arrive in Phase 6). Mirrors standard iOS app structure; gives Angelica on-iPhone visibility into past recordings. iPad uses the same TabView (sidebar layout is v2 — PROJECT.md Out of Scope for iPad-native capture).
- **IOS-02: Now Playing + remote commands only.** `MPNowPlayingInfoCenter` pushes "Recording — {elapsed}" to iOS lock screen, Control Center, AirPods double-tap, and Apple Watch remote. `MPRemoteCommandCenter` handles Stop/Pause commands from lock screen. Satisfies CAPT-03 "lock-screen recording indicator." `ActivityKit` Live Activity / Dynamic Island is DEFERRED to Phase 6 polish (more code, custom widget extension, marginal UX gain for the MVP).
- **IOS-03: Pause + auto-resume on interruption.** When iOS interrupts the audio session (phone call, Siri, another audio app claiming the session), the `AVAudioSession` delegate receives `audioRecorderBeginInterruption` → pause recording. On `audioRecorderEndInterruption` → automatically resume. The `.m4a` stays contiguous via Phase 3 CAPT-02 pause/resume timestamp markers. Angelica never manually restarts after a phone call. Accepted risk: if iOS killed the app during a long interruption, auto-resume fails silently — the queue processor's failure path (TRIG-04) catches this.
- **IOS-04: Expanded Phase 3 layout for Record tab.** iOS gets the Phase 3 macOS popover components (P-09) scaled up to full-screen: large timer at top, prominent live waveform visualization (SwiftUI `Canvas`) taking most of the screen, horizontal mic-level meter (green/yellow/red segments confirming CAPT-05 "lecturer is audible"), [Pause] [Stop] buttons at bottom. More visual real estate than macOS = better waveform visibility for confirming from across a lecture hall.

### macOS Pipeline Trigger (TRIG-01..04)

- **TRIG-01: NSMetadataQuery + launch scan (hybrid).** While the macOS app is running, an `NSMetadataQuery` with predicate scoped to `{vault}/_inbox/` watches for new files — iCloud-aware, fires on `.icloud` placeholder → real-file transitions (pairs naturally with IC-04 active download). On app launch, a one-shot scan of `_inbox/` catches any files that arrived while the app was closed (menu-bar apps get quit; MacBooks restart). Hybrid is the only robust option — assumes nothing about app always-running state.
- **TRIG-02: Serial FIFO queue.** Discovered files enqueue; the queue processor pops one file at a time, FIFO. For each file: trigger download if needed (IC-04) → run full pipeline (download → transcribe → classify → normalize → write) → move audio to final course folder (TRIG-03) → dequeue. Matches Phase 2 O-02 (orchestrator rejects concurrent runs via `.alreadyRunning`). Predictable ordering; no concurrency architecture needed beyond the queue.
- **TRIG-03: Move audio to final course folder on success.** After the pipeline writes the note, the source audio file is atomically moved from `_inbox/{source}-{timestamp}-{uuid}.m4a` to `{vault}/{term}/{course-code}/YYYY-MM-DD-{course_code}-Lecture.m4a` (the Phase 3 P-15 destination). The note references it via Obsidian wiki-link `![[YYYY-MM-DD-{course_code}-Lecture.m4a]]`. Both paths live inside the same iCloud Drive container (IC-01), so the move is fast and atomic on the same filesystem. `_inbox/` stays transit-only — only contains unprocessed files.
- **TRIG-04: Retry-with-backoff + dead-letter on failure.** Queue processor retries failed files up to 3 times with exponential backoff (30s, 2min, 10min). On final failure, moves the file to `_inbox/_failed/{filename}.m4a` with an error-log sidecar `_inbox/_failed/{filename}.error.json` (JSON: timestamp, error type, retry count, last error message). Popover surfaces "Recording failed: {short error}" with [Retry] [Delete] buttons. Recovers from transient issues (iCloud flake, file lock, SpeechAnalyzer transient error); dead-letter keeps `_inbox/` clean and prevents silent data loss. This is queue-level retry — DISTINCT from Phase 6's cloud-provider retry (CLOUD-10) which is per-call inside the provider client.

### Onboarding (ONBD-01, ONBD-04, ONBD-05, ONB-01..04)

- **ONB-01: macOS-first, iOS inherits.** macOS onboarding runs first (Angelica sets up her MacBook — she needs it for transcription anyway). When she later opens iOS app for the first time, iOS detects `.unibrain/courses.json` inside the iCloud Drive folder she picks and inherits `currentTerm` + course mapping. iOS onboarding is ABBREVIATED: welcome → vault pick → mic permission → calendar permission → ready (skips the current-term step, which is inherited). Each device still picks its own vault folder (filesystem paths differ) and grants its own permissions (per-device by iOS/macOS design).
- **ONB-02: PageTabView + progress dots.** Onboarding UI is a SwiftUI `TabView` with `.tabViewStyle(.page)` (page-style), one full-screen page per step, swipeable, progress dots at bottom. Steps on macOS: Welcome → Vault → Mic → Calendar → Term → Ready (6 pages). On iOS: Welcome → Vault → Mic → Calendar → Ready (5 pages, term inherited). Apple's standard first-run pattern. macOS adapts the same flow into a sheet on first launch (or a dedicated window — planner picks).
- **ONB-03: Folder picker with iCloud default.** SwiftUI `.fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:)` with `.folder` content type (UTType.folder). macOS `NSOpenPanel` opens at `~/Library/Mobile Documents/com~apple~CloudDocs/` (iCloud Drive root) as the default directory; iOS picker surfaces iCloud Drive location prominently. Angelica picks an existing folder or creates a new one (e.g., `Unibrain/`). Security-scoped bookmark persisted in macOS Keychain / iOS Secure Enclave so the app retains access across launches. Planner researches iOS bookmark staleness handling (bookmarks can expire; may need re-prompt).
- **ONB-04: Dedicated Permissions sheet (ONBD-05).** Phase 5 ships a minimal but complete Permissions UI: macOS menu-bar popover gets a "Manage Permissions" button → SwiftUI sheet showing live mic status (granted/denied) + live calendar status + "Open System Settings" deep-link button per row. iOS gets a "Permissions" row in the Settings tab → same sheet. Status updates on sheet dismiss (re-reads actual authorization). Phase 6's full Settings UI (CLOUD-01) will fold this sheet into a tab.

### Claude's Discretion

- **iOS sandbox `tmp/recordings/` path** — exact subfolder path inside the app's sandbox for active recordings. `tmp/` is conventional; iOS may purge it under storage pressure (acceptable since recordings are short-lived — moved to `_inbox/` within seconds of Stop).
- **`shortUUID` format** — 4-character hex suffix (`a3f8`) vs. 8-character vs. full UUID. Planner picks; shorter is fine for collision avoidance at Angelica's scale.
- **AVAudioSession category specifics** — exact category/option/mode combination for iOS lecture recording. Likely `.playAndRecord` with `.defaultToSpeaker` and `.allowBluetoothA2DP` (for AirPods), mode `.default` or `.spokenAudio`. Planner verifies against Apple docs and tests on Angelica's iPhone.
- **`Info.plist` keys** — `NSMicrophoneUsageDescription`, `NSCalendarsUsageDescription`, `UIBackgroundModes: ["audio"]`. Planner writes the actual strings; Phase 5 plan must include them.
- **`MPNowPlayingInfoCenter` artwork / metadata** — what artwork (if any) shows on lock screen. App icon is the obvious choice; planner decides if more is needed.
- **Queue processor persistence** — is the FIFO queue in-memory (lost on app quit) or persisted to disk? In-memory is simpler; launch scan (TRIG-01) recovers any files the queue lost. Persists to `.unibrain/queue.json` if Angelica expects "Resume processing after restart" semantics. Planner picks.
- **Backoff schedule** — 30s/2min/10min was suggested; planner can adjust based on observed iCloud flake patterns. Max retry count (3) can also be tuned.
- **Dead-letter sidecar JSON schema** — exact field names and shape for `_failed/{filename}.error.json`. Should include enough for Greg to diagnose remotely.
- **Welcome page content** — exact copy/branding for the Welcome page. Probably app icon + "unibrain" + one-line value prop ("Every recording lands in the right course folder, automatically") + Get Started button.
- **Term input UI** — Phase 4 CT-01 stores `{ label, startDate, endDate }`. Onboarding Term page collects all three (label as TextField, dates as `DatePicker`). Default values: label empty (placeholder "e.g., Fall 2026"), startDate = today, endDate = today + 4 months. Planner refines.
- **macOS onboarding surface** — full window vs. sheet on first launch. Sheet is less intrusive (Angelica can dismiss and explore); window is more ceremonial. Either works.
- **iOS onboarding detection of "first run"** — `UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")`. Standard pattern.
- **Security-scoped bookmark lifecycle on iOS** — iOS bookmarks can become stale if the user renames/moves the folder in Files app. Planner researches re-prompt flow (likely: catch `URLError` on stale bookmark, re-run folder picker).

### Folded Todos

None — no pending todos in `.planning/STATE.md` §"Pending Todos" matched Phase 5 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Planning (in this repo)
- `.planning/PROJECT.md` — project definition, constraints, Key Decisions table. MacBook Neo A-series / macOS 26 Tahoe / 8GB / iOS 17 / iPhone model unknown constraints shape every Phase 5 decision. Assumption #2 (iCloud Drive syncs Angelica's vault between her devices) IS Phase 5 — this is the phase that proves or disproves it. The Out-of-Scope line "iPad-native capture" is confirmed (iPad uses the same TabView shell as iPhone but is not optimized).
- `.planning/REQUIREMENTS.md` §"Capture" — CAPT-03 (iOS background recording with `AVAudioSession` background audio mode + lock-screen recording indicator).
- `.planning/REQUIREMENTS.md` §"Onboarding" — ONBD-01 (first-run flow sequence), ONBD-04 (vault picker suggests iCloud Drive), ONBD-05 (permissions screen accessible post-onboarding).
- `.planning/REQUIREMENTS.md` §"Discipline" — DISC-04 (app survives iOS backgrounding during active recording), DISC-06 (iCloud Drive sync conflicts do not corrupt notes — atomic writes + schema_version).
- `.planning/ROADMAP.md` §"Phase 5: iOS Capture + iCloud Handoff + Onboarding" — phase goal, mode (mvp), depends-on (Phase 4), requirements, four success criteria.
- `.planning/STATE.md` §"Blockers/Concerns" — Apple Developer Program decision must be settled before first device build (Phase 5 needs to ship to Angelica's iPhone — TestFlight requires paid membership; IC-01 picker-only path keeps Phase 5 unblocked if Dev Program decision slips).

### Phase 1 CONTEXT (decisions carried forward)
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-05 (macOS 26 / iOS 17 deployment targets — unlocks `AVAudioSession` modern APIs, `EventKit.requestFullAccessToEvents`), D-07 (three SPM targets: `UnibrainCore` Foundation-only, `UnibrainProviders` macOS/iOS-only, `UnibrainApp` Xcode app), D-08 (test target split: `UnibrainProvidersTests` macOS-only — Phase 5 likely adds iOS-only tests in same target behind `#if os(iOS)` guards), D-09 (Xcode app target not SPM executable — multiplatform Xcode target), D-15..17 (four standalone provider protocols, `ProviderError`, single-shot async/throws APIs).

### Phase 2 CONTEXT (contracts Phase 5 wires)
- `.planning/phases/02-pure-pipeline-logic/02-CONTEXT.md` — A-03 (`.icloud` placeholder detection — AMENDED by IC-04 for the iCloud-handoff path specifically), A-04 (`NoteWriterError` enum — Phase 5 may extend with inbox-specific cases), A-05 (NoteWriter creates folder tree recursively — Phase 5's TRIG-03 move relies on this), O-01 (8-state `PipelineState` lifecycle), O-02 (`PipelineOrchestrator` actor — `.alreadyRunning` rejection enforces TRIG-02 serial queue), O-05 (`PipelineInputs` value type — Phase 5's queue processor constructs this per `_inbox/` file).

### Phase 3 CONTEXT (macOS surface that hosts Phase 5 additions)
- `.planning/phases/03-macos-capture-transcribe/03-CONTEXT.md` — P-08 (menu-bar popover is macOS primary recording surface — Phase 5 adds "Manage Permissions" button + iCloud-handoff progress display here), P-09 (popover layout — Phase 5 reuses components in iOS Record tab per IOS-04), P-13 (`~/Documents/Unibrain/` default vault root — Phase 5 onboarding picker overrides), P-15 (audio file alongside note — Phase 5's TRIG-03 move destinations use this path), P-16 (`_inbox/` RESERVED for Phase 5 iCloud handoff input — Phase 5 activates this folder), P-17..19 (background model download pattern — Phase 5 iPhone sandbox mirrors this for any iPhone-side model needs, though IC-01 keeps iPhone capture-only so likely N/A).

### Phase 4 CONTEXT (contracts Phase 5 activates on iOS)
- `.planning/phases/04-course-classification-smart-routing/04-CONTEXT.md` — M-01 (`.unibrain/courses.json` lives INSIDE vault so iCloud syncs mapping — Phase 5 relies on this for iOS inheritance per ONB-01), P-03 (iOS EventKit adapter shipped in `UnibrainProviders` behind `#if os(iOS)` guards, code-complete but untested — Phase 5 activates + tests on Angelica's iPhone), P-05 (verify `.fullAccess` explicitly — Phase 5 iOS permission flow must handle `.writeOnly` as denied), CT-01 (`currentTerm = { label, startDate, endDate }` schema — Phase 5 iOS inherits via `.unibrain/courses.json`), CT-03 (auto-detect term-end nudge — Phase 5 surfaces this in iOS Settings tab too), MP-01..05 (manual picker UI — Phase 5 surfaces this in iOS as a sheet from Record tab when CourseClassifier returns `.multiple`/`.none`).

### Existing Code (the assets Phase 5 extends)
- `UnibrainApp/UnibrainApp.swift` — Phase 1's app shell with `MenuBarExtra` (macOS-only). Phase 5 keeps macOS menu-bar surface and adds: (a) iOS `TabView` shell behind `#if os(iOS)`, (b) onboarding flow entry, (c) "Manage Permissions" sheet entry (ONB-04), (d) iCloud-handoff queue progress display in the popover.
- `UnibrainApp/ContentView.swift` — Phase 1's placeholder. Phase 5 either replaces with onboarding-or-main conditional view, or planner introduces new `OnboardingView`, `iOSTabView`, `PermissionsSheet` alongside.
- `Sources/UnibrainCore/Protocols/AudioTranscriber.swift` — Phase 3's `TranscriberRouter` conforms. Phase 5 doesn't add engines (iPhone is capture-only) but the Router is invoked when processing iPhone-originated files on macOS.
- `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` — unchanged in Phase 5. Whisper.cpp/SpeechAnalyzer still loads on macOS only.
- `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` — Phase 5 may extend with iOS-capture metadata (e.g., `source_device: iphone`). Planner picks; `source` field already exists from Phase 2.
- `Sources/UnibrainCore/Errors/ProviderError.swift` — Phase 5 likely extends with `.iCloudDownloadTimedOut`, `.iCloudSyncConflict` (if not already present), or planner creates a separate `InboxWatcherError` enum.
- `Package.swift` — Phase 5 may add new source files to `UnibrainApp` (iOS shell views) and `UnibrainProviders` (iOS EventKit adapter was already added in Phase 4 per P-03 — Phase 5 just verifies it compiles and works on device).

### External Documentation (consult during planning)
- [AVAudioRecorder (Apple Developer)](https://developer.apple.com/documentation/avfaudio/avaudiorecorder) — iPhone recording API.
- [AVAudioSession (Apple Developer)](https://developer.apple.com/documentation/avfaudio/avaudiosession) — category/mode for iOS background recording.
- [WWDC25: Enhance your app's audio recording capabilities](https://developer.apple.com/videos/play/wwdc2025/251/) — latest 2025 audio recording guidance.
- [UIBackgroundModes (Apple Developer)](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes) — `audio` mode for background recording (CAPT-03, DISC-04).
- [MPNowPlayingInfoCenter (Apple Developer)](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter) — lock-screen Now Playing metadata (IOS-02).
- [MPRemoteCommandCenter (Apple Developer)](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter) — lock-screen remote commands for Stop/Pause (IOS-02).
- [NSMetadataQuery (Apple Developer)](https://developer.apple.com/documentation/foundation/nsmetadataquery) — iCloud-aware file watcher (TRIG-01).
- [URL.startDownloadingUbiquitousItem() (Apple Developer)](https://developer.apple.com/documentation/foundation/url/startdownloadingubiquitousitem()) — trigger iCloud download for placeholder files (IC-04).
- [Ubiquitous Item Download Status (Apple Developer)](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemdownloadingstatuskey) — poll download progress.
- [UIDocumentPickerViewController (Apple Developer)](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller) — iOS folder picker (ONB-03).
- [SwiftUI fileImporter (Apple Developer)](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncancel:)) — SwiftUI wrapper for folder picker (ONB-03).
- [NSOpenPanel (Apple Developer)](https://developer.apple.com/documentation/appkit/nsopenpanel) — macOS folder picker (ONB-03).
- [Security-scoped bookmarks (Apple Developer)](https://developer.apple.com/documentation/foundation/url#2870281) — persist folder access across launches (ONB-03).
- [TabView (Apple Developer)](https://developer.apple.com/documentation/swiftui/tabview) — iOS app shell (IOS-01).
- [EKEventStore.requestFullAccessToEvents(completion:) (Apple Developer)](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)) — iOS 17+ permission API (Phase 4 P-03 adapter uses this; Phase 5 verifies on device).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Phase 3 macOS menu-bar popover** — `UnibrainApp/UnibrainApp.swift`'s `MenuBarExtra` content. Phase 5 adds "Manage Permissions" button + iCloud-handoff progress display ("Downloading iPhone recording…", "Queue: 2 pending", "Failed: see _failed/").
- **Phase 3 recording UI components** (timer, waveform, mic meter, Pause/Stop buttons) — Phase 5's iOS Record tab reuses these scaled up (IOS-04).
- **Phase 3 `TranscriberRouter` + `PipelineOrchestrator`** — unchanged. Phase 5's macOS queue processor invokes the orchestrator once per `_inbox/` file.
- **Phase 4 iOS EventKit adapter** in `Sources/UnibrainProviders/` — already compiles behind `#if os(iOS)` (Phase 4 P-03). Phase 5 runs it on Angelica's iPhone for the first time.
- **Phase 4 `.unibrain/courses.json` + `currentTerm` schema** — Phase 5 iOS reads this from the picked iCloud Drive folder to inherit config (ONB-01).
- **Phase 2 `NoteWriterError`** — Phase 5 extends or siblings with `.iCloudDownloadTimedOut` (or similar) for the active-download path.

### Established Patterns
- **Swift 6 strict concurrency** (`actor`, `Sendable`, `async/await`) — Phase 5's queue processor actor, audio session delegate, and metadata query handlers all use these idioms.
- **Protocol-abstraction layer** — Phase 5 doesn't add new protocols (IC-01 picker-only keeps iCloud interactions at the file-system level, not protocol-abstracted). The `NoteWriter` and `AudioTranscriber` protocols stay as-is.
- **`#if os(macOS)` / `#if os(iOS)` guards** — Phase 5 adds many of these in `UnibrainApp` (TabView is iOS-only, MenuBarExtra is macOS-only, onboarding flow has platform branches).
- **Acquire/release lease** for shared-resource gating — Phase 5 doesn't need ModelLoadGate (iPhone is capture-only; macOS loads models for processing but that's Phase 3's existing pattern).
- **swift-testing framework** — Phase 5's iOS tests (if any — likely limited since most iOS code is UI/platform-specific) use `@Test`, `#expect`. macOS tests in `UnibrainProvidersTests` can test the queue processor and NSMetadataQuery logic via mocks.
- **macOS CI matrix** — `macos-15` runner (Xcode 16.x) is current. iOS tests would require an iOS Simulator step in CI (`xcodebuild test -destination 'platform=iOS Simulator,...'`). Planner evaluates whether to add an iOS Simulator job to `ci.yml` or defer iOS testing to manual device-only.

### Integration Points
- **`UnibrainApp`** is the consumer-facing entry point. Phase 5 adds: iOS TabView shell, onboarding flow, Permissions sheet, queue progress UI in macOS popover.
- **`PipelineOrchestrator.run(inputs:)`** — Phase 5's macOS queue processor constructs `PipelineInputs` per `_inbox/` file (with `events` fetched via Phase 4's EventKit adapter on macOS) and invokes.
- **`{vault}/_inbox/`** — Phase 5 activates this reserved folder (Phase 3 P-16). Pipeline reads from here, moves to `{vault}/{term}/{course}/` on success.
- **`{vault}/.unibrain/courses.json`** — Phase 5 reads on app launch (both platforms) to inherit currentTerm and course mapping; macOS writes via Phase 4 auto-learn/manual pick; iOS reads via iCloud sync.
- **`.github/workflows/ci.yml`** — Phase 5 may add an iOS Simulator job (`xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 15'`). Planner decides based on complexity vs. value (most Phase 5 code is platform-specific UI that's hard to unit-test).
- **Entitlements / Info.plist** — Phase 5 must add `UIBackgroundModes: ["audio"]`, `NSMicrophoneUsageDescription`, `NSCalendarsUsageDescription` to iOS Info.plist. macOS entitlements may need `com.apple.security.files.user-selected.read-write` (already standard for sandboxed Mac apps). Planner verifies.

</code_context>

<specifics>
## Specific Ideas

- **Picker-only (IC-01) is the keystone architectural decision.** It avoids blocking Phase 5 on the Apple Developer Program decision (still deferred per Phase 1 D-01). If Angelica/Greg later activate the paid membership, Phase 6 can add an iCloud container as a "zero-setup" alternative — but Phase 5 ships without it. The tradeoff: Angelica must pick the SAME iCloud Drive folder on both devices (macOS first, then iPhone) for config inheritance to work.
- **iPhone-capture-only (success criterion #2 implicit contract) preserves iPhone battery.** Angelica's iPhone model is unknown (PROJECT.md D-04). Running whisper.cpp on iPhone would be a battery/RAM disaster. Offloading all transcription to macOS via iCloud sync is the right architecture — iPhone is a discreet capture device, MacBook is the workstation. This also means Angelica's iPhone NEVER needs the `small.en` model download (Phase 3 P-17) — saving ~466MB of iPhone storage.
- **The serial FIFO queue (TRIG-02) is the right concurrency model given Phase 2 O-02.** Phase 2 locked the orchestrator to reject concurrent runs. Phase 5 honors that by serializing. The cost: back-to-back lectures processing time stacks (2 recordings × ~2min each = ~4min total). Acceptable for Angelica's schedule.
- **Active-download-with-wait (IC-04) amends Phase 2 A-03 in a Phase-5-specific way.** Phase 2's contract was "hard-error on .icloud placeholder." Phase 5 introduces a legitimate case where placeholders are expected (iPhone handoff) and the app should actively download them. The amendment is scoped to the iCloud-handoff path; non-iCloud destinations keep Phase 2's hard-error behavior. Planner must make this distinction explicit in the NoteWriter protocol or its conformances.
- **macOS-first onboarding (ONB-01) reflects the real-world setup sequence.** Angelica opens her MacBook first (it's the more capable device). iPhone onboarding is shorter because most config inherits via `.unibrain/courses.json`. This is a meaningful UX win — iPhone setup takes maybe 3 taps instead of 6.
- **The Dedicated Permissions sheet (ONB-04) is the Phase 5 minimum for ONBD-05.** Phase 6 will build the full Settings UI (CLOUD-01). Phase 5 ships just enough to let Angelica audit/re-grant permissions without re-running the whole onboarding flow. The sheet is a SwiftUI `View` that will become a tab in Phase 6's Settings window.
- **Retry-with-backoff (TRIG-04) is queue-level, NOT provider-level.** This is a deliberate separation: the queue retries the WHOLE pipeline run (download → transcribe → classify → write). Phase 6's CLOUD-10 will retry individual provider CALLS (e.g., a transient OpenAI 429). The two retry layers compose cleanly: queue-level retries recover from filesystem/iCloud/transient-pipeline errors; provider-level retries recover from network/API errors. Planner must keep these distinct.
- **The `_inbox/_failed/` dead-letter folder** is invisible to Angelica unless she opens the vault in Obsidian or Finder. The popover's "Failed: see _failed/" indicator surfaces it. Greg (as developer) can inspect `_failed/*.error.json` sidecars remotely when Angelica reports issues.
- **iPad uses the iPhone TabView shell.** PROJECT.md Out-of-Scope confirms "iPad-native capture" is not in MVP, but the TabView shell will run on iPad (SwiftUI multiplatform). iPad becomes a view/sync surface with accidental capture capability. Acceptable for MVP.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The following items were considered but explicitly belong in other phases:

- **Full Settings UI (per-modality LLM/ASR/Vision/TTS provider selectors, API key entry, audit trail)** → Phase 6 (CLOUD-01..13). Phase 5's Settings tab is a placeholder with only the Permissions sheet entry.
- **iCloud container (`NSUbiquitousContainers`) as zero-setup alternative** → Phase 6 polish OR a later phase if Apple Dev Program is activated. Phase 5 ships picker-only (IC-01).
- **Live Activity / Dynamic Island recording indicator** → Phase 6 polish. Phase 5 ships Now Playing + remote commands only (IOS-02).
- **iPad-optimized sidebar layout** → v2. PROJECT.md Out of Scope. Phase 5 iPad uses iPhone TabView as-is.
- **iPhone transcription (SpeechAnalyzer on-device)** → v2. Phase 5 iPhone is capture-only (success criterion #2).
- **Cloud ASR providers (OpenAI Whisper-1, etc.)** → Phase 6 (CLOUD-03..06). Phase 5 uses Phase 3's local engines (SpeechAnalyzer primary, whisper.cpp fallback) on macOS.
- **Background-task upload of audio to iCloud via `BGProcessingTask`** → Phase 5 uses foreground move-on-Stop (IC-02); background upload is unnecessary since AVAudioRecorder writes to sandbox and the move happens synchronously on Stop. If Stop is interrupted (app killed), the file stays in sandbox and is moved on next app launch (TRIG-01 launch scan logic extended to sandbox).
- **AirDrop as fallback when iCloud Drive unavailable** → Phase 6 polish or v2. Phase 5 requires iCloud Drive (IC-01) — if iCloud is unavailable, iPhone recordings stay on iPhone and Angelica manually AirDrops (out of scope to automate in MVP).
- **Multi-iPhone support (e.g., Angelica + Isabella both recording)** → v2. PROJECT.md single-user mandate.
- **iCloud Drive sync conflict UI** → Phase 5 relies on Phase 2 DISC-06 (atomic writes + schema_version) and surfaces conflicts as NoteWriterError. Phase 6 can add a dedicated conflict resolver UI if real-world usage reveals it's needed.
- **Cloud audio storage** → Out of Scope per PROJECT.md (audio lives in vault; iCloud syncs between Angelica's devices only).
- **Apple Watch companion app** → v2. IOS-02's `MPRemoteCommandCenter` enables Apple Watch as a remote control surface for free (no WatchKit needed).
- **Action Button / Lock Screen widget one-tap trigger (CAPT-07)** → v2 per REQUIREMENTS.md v2 list. Phase 5 captures via the Record tab.
- **Hands-free bookmark during recording (CAPT-08)** → v2.
- **Audio-transcript playback sync (CAPT-09)** → v2.

### Reviewed Todos (not folded)

None — no todos existed in `.planning/STATE.md` §"Pending Todos" at discussion time.

</deferred>

---

*Phase: 5-iOS Capture + iCloud Handoff + Onboarding*
*Context gathered: 2026-07-14*
