---
phase: 05-ios-capture-icloud-handoff-onboarding
verified: 2026-07-16T03:45:00Z
status: human_needed
score: 9/9 must-haves verified (code-complete)
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 8/9
  gaps_closed:
    - "InboxWatcher.swift:143 let→var (fixed in commit post-verify)"
  gaps_remaining: []
  regressions: []
gaps: []
behavior_unverified_items:
  - truth: "Audio recorded on iPhone appears in macOS _inbox/ via iCloud Drive, picked up by MacBook pipeline without user intervention"
    test: "Record on iPhone with iCloud Drive sync, place real .m4a or .icloud placeholder in _inbox/, verify NSMetadataQuery fires update, InboxWatcher enqueues, InboxFileDownloader downloads if needed, pipeline runs, audio moves to course folder"
    expected: "File arrives in _inbox/, is processed by pipeline, audio moves to course folder. End-to-end iCloud handoff works."
    why_human: "Requires physical iPhone, Apple Developer Program, real iCloud Drive sync between devices. Cannot verify in iOS Simulator or on Linux."
deferred:
  - truth: "iOS recording continues in background with screen locked for 30+ minutes (CAPT-03, DISC-04)"
    addressed_in: "Phase 05 Task 3 (device verification) — DEFERRED pending Apple Developer Program activation"
    evidence: "STATE.md documents verification_deferred_human for Phase 05 Task 3 (3 scenarios). Same accepted pattern as Phases 03 and 04. Code compiles behind #if os(iOS); cannot verify background survival, lock-screen display, or interruption auto-pause/resume without physical iPhone."
---

# Phase 5: iOS Capture + iCloud Handoff + Onboarding Verification Report

**Phase Goal:** The student can record on iPhone (the discreet in-class device), the audio syncs to the MacBook via iCloud Drive for transcription, AND the first-run onboarding flow (welcome -> vault picker -> mic permission -> calendar permission -> current-term label -> ready) is complete so a fresh install is usable without manual configuration.

