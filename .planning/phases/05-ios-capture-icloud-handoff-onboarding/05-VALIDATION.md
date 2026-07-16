---
phase: 5
slug: ios-capture-icloud-handoff-onboarding
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-15
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`) — existing from Phase 1 |
| **Config file** | `Package.swift` (test targets: `UnibrainCoreTests`, `UnibrainProvidersTests`, `UnibrainAppTests`) |
| **Quick run command** | `swift test --filter UnibrainProvidersTests` (Linux, ~5s) |
| **Full suite command** | `swift test` (macOS CI, ~30s) |
| **Estimated runtime** | ~30 seconds (Linux quick: ~5s; macOS full: ~30s) |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter UnibrainProvidersTests` (Linux) for fast feedback
- **After every plan wave:** Run `swift test` (full suite on macOS CI)
- **Before `/gsd-verify-work`:** Full suite must be green + manual device verification (CAPT-03/DISC-04 require physical iPhone)
- **Max feedback latency:** 30 seconds (Linux quick); ~5s for the targeted filters

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 5-01-01a | 01 | 1 | ONBD-04 | T-5-01 | Bookmark round-trip via Keychain (not UserDefaults) | unit | `swift test --filter BookmarkStoreTests` | ✅ | ⬜ pending |
| 5-01-01b | 01 | 1 | ONBD-01 | T-5-03 | Stale bookmark returns nil (no silent stale access) | unit | `swift test --filter BookmarkStoreTests` (case: stale) | ✅ | ⬜ pending |
| 5-01-02-build | 01 | 1 | ONBD-01 | — | Onboarding wizard compiles with page guards | build | `swift build 2>&1 \| tee /tmp/05-01-t2-build.log; test ${PIPESTATUS[0]} -eq 0` | N/A | ⬜ pending |
| 5-01-02-logic | 01 | 1 | ONBD-01, ONB-01 | — | OnboardingViewModel state machine (completeOnboarding toggles UserDefaults, advance() gating, iOS config inheritance) | unit | `swift test --filter OnboardingViewModelTests` | ❌ W0 | ⬜ pending |
| 5-01-02-manual | 01 | 1 | ONBD-01 | — | Onboarding pages render correctly (6 macOS, 5 iOS) | manual | See Manual-Only table below | N/A | ⬜ pending |
| 5-02-01-build | 02 | 2 | CAPT-03, IOS-03 | T-5-05 | iOSAudioSessionManager + NowPlayingManager compile behind #if os(iOS) | build | `swift build 2>&1 \| tee /tmp/05-02-t1-build.log; test ${PIPESTATUS[0]} -eq 0` | N/A | ⬜ pending |
| 5-02-01b-filename | 02 | 2 | IC-03 | T-5-07 | IC-03 filename pattern `{source}-{YYYYMMDDTHHMMSS}-{uuid}.m4a` | unit | `swift test --filter InboxFilenameTests` | ❌ W0 | ⬜ pending |
| 5-02-01b-config | 02 | 2 | IOS-03, CAPT-03 | T-5-05 | iOSAudioSessionConfig category=.playAndRecord, options=[.defaultToSpeaker, .allowBluetoothA2DP] | unit | `swift test --filter iOSAudioSessionConfigTests` | ❌ W0 | ⬜ pending |
| 5-02-01b-metadata | 02 | 2 | IOS-02 | T-5-06 | NowPlayingMetadata builder produces MPMediaItemPropertyTitle + MPNowPlayingInfoPropertyPlaybackRate=1.0 | unit | `swift test --filter NowPlayingMetadataTests` | ❌ W0 | ⬜ pending |
| 5-02-02-build | 02 | 2 | IOS-01, IC-02 | — | iOSTabView + iOSRecordTab + iOSRecentTab + iOSSettingsTab compile; pipeline macOS-only code guarded | build | `swift build 2>&1 \| tee /tmp/05-02-t2-build.log; test ${PIPESTATUS[0]} -eq 0` | N/A | ⬜ pending |
| 5-02-03-device-bg | 02 | 2 | CAPT-03, DISC-04 | T-5-05 | Background recording survives 30+ min locked screen | manual | See Manual-Only table below | N/A | ⬜ pending |
| 5-02-03-device-interrupt | 02 | 2 | IOS-03 | T-5-05 | Phone call interruption auto-pauses + auto-resumes | manual | See Manual-Only table below | N/A | ⬜ pending |
| 5-02-03-device-icloud | 02 | 2 | IC-02 | T-5-07 | iPhone recording lands in macOS _inbox/ via iCloud Drive | manual | See Manual-Only table below | N/A | ⬜ pending |
| 5-03-01-queue | 03 | 3 | TRIG-02 | T-5-11 | FIFO queue: first-enqueued is first-returned by processNext; returns nil when empty | unit | `swift test --filter InboxQueueTests` | ❌ W0 | ⬜ pending |
| 5-03-01-deadletter | 03 | 3 | TRIG-04 | T-5-10 | Retry 3x then dead-letter to _failed/ with JSON sidecar (no transcript/audio leak) | unit | `swift test --filter DeadLetterHandlerTests` | ❌ W0 | ⬜ pending |
| 5-03-01-downloader | 03 | 3 | IC-04 | — | .icloud placeholder -> .downloadNeeded; real .m4a -> .ready | unit | `swift test --filter InboxFileDownloaderTests` | ❌ W0 | ⬜ pending |
| 5-03-02-build | 03 | 3 | TRIG-01, TRIG-03 | — | InboxWatcher + PipelineWiring.processInboxFile + popover UI compile | build | `swift build 2>&1 \| tee /tmp/05-03-t2-build.log; test ${PIPESTATUS[0]} -eq 0` | N/A | ⬜ pending |
| 5-03-02-manual | 03 | 3 | TRIG-01 | — | NSMetadataQuery detects real iCloud-synced file in _inbox/ | manual | See Manual-Only table below | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 0 files MUST be created by the first task of the owning plan before the rest of the task's work proceeds.

- [ ] `Tests/UnibrainProvidersTests/Security/BookmarkStoreTests.swift` — stubs for ONBD-04 (created by 05-01 Task 1)
- [ ] `Tests/UnibrainAppTests/Onboarding/OnboardingViewModelTests.swift` — stubs for ONBD-01/ONB-01 (created by 05-01 Task 2)
- [ ] `Tests/UnibrainProvidersTests/Inbox/InboxFilenameTests.swift` — stubs for IC-03 (created by 05-02 Task 1b)
- [ ] `Tests/UnibrainProvidersTests/Capture/iOSAudioSessionConfigTests.swift` — stubs for CAPT-03/IOS-03 (created by 05-02 Task 1b)
- [ ] `Tests/UnibrainProvidersTests/Playback/NowPlayingMetadataTests.swift` — stubs for IOS-02 (created by 05-02 Task 1b)
- [ ] `Tests/UnibrainProvidersTests/Inbox/InboxQueueTests.swift` — stubs for TRIG-02/TRIG-03 (created by 05-03 Task 1)
- [ ] `Tests/UnibrainProvidersTests/Inbox/DeadLetterHandlerTests.swift` — stubs for TRIG-04 (created by 05-03 Task 1)
- [ ] `Tests/UnibrainProvidersTests/Inbox/InboxFileDownloaderTests.swift` — stubs for IC-04 (created by 05-03 Task 1)

*Framework: existing Swift Testing (`import Testing`). No new install needed.*

---

## Manual-Only Verifications