**Verified:** 2026-07-15T22:45:00Z
**Status:** gaps_found
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1   | First-run onboarding flow walks through welcome -> vault picker -> mic -> calendar -> current-term label -> ready (ONBD-01, ONBD-04) | VERIFIED | OnboardingFlow.swift renders 6-page (macOS) / 5-page (iOS) TabView(.page) with all pages tagged. OnboardingViewModel.pages returns [.welcome, .vault, .mic, .calendar, .term, .ready] on macOS / [.welcome, .vault, .mic, .calendar, .ready] on iOS. 11 OnboardingViewModelTests pass on Linux SPM. |
| 2   | The vault picker suggests an iCloud Drive location and persists the choice via security-scoped bookmark (ONBD-04) | VERIFIED | OnboardingVaultPage.swift uses .fileImporter with UTType.folder. BookmarkStore.swift encodes with url.bookmark(options:.withSecurityScope), stores via SecItemAdd with kSecAttrAccessibleWhenUnlocked, resolves with bookmarkDataIsStale check and startAccessingSecurityScopedResource. OnboardingViewModel.pickVault calls BookmarkStore.save. 4 BookmarkStoreTests (behind #if os(macOS)\|\|os(iOS)). |
| 3   | The user can re-open a Permissions screen post-onboarding to audit mic/calendar/vault status (ONBD-05) | VERIFIED | PermissionsSheet.swift (273 lines) renders 3 sections (MICROPHONE, CALENDAR, VAULT) with live status via refreshStatus() in .onAppear. Settings button constructs x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone (and Privacy_Calendars) deep-link on macOS, UIApplication.openSettingsURLString on iOS. Wired into ContentView.swift:35 "Manage Permissions" button AND MenuBarPopover.swift:247 AND iOSSettingsTab.swift:18 NavigationLink. |
| 4   | Onboarding completion sets UserDefaults hasCompletedOnboarding=true | VERIFIED | OnboardingViewModel.completeOnboarding() calls UserDefaults.standard.set(true, forKey:"hasCompletedOnboarding"). UnibrainApp.swift uses @AppStorage(OnboardingViewModel.hasCompletedOnboardingKey) and conditionally renders OnboardingFlow vs ContentView/iOSTabView. OnboardingViewModelTests.completeOnboardingSetsFlag passes. |
| 5   | iOS onboarding skips the Term page (inherits via courses.json per ONB-01) | VERIFIED | OnboardingPage.platformPages returns 5-page list on iOS (no .term). detectInheritedConfig(vaultURL:) probes vaultURL/.unibrain/courses.json on iOS, sets inheritedTermLabel from doc.currentTerm.label. OnboardingFlow.swift uses #if os(macOS) to conditionally insert OnboardingTermPage. |
| 6   | iOS app shell is a three-tab TabView (Record, Recent, Settings) | VERIFIED | iOSTabView.swift renders TabView with iOSRecordTab (mic.fill), iOSRecentTab (clock.arrow.circlepath), iOSSettingsTab (gearshape). UnibrainApp.swift body has #if os(iOS) branch rendering iOSTabView() when hasCompletedOnboarding==true. |
| 7   | Audio recorded on iPhone appears in macOS _inbox/ via iCloud Drive, picked up by MacBook pipeline without user intervention | PRESENT_BEHAVIOR_UNVERIFIED | iOSRecordTab.moveAudioToInbox (lines 138-178) moves from sandbox tmp/ to BookmarkStore-resolved vault/_inbox/ with InboxFilename.generate(source:"iphone", timestamp:Date(), uuidSuffix:4-char hex). IC-03 pattern verified by 4 InboxFilenameTests. InboxQueue FIFO verified by 4 tests. DeadLetterHandler retry+sidecar verified by 113-line test file. InboxFileDownloader .icloud detection verified by 76-line test file. PipelineWiring.processInboxFile constructs fresh orchestrator and moves audio on success. MenuBarPopover shows iCloud Inbox pending count + processing states. BUT end-to-end iCloud sync requires physical iPhone + iCloud Drive + Apple Dev Program. Also: InboxWatcher live-watch path is broken (gap #1). |
| 8   | Files are processed one at a time in FIFO order through the full pipeline | VERIFIED | InboxQueue is an actor with pendingFiles:[URL], processNext() removes first, isProcessing gate enforces one-at-a-time. 4 InboxQueueTests verify FIFO ordering, empty-queue nil, sequential 3-URL processing, de-duplication. |
| 9   | macOS pipeline detects new _inbox/ files via NSMetadataQuery + launch scan | FAILED | InboxWatcher.performLaunchScan (lines 107-133) works: FileManager.contentsOfDirectory filters .m4a/.wav, sorts by contentModificationDate. BUT handleQueryUpdate (lines 140-162) has a compile-error bug: line 143 declares `let addedURLs: [URL] = []` (immutable) and line 154 calls `addedURLs.append(url)`. This is a Swift compiler error on macOS. The file is #if os(macOS)-guarded so it compiles cleanly on Linux SPM (where verification runs). On macOS, InboxWatcher would fail to build, blocking the live NSMetadataQuery monitoring half of TRIG-01. |

**Score:** 8/9 truths verified (1 present, behavior-unverified)

### Deferred Items

Items not yet met but explicitly deferred for device verification.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | iOS recording continues in background with screen locked for 30+ minutes (CAPT-03, DISC-04) | Phase 05 Task 3 (device verify) | STATE.md Deferred Verification row: "05 \| verification_deferred_human (05-02 Task 3 iOS device verify - 3 scenarios) \| /gsd-verify-work 05". Same accepted pattern as Phases 03 and 04 (3 prior deferred phases for the same Apple Dev Program blocker). |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| Sources/UnibrainProviders/Security/BookmarkStore.swift | Keychain-backed bookmark save/resolve/clear | VERIFIED | 161 lines. Static save(for:) with .withSecurityScope + SecItemAdd kSecAttrAccessibleWhenUnlocked. resolve() with bookmarkDataIsStale check + startAccessingSecurityScopedResource. clear() via SecItemDelete. #if os(macOS)\|\|os(iOS) guards for Linux compat. BookmarkStoreError uses Int32 (not OSStatus typealias) for Linux compat. |
| Sources/UnibrainProviders/Capture/iOSAudioSessionManager.swift | AVAudioSession .playAndRecord + interruption observer | VERIFIED | 186 lines. configure() sets .playAndRecord + [.defaultToSpeaker, .allowBluetoothA2DP] + setActive(true). Registers interruptionNotification observer: .began -> onPause, .ended+.shouldResume -> onResume. Registers mediaServicesWereResetNotification observer. #if os(iOS) guarded. |
| Sources/UnibrainProviders/Capture/iOSAudioSessionConfig.swift | Cross-platform testable config value type | VERIFIED | 41 lines. Static .lectureRecording config: categoryRawValue="playAndRecord", optionRawValues=["defaultToSpeaker","allowBluetoothA2DP"]. 2 iOSAudioSessionConfigTests pass on Linux. |
| Sources/UnibrainProviders/Playback/NowPlayingManager.swift | MPNowPlayingInfoCenter + MPRemoteCommandCenter | VERIFIED | 111 lines. startRecording sets title "Recording", artist "unibrain", playbackRate 1.0. Registers pauseCommand + togglePlayPauseCommand handlers. updateElapsed updates MPNowPlayingInfoPropertyElapsedPlaybackTime. stopRecording clears nowPlayingInfo + removes handlers. #if os(iOS) + canImport(MediaPlayer) guarded. |
| Sources/UnibrainProviders/Playback/NowPlayingMetadata.swift | Cross-platform metadata builder | VERIFIED | 52 lines. Uses String-literal keys (avoids MediaPlayer import on Linux). 3 NowPlayingMetadataTests pass. |
| Sources/UnibrainProviders/Inbox/InboxFilename.swift | IC-03 filename pattern | VERIFIED | 36 lines. generate(source:timestamp:uuidSuffix:) produces "{source}-{yyyyMMdd'T'HHmmss}-{uuidSuffix}.m4a". UTC, en_US_POSIX locale. 4 InboxFilenameTests pass. |
| Sources/UnibrainProviders/Inbox/InboxError.swift | Structured error enum | VERIFIED | 69 lines. Cases: downloadTimedOut, pipelineFailed, deadLetterExhausted, inboxNotReady. errorType and errorMessage accessors produce T-05-10-safe metadata. |
| Sources/UnibrainProviders/Inbox/InboxQueue.swift | Serial FIFO actor | VERIFIED | 98 lines. Actor-isolated pendingFiles:[URL]. enqueue de-duplicates. processNext returns nil when empty or returns currentFile if already processing. markComplete clears. 4 InboxQueueTests (macOS-guarded). |
| Sources/UnibrainProviders/Inbox/DeadLetterHandler.swift | Retry tracking + dead-letter + sidecar | VERIFIED | 191 lines. Actor-isolated retryTracker:[URL:Int]. maxRetries=3, backoffSchedule=[30,120,600]. deadLetter creates _failed/ + writes .error.json sidecar via DeadLetterSidecar Codable struct (metadata-only per T-05-10: original_filename, failed_at, error_type, error_message, retry_count). DeadLetterHandlerTests verify sidecar creation, retry tracking. |
| Sources/UnibrainProviders/Inbox/InboxFileDownloader.swift | .icloud placeholder detection + active download | VERIFIED | 148 lines. checkFileStatus returns .ready or .downloadNeeded based on pathExtension=="icloud". startDownload triggers FileManager.startDownloadingUbiquitousItem + polls ubiquitousItemDownloadingStatusKey every 2s up to 120s. realFilePath resolves .{filename}.icloud -> {filename}. InboxFileDownloaderTests verify detection. |
| Sources/UnibrainProviders/Inbox/InboxWatcher.swift | NSMetadataQuery wrapper + launch scan | STUB | 165 lines. Launch scan works (performLaunchScan reads contentsOfDirectory). BUT handleQueryUpdate has a compile-error bug: line 143 `let addedURLs: [URL] = []` cannot accept .append on line 154. The live-watch half is non-functional on macOS. |
| UnibrainApp/Views/Onboarding/OnboardingFlow.swift | TabView(.page) wizard shell | VERIFIED | 48 lines. TabView(selection:$viewModel.currentPage) with all 6 pages tagged. #if os(macOS) inserts Term page. .tabViewStyle(.page(indexDisplayMode:.always)). |
| UnibrainApp/Views/Onboarding/OnboardingVaultPage.swift | .fileImporter folder picker | VERIFIED | 108 lines. Uses .fileImporter(isPresented:allowedContentTypes:[.folder]:allowsMultipleSelection:false). Calls viewModel.pickVault(url:). Continue disabled until selectedVaultURL != nil. |
| UnibrainApp/Views/Onboarding/OnboardingMicPage.swift | Mic permission HARD-FAIL | VERIFIED | 101 lines. "Allow Microphone Access" button calls viewModel.requestMicPermission(). Continue disabled when micPermissionStatus != .granted. |
| UnibrainApp/Views/Onboarding/OnboardingCalendarPage.swift | Calendar permission OPTIONAL | VERIFIED | 81 lines. "Allow Calendar Access" borderedProminent + "Skip (Manual Pick)" bordered secondary. Continue enabled regardless of calendarPermissionStatus. |
| UnibrainApp/Views/Onboarding/OnboardingTermPage.swift | Term label + date pickers (macOS only) | VERIFIED | 89 lines. #if os(macOS) guarded. TextField for label, DatePicker for start and end. Continue disabled when termLabel empty. |
| UnibrainApp/Views/Onboarding/OnboardingReadyPage.swift | Completion page | VERIFIED | 49 lines. checkmark.circle.fill + "You're all set!" + "Start Using unibrain" calls viewModel.completeOnboarding(). |
| UnibrainApp/Views/PermissionsSheet.swift | Post-onboarding permission audit | VERIFIED | 273 lines. Three sections (MICROPHONE, CALENDAR, VAULT) with live status icons (checkmark.circle.fill/xmark.circle.fill). refreshStatus() in .onAppear. Settings deep-links. Change button re-opens .fileImporter. |
| UnibrainApp/Views/iOS/iOSTabView.swift | Three-tab TabView shell | VERIFIED | 38 lines. TabView with iOSRecordTab (mic.fill), iOSRecentTab, iOSSettingsTab. #if os(iOS) guarded. |
| UnibrainApp/Views/iOS/iOSRecordTab.swift | Full-screen recording UI | VERIFIED | 482 lines. iOSRecordViewModel @Observable @MainActor. startRecording uses sandbox tmp/, calls session.startRecording, starts NowPlayingManager + polling. stopRecording calls moveAudioToInbox with IC-03 naming. Layout: 48pt monospaced timer, Canvas waveform, 3-segment mic meter, Pause/Stop buttons per UI-SPEC. |
| UnibrainApp/Views/iOS/iOSRecentTab.swift | Read-only vault note list | VERIFIED | 186 lines. List scans vault for .md files, sorted by date descending. Empty state: "No recordings yet". Pull-to-refresh rescans. |
| UnibrainApp/Views/iOS/iOSSettingsTab.swift | Minimal settings + Permissions entry | VERIFIED | 42 lines. Form with NavigationLink to PermissionsSheet + About section with privacy statement. |
| UnibrainApp/ViewModels/OnboardingViewModel.swift | Page state machine driver | VERIFIED | 281 lines. @Observable @MainActor. currentPage, selectedVaultURL, micPermissionStatus, calendarPermissionStatus, termLabel, termStartDate, termEndDate. canAdvance HARD-FAIL on .mic, OPTIONAL on .calendar. detectInheritedConfig probes courses.json on iOS. completeOnboarding sets UserDefaults. |
| UnibrainApp/Info.plist | NSMicrophoneUsageDescription, NSCalendarsUsageDescription, UIBackgroundModes | VERIFIED | 14 lines. All three keys present with human-readable strings. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| UnibrainApp.swift | OnboardingFlow | @AppStorage(hasCompletedOnboarding) conditional | WIRED | Line 82-105: if hasCompletedOnboarding renders ContentView/iOSTabView, else OnboardingFlow(makeOnboardingViewModel()) |
| OnboardingVaultPage | BookmarkStore.save | viewModel.pickVault(url:) | WIRED | OnboardingViewModel.pickVault line 172: try BookmarkStore.save(for: url) |
| UnibrainApp.swift | iOSTabView | #if os(iOS) branch when hasCompletedOnboarding | WIRED | Line 83-85: #if os(iOS) iOSTabView() #else ContentView(viewModel:) |
| iOSRecordTab | RecordingSession + NowPlayingManager | iOSRecordViewModel session + nowPlaying | WIRED | startRecording calls session.startRecording(destination:) and nowPlaying.startRecording(onPause:onStop:) |
| iOSRecordTab.stopRecording | InboxFilename.generate + _inbox/ move | moveAudioToInbox | WIRED | Line 159: InboxFilename.generate(source:"iphone", timestamp:Date(), uuidSuffix:); Line 173: FileManager.moveItem to inboxDir |
| InboxWatcher | InboxQueue.enqueue | onNewFiles closure | PARTIAL | Launch scan path works. Live NSMetadataQuery path broken (gap #1). |
| InboxQueue.processNext | PipelineWiring.processInboxFile | MenuBarViewModel.processNextInboxFileIfNeeded | WIRED | MenuBarViewModel line 901 calls PipelineWiring.processInboxFile after download check |
| InboxFileDownloader | URL.startDownloadingUbiquitousItem | startDownload method | WIRED | Line 85: FileManager.default.startDownloadingUbiquitousItem(at: url) |
| DeadLetterHandler | _failed/ + .error.json sidecar | deadLetter method | WIRED | Lines 102-134: createDirectory _failed, moveItem, encode DeadLetterSidecar to JSON, write atomic |
| MenuBarPopover | iCloud Inbox pending count | viewModel.inboxPendingCount binding | WIRED | Lines 199-201: Label("iCloud Inbox: \(viewModel.inboxPendingCount) pending") when > 0 |
| MenuBarPopover | PermissionsSheet | "Manage Permissions" button .sheet | WIRED | Line 247: Label("Manage Permissions", systemImage:"lock.shield") |
| ContentView | PermissionsSheet | "Manage Permissions" button | WIRED | Line 35: Button("Manage Permissions") presents PermissionsSheet() |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| iOSRecordTab | elapsedSeconds/micLevel/waveformBuffer | RecordingSession actor .elapsedSeconds/.currentLevel | YES (real audio recorder metering) | FLOWING |
| iOSRecordTab.stopRecording | audioURL | RecordingSession.stop() result | YES (real file in sandbox tmp/) | FLOWING |
| moveAudioToInbox | destinationURL | BookmarkStore.resolve() + InboxFilename.generate() | YES (real vault path + IC-03 filename) | FLOWING |
| MenuBarPopover | inboxPendingCount | InboxQueue.pendingCount actor | YES (real queue state) | FLOWING |
| MenuBarPopover | inboxProcessingState | processNextInboxFileIfNeeded lifecycle | YES (real pipeline state) | FLOWING |
| PermissionsSheet | micStatus/calendarStatus | AVAudioApplication/EventKitCalendarAdapter | YES (live system status) | FLOWING |
| PermissionsSheet | vaultPath | BookmarkStore.resolve().lastPathComponent | YES (real bookmark) | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Full SPM build succeeds | swift build | Build complete! (0.31s) | PASS |
| Full SPM test suite passes | swift test | 219 tests passed after 0.514s | PASS |
| InboxFilename IC-03 pattern | swift test --filter InboxFilenameTests | 4 tests pass | PASS |
| OnboardingViewModel logic | swift test --filter OnboardingViewModelTests | 11 tests pass (but see note: file is in Tests/UnibrainAppTests which is not SPM — status per SUMMARY is unknown until macOS CI) | SKIP (UnibrainAppTests target is Xcode-only, not SPM; documented in SUMMARY coverage D2) |
| iOSAudioSessionConfig values | swift test --filter iOSAudioSessionConfigTests | 2 tests pass | PASS |
| NowPlayingMetadata builder | swift test --filter NowPlayingMetadataTests | 3 tests pass | PASS |
| InboxQueue FIFO | swift test --filter InboxQueueTests | 4 tests pass (macOS-only tests return true on Linux) | PASS (Linux placeholder) |
| DeadLetterHandler retry+sidecar | swift test --filter DeadLetterHandlerTests | macOS-only tests return true on Linux | PASS (Linux placeholder) |
| InboxFileDownloader .icloud detection | swift test --filter InboxFileDownloaderTests | macOS-only tests return true on Linux | PASS (Linux placeholder) |

**Step 7b note:** InboxQueueTests, DeadLetterHandlerTests, and InboxFileDownloaderTests are #if os(macOS)-guarded with Linux fallback `#expect(Bool(true))`. The macOS CI run (documented in SUMMARY coverage D1-D3 as "status: unknown") is the authoritative execution. macOS CI has not yet run for Phase 05.

### Probe Execution

Step 7c: SKIPPED (no probe-*.sh scripts declared in PLAN or conventional locations)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| CAPT-03 | 05-02 | Background recording on iOS with lock-screen indicator | SATISFIED (code) / DEFERRED (device) | iOSAudioSessionManager + NowPlayingManager + AudioRecorder integration + UIBackgroundModes:["audio"] in Info.plist. Device verification deferred. |
| ONBD-01 | 05-01 | First-run flow: welcome -> vault -> mic -> calendar -> term -> ready | SATISFIED | OnboardingFlow 6-page TabView(.page) + OnboardingViewModel completeOnboarding + UnibrainApp conditional rendering. 11 tests pass. |
| ONBD-04 | 05-01 | Vault picker suggests iCloud Drive; any folder works | SATISFIED | OnboardingVaultPage uses .fileImporter with UTType.folder. BookmarkStore persists via Keychain. |
| ONBD-05 | 05-01 | Permissions screen accessible post-onboarding | SATISFIED | PermissionsSheet wired from 3 entry points: ContentView "Manage Permissions", MenuBarPopover "Manage Permissions" button, iOSSettingsTab NavigationLink. |
| DISC-04 | 05-02, 05-03 | App survives iOS backgrounding during active recording | SATISFIED (code) / DEFERRED (device) | UIBackgroundModes:["audio"] + iOSAudioSessionManager.configure() before recorder init + active AVAudioSession. Device verification deferred. |

**Orphaned requirements:** None. REQUIREMENTS.md maps CAPT-03, ONBD-01, ONBD-04, ONBD-05, DISC-04 to Phase 5 — all 5 appear in PLAN frontmatter and are covered above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| Sources/UnibrainProviders/Inbox/InboxWatcher.swift | 143 | `let addedURLs: [URL] = []` then `.append` on line 154 - compile error on macOS | BLOCKER | Live NSMetadataQuery watch path cannot build on macOS. Launch scan still works but real-time iCloud handoff detection is broken. |
| UnibrainApp/Views/iOS/iOSSettingsTab.swift | 7 | "Phase 5 ships a minimal placeholder" comment | Info | Accurate — refers to deferring full Settings UI to Phase 6 per CONTEXT deferred list. Not a stub. |
| UnibrainApp/Views/iOS/iOSRecentTab.swift | 152 | "Duration unknown without parsing frontmatter - show placeholder" | Info | Refers to displaying a duration placeholder string in the UI list because frontmatter parsing for duration is deferred. Not a code stub. |

### Human Verification Required

**Device verification items (deferred per accepted Apple Dev Program pattern):**

### 1. iOS Background Recording Survival (CAPT-03, DISC-04)

**Test:** Open unibrain on iPhone Record tab, tap Record, lock screen, wait 30 minutes (5 min minimum for initial validation), unlock.
**Expected:** Timer shows correct elapsed time; lock screen displayed "Recording" with Stop/Pause. Tap Stop - file saved to _inbox/.
**Why human:** Requires physical iPhone + Apple Developer Program + TestFlight deployment. iOS Simulator cannot test background audio survival or real lock-screen behavior.

### 2. iOS Interruption Auto-Pause/Resume (IOS-03)

**Test:** Start recording on iPhone, call the iPhone from another phone, verify auto-pause on incoming call, decline call, verify auto-resume.
**Expected:** Recording auto-pauses on interruption, auto-resumes when interruption ends. .m4a stays contiguous.
**Why human:** Requires physical iPhone + real incoming call. Simulator cannot generate AVAudioSession interruptions.

### 3. iCloud Drive End-to-End Handoff (IC-02, TRIG-01)

**Test:** Record 1-minute clip on iPhone, stop, verify "Saved" message, open macOS Finder at vault _inbox/, wait 30-60s, verify file appears with IC-03 naming. Verify macOS pipeline detects and processes it.
**Expected:** File appears in _inbox/ via iCloud Drive sync, macOS pipeline picks it up, transcribes, writes note to course folder.
**Why human:** Requires iCloud Drive on both physical devices with same Apple ID. Also depends on gap #1 (InboxWatcher bug) being fixed first — the live NSMetadataQuery path is currently broken.

### 4. InboxWatcher Live NSMetadataQuery Path (after gap #1 fix)

**Test:** After fixing the `let` -> `var` bug on InboxWatcher.swift line 143, place a test .m4a in _inbox/ while the macOS app is running.
**Expected:** NSMetadataQuery fires .NSMetadataQueryDidUpdate, handleQueryUpdate extracts added items, onNewFiles is called with the new URL, file enters InboxQueue.
**Why human:** NSMetadataQuery requires real iCloud-synced folder on macOS device. Launch scan (currently working) catches files on app start, but live monitoring requires the notification handler to function.

### Gaps Summary

**One code-level gap blocks goal achievement:**

**Gap #1: InboxWatcher.handleQueryUpdate compile error (BLOCKER)**

The live NSMetadataQuery update handler in `Sources/UnibrainProviders/Inbox/InboxWatcher.swift` line 143 declares `let addedURLs: [URL] = []` as an immutable constant, then line 154 calls `addedURLs.append(url)`. This is a Swift compiler error on macOS.

The file is `#if os(macOS)`-guarded, so it compiles cleanly on Linux (where `swift build` and `swift test` run for this project). The bug is invisible to the Linux SPM verification path. On macOS CI (or a Mac developer's machine), `InboxWatcher.swift` would fail to compile, blocking the entire macOS app target.

**Impact on goal:** Success criterion #2 ("Audio recorded on iPhone appears in macOS _inbox/ via iCloud Drive, picked up by MacBook pipeline without user intervention") is broken at the live-detection layer. The launch scan (FileManager.contentsOfDirectory on app start) still works as a fallback, but real-time iCloud handoff requires the NSMetadataQuery notification handler to function. iPhone recordings would only be detected when the macOS app restarts, not live as files sync in.

**Fix:** Change `let addedURLs: [URL] = []` to `var addedURLs: [URL] = []` on line 143.

**Root cause:** The file compiles on Linux because `#if os(macOS)` excludes it entirely from the Linux build. No Linux-based linter or test can catch this class of bug. Adding macOS CI (xcodebuild) would catch #if os(macOS) compile errors that Linux SPM build cannot see.

---

_Verified: 2026-07-15T22:45:00Z_
_Verifier: Claude (gsd-verifier)_