iOS Simulator and Linux CI cannot validate iOS background audio, real lock-screen Now Playing, real iCloud Drive sync, or NSMetadataQuery against live iCloud metadata. These behaviors require a physical iPhone + iCloud Drive on both devices.

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Background recording survives 30+ min lock | CAPT-03, DISC-04 | iOS Simulator does not reliably simulate background audio suspension; only physical device reproduces the 30-second kill + UIBackgroundModes audio lease | 1. Deploy to iPhone via TestFlight/Xcode. 2. Open Record tab, tap Record. 3. Lock screen. 4. Wait 30 min (5 min acceptable for initial validation). 5. Unlock — verify timer shows correct elapsed time. 6. Tap Stop — verify .m4a saved to _inbox/. |
| Lock screen Now Playing + Stop/Pause remote commands | IOS-02 | MPNowPlayingInfoCenter display requires physical lock screen; Simulator does not render lock screen Now Playing | 1. Start recording on iPhone. 2. Lock screen. 3. Verify "Recording — {elapsed}" appears with Stop/Pause buttons. 4. Tap Pause on lock screen — verify recording pauses. 5. Tap Stop — verify recording stops and saves. |
| Phone call / Siri interruption auto-pause + auto-resume | IOS-03 | Interruption lifecycle requires real telephony stack; Simulator cannot receive calls | 1. Start recording on iPhone. 2. Call the iPhone from another phone. 3. Verify auto-pause on incoming call. 4. Decline the call. 5. Verify auto-resume. 6. Stop — verify .m4a is contiguous. |
| iPhone audio lands in macOS _inbox/ via iCloud Drive | IC-02 | iCloud Drive sync requires real iCloud account on both devices; Simulator has no real iCloud identity | 1. Record 1-min clip on iPhone. 2. Stop. 3. Verify "Saved" message on iPhone. 4. Open macOS Finder at vault _inbox/. 5. Wait 30-60s. 6. Verify file appears with IC-03 naming pattern. |
| NSMetadataQuery detects iCloud-synced file | TRIG-01 | NSMetadataQuery iCloud-aware results require real iCloud metadata on the picked folder; local test files do not transition through .icloud placeholders | 1. On iPhone: record 1-min clip, stop. 2. On macOS: wait for iCloud sync. 3. Verify NSMetadataQuery fires `.NSMetadataQueryDidUpdate` with the new file URL. 4. Verify pipeline processes it and moves audio to course folder. |
| Onboarding wizard page rendering (6 macOS, 5 iOS) | ONBD-01 | TabView(.page) rendering fidelity and swipe interactions require visual inspection | 1. Fresh-install the app (delete UserDefaults.hasCompletedOnboarding). 2. Launch. 3. Walk through all pages — verify Welcome, Vault picker (opens .fileImporter at iCloud Drive root), Mic (blocks on deny), Calendar (allows Skip), Term (macOS only), Ready. 4. Verify progress dots update. 5. Verify "Start Using unibrain" dismisses onboarding. |
| Permissions sheet live status display | ONBD-05 | Live mic/calendar authorization status reads system privacy state; requires actual permission grants | 1. Complete onboarding. 2. Tap "Manage Permissions". 3. Verify Mic row shows green check (granted). 4. Verify Calendar row shows status. 5. Tap "Settings" deep-link — System Settings opens to Privacy & Security. 6. Return to app — verify status refreshed. |
| iPhone setup picks same iCloud folder as Mac (config inheritance) | ONB-01 | Requires iCloud Drive sync of .unibrain/courses.json between two physical devices | 1. Complete macOS onboarding (sets currentTerm + course mapping). 2. On iPhone: open app fresh. 3. Walk through iOS onboarding (5 pages — no Term). 4. Pick the SAME iCloud Drive folder. 5. Verify Recent tab populates with macOS-created course folders within 1-2 minutes (iCloud sync latency). |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (8 test files enumerated above)
- [x] No watch-mode flags (all tests run-to-completion)
- [x] Feedback latency < 5s for targeted filters; ~30s for full macOS suite
- [x] `nyquist_compliant: true` set in frontmatter
- [x] Manual-only verifications have explicit rationale + device-test instructions

**Approval:** pending
