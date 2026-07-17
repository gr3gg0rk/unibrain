---
title: unibrain v1.0 — Milestone UAT Runbook
audience: Greg (developer) + Angelica (end-user device access)
assumptions:
  - Apple Developer Program: paid $99/yr (TestFlight enabled)
  - MacBook Neo: macOS 26 Tahoe, 8GB unified memory, A-series chip
  - iPhone: iOS 17+ (Angelica's device)
status: draft
created: 2026-07-17
sources:
  - .planning/PROJECT.md
  - .planning/STATE.md
  - .planning/ROADMAP.md
  - .planning/REQUIREMENTS.md
  - .planning/phases/03-macos-capture-transcribe/03-UAT.md
  - .planning/phases/04-course-classification-smart-routing/04-VERIFICATION.md
  - .planning/phases/05-ios-capture-icloud-handoff-onboarding/05-UAT.md
  - .planning/phases/06-gated-summarization-cloud-providers-mvp-polish/06-UAT.md
  - .planning/phases/06-gated-summarization-cloud-providers-mvp-polish/06-VERIFICATION.md
---

# unibrain v1.0 — Milestone UAT Runbook

Path: **clean MacBook Neo first boot → v1.0 milestone sign-off**.

Consolidates 15 device-deferred UAT scenarios from phases 3 / 4 / 5 / 6 into an ordered, command-level checklist. All commands assume macOS unless prefixed with `(ios)` or `(wsl)`.

## Critical pre-conditions discovered during planning scan

Three blockers surfaced while authoring this runbook. Each must be addressed in-stage:

| # | Blocker | Stage | Impact |
|---|---------|-------|--------|
| 1 | **No `.xcodeproj` in repo.** `UnibrainApp/` is Swift sources + Info.plist only. SPM `Package.swift` builds the libraries; the app target has never been compiled. | Stage 3 | First Mac session must create the Xcode project from scratch (multiplatform target, signing, entitlements, Info.plist wiring). Expect Swift 6 strict-concurrency warnings not seen on Linux SPM build. |
| 2 | **CI is stale.** Last green run `29440234427` on 2026-07-15 (pre-Phase 6). Phase 6 commits `2ad1720`, `17e1a4c`, etc. have never run on macOS CI. | Stage 0 | Push must go green before any device work, otherwise you're validating un-CI'd code. |
| 3 | **Phase 4 integration wiring never device-verified.** 04-VERIFICATION.md reported 4 source-level gaps (resolver, picker overlay, picker data, manage-courses data); claim is they were closed by 04-06 commit but the device behavior has never been observed. | Stage 9 | Treat Stage 9 as the **first end-to-end test** of smart routing — not a confirmation of known-good behavior. |

## Pre-flight checklist (gather before Stage 0)

- [ ] Apple ID enrolled in Apple Developer Program ($99/yr paid)
- [ ] MacBook Neo (macOS 26 Tahoe, 8GB) with admin access
- [ ] Angelica's iPhone (iOS 17+) with passcode
- [ ] Both devices signed into the SAME iCloud account, iCloud Drive enabled
- [ ] At least one cloud provider API key (OpenAI / Anthropic / Grok / Z.ai)
- [ ] ~15GB free disk on MacBook Neo (Xcode ~7GB, Ollama models ~2GB, whisper.cpp `small.en` ~466MB, repo + build artifacts ~3GB, vault + audio buffer ~1GB)
- [ ] WSL2 dev environment reachable (for Stage 0 push)
- [ ] Calendar access on MacBook Neo (admin grant for adding test events)

---

## Stage 0 — WSL2 pre-flight (before touching Mac)

Validates Phase 6 source state and pushes to CI before any device session.

- [ ] **0.1** On WSL2, in `/home/gr3gg0rk/unibrain`: `swift test` → expect 343/345 pass (2 pre-existing `ModelLoadGateOllamaTests` flakes documented in 06-VERIFICATION.md behavior_unverified item 1). If a different count, stop and investigate.
- [ ] **0.2** Confirm working tree clean: `git status` → nothing to commit.
- [ ] **0.3** Push: `git push origin main`.
- [ ] **0.4** Watch CI: `gh run watch` → both `linux-tests` and `macos-tests` jobs must go green. Record the run URL + completion time in the validation log.
- [ ] **0.5** If macOS CI surfaces failures not present on WSL2: file an issue, route through `/gsd-debug`, do not proceed to Stage 1.

## Stage 1 — MacBook Neo first-boot setup

Estimated 1–2 hours (dominated by Xcode download).

- [ ] **1.1** Boot, complete macOS setup wizard, sign into iCloud (same Apple ID as iPhone).
- [ ] **1.2** System Settings → Software Update → install all updates → reboot.
- [ ] **1.3** Install Xcode 16+ from App Store (~7GB; will take 30+ min).
- [ ] **1.4** Launch Xcode once → accept license → install additional components prompt → install.
- [ ] **1.5** Verify: `xcodebuild -version` → Xcode 16.x, Swift 6.0.x.
- [ ] **1.6** Install Homebrew:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo >> ~/.zprofile; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile; eval "$(/opt/homebrew/bin/brew shellenv)"
  ```
- [ ] **1.7** `brew install gh` → `gh auth login` (use GitHub.com → HTTPS → web browser flow).
- [ ] **1.8** `brew install --cask obsidian` (vault verification tool).
- [ ] **1.9** `brew install --cask ollama` (local LLM runtime; launches `Ollama.app` at end of install).
- [ ] **1.10** `brew install mitmproxy` (for Stage 13 zero-telemetry audit).
- [ ] **1.11** `xcode-select --install` (Command Line Tools — sometimes already installed by Xcode).

## Stage 2 — Apple Developer Program activation

Estimated 5 min if Apple ID is already paid; 1–2 days if waiting for verification.

- [ ] **2.1** https://developer.apple.com → Account → sign in with the Apple ID that will own unibrain.
- [ ] **2.2** Enroll in Apple Developer Program → pay $99 USD → confirm email.
- [ ] **2.3** Wait for activation email ("Welcome to Apple Developer Program"). Do not proceed until received.
- [ ] **2.4** Xcode → Settings → Accounts → `+` → Apple ID → sign in with the paid Apple ID.
- [ ] **2.5** Verify the team appears with paid membership status (not "Free").
- [ ] **2.6** Xcode → Settings → Accounts → select team → "Manage Certificates…" → `+` → "Apple Development" (for Mac + iPhone dev installs). Verify no errors.

## Stage 3 — Repo + Xcode project bootstrap

Estimated 2–4 hours. **This is the highest-risk stage** — no `.xcodeproj` exists.

- [ ] **3.1** Clone repo:
  ```bash
  mkdir -p ~/Developer && cd ~/Developer
  git clone https://github.com/gr3gg0rk/unibrain.git
  cd unibrain
  ```
- [ ] **3.2** Sanity check the libraries compile:
  ```bash
  swift build
  ```
  Both `UnibrainCore` + `UnibrainProviders` must build clean. If they fail on Mac but passed on WSL2, investigate — Linux SPM doesn't catch Darwin-only issues.
- [ ] **3.3** Sanity check tests:
  ```bash
  swift test
  ```
  Expect 343/345 (same baseline as Stage 0).
- [ ] **3.4** **Create Xcode project wrapping `UnibrainApp/`** — see *Project Creation Procedure* below.
- [ ] **3.5** First build (⌘B): both macOS + iOS targets compile. Fix any Swift 6 strict-concurrency warnings (Linux SPM may not have surfaced them).
- [ ] **3.6** First macOS run (⌘R): menu-bar brain icon appears in the menu bar. No crash within 30 seconds.
- [ ] **3.7** Commit the `.xcodeproj`, `.entitlements`, any new Info.plist fields to the repo. Tag the commit — this is the first device-buildable state.

### Project Creation Procedure (Stage 3.4 detailed)

The `UnibrainApp/` folder exists with Swift sources but is not yet an Xcode target.

1. **Xcode → File → New → Project…**
2. Choose **macOS → App** template.
3. Fields:
   - Product Name: `unibrain`
   - Organization Identifier: `app` (gives Bundle ID `app.unibrain` per PROJECT.md D-…)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
   - Include Tests: leave unchecked (SPM `Tests/` directory already exists)
4. Save **INTO** the existing `~/Developer/unibrain` repo root. Xcode will warn about non-empty dir — accept.
5. Delete the auto-generated `ContentView.swift`, `*_App.swift`, `Assets.xcassets`, `Preview Content/`, and `unibrain.entitlements` from the new project navigator. Keep `Info.plist` only if you intend to merge it.
6. Drag the existing `UnibrainApp/` folder from Finder into the Xcode project navigator:
   - **Options**: "Create groups", **uncheck** "Copy items if needed" (sources stay where they are).
   - Add to targets: **unibrain (macOS)**.
7. Configure the macOS target:
   - Deployment Target: **macOS 15.0** (per Package.swift — `.macOS(.v15)`; Swift 6.0.3 toolchain lacks `.v26`)
   - Signing & Capabilities → Team: paid Personal Team → "Automatically manage signing" → check no errors
   - Hardened Runtime: **enabled** (required for distribution)
8. Add the local SPM package:
   - **File → Add Package Dependencies… → Add Local…** → select `~/Developer/unibrain` (the repo root)
   - Add to target: `UnibrainCore`, `UnibrainProviders`
   - Yams will resolve transitively from `Package.resolved`
9. Configure Info.plist (existing file at `UnibrainApp/Info.plist`). Add/verify:
   - `NSMicrophoneUsageDescription`: `"unibrain records lectures to transcribe them."`
   - `NSCalendarsUsageDescription`: `"unibrain reads your course schedule to file recordings into the right folder."`
   - `LSUIElement`: `true` (menu-bar-only app — no Dock icon)
10. Create `UnibrainApp.entitlements` with:
    - `com.apple.security.app-sandbox`: `true`
    - `com.apple.security.device.audio-input`: `true`
    - `com.apple.security.network.client`: `true` (cloud providers — opt-in)
    - `com.apple.security.files.user-selected.read-write`: `true` (vault folder picker)
    - `com.apple.security.files.bookmarks.app-scope`: `true` (persist vault bookmark)
11. Build (⌘B). Fix any errors before proceeding.

## Stage 4 — iOS target setup (multiplatform)

Estimated 1–2 hours.

- [ ] **4.1** In the existing `.xcodeproj`: **File → New → Target…** → **iOS → App**.
- [ ] **4.2** Fields: Product Name `unibrain-ios`, Organization Identifier `app`, Interface SwiftUI, Language Swift. Bundle ID `app.unibrain` (same as macOS for shared iCloud container).
- [ ] **4.3** Delete auto-generated sources for the iOS target.
- [ ] **4.4** Drag `UnibrainApp/` sources into the iOS target (Create groups, don't copy). Verify file membership: each source file should be in BOTH macOS + iOS targets (except `#if os(...)` guarded views).
- [ ] **4.5** Link `UnibrainCore` + `UnibrainProviders` from the local SPM package to the iOS target.
- [ ] **4.6** iOS deployment target: **iOS 17.0** (per Package.swift — `.iOS(.v17)`; required for `@Observable`, EventKit iOS 17+ API).
- [ ] **4.7** iOS Info.plist:
    - `NSMicrophoneUsageDescription`
    - `NSCalendarsUsageDescription`
    - `UIBackgroundModes`: `["audio"]` (CAPT-03 background recording)
- [ ] **4.8** iOS entitlements:
    - `com.apple.security.application-groups`: shared App Group ID (for iCloud Drive container shared with macOS target) — typically `group.app.unibrain`
    - Keychain Sharing capability: same access group as macOS (`$(AppIdentifierPrefix)app.unibrain`)
- [ ] **4.9** Configure iCloud Drive container: enable "iCloud Documents" capability on both targets, same container ID.
- [ ] **4.10** Build both targets (⌘B). Resolve any remaining strict-concurrency issues.

## Stage 5 — Local infrastructure setup

Estimated 30 min + iCloud sync wait.

- [ ] **5.1** Launch `Ollama.app` (menu bar icon "🦙"). Wait for "Ollama is running" notification.
- [ ] **5.2** Pull summarization model:
  ```bash
  ollama pull llama-3.2:3b   # ~2GB download
  ```
- [ ] **5.3** Verify: `ollama list` shows `llama-3.2:3b`.
- [ ] **5.4** Health check the API endpoint unibrain will use:
  ```bash
  curl -s http://localhost:11434/api/tags | jq '.models[].name'
  ```
  Should include `llama-3.2:3b`.
- [ ] **5.5** Create Angelica's vault:
  ```bash
  mkdir -p ~/Library/Mobile\ Documents/iCloud~unibrain/Documents/AngelicaVault
  ```
  (This puts it directly in the iCloud Drive container unibrain will sync to — preferred over `~/Documents` per ONBD-04.)
- [ ] **5.6** Open Obsidian → "Open folder as vault" → navigate to the iCloud path above. If Obsidian can't see iCloud Drive, use `~/Documents/AngelicaVault` and add it to iCloud manually via Finder.
- [ ] **5.7** Verify vault syncs to iPhone: open Files app on iPhone → Browse → iCloud Drive → `AngelicaVault` should appear within 5 minutes. If not, force-sync via System Settings → Apple ID → iCloud → iCloud Drive.
- [ ] **5.8** whisper.cpp `small.en` model (~466MB) — **do not pre-download**. unibrain's `SmallEnDownloader` (Phase 3, plan 03-02) downloads it on first transcription with checksum verification. We want the downloader path exercised end-to-end during UAT.

## Stage 6 — Test calendar setup

Estimated 15 min.

- [ ] **6.1** Open Calendar.app on MacBook Neo → ensure iCloud calendar is the default.
- [ ] **6.2** Create a calendar named "Courses" (or use the existing default iCloud calendar).
- [ ] **6.3** Add test events that **overlap "now"** so UAT can run live:
  - "BIO 101 Lecture" — 10:00–11:00 today, location "Gym A"
  - "MATH 200 Lecture" — 13:00–14:30 today, location "Hall B"
  - "HIST 110 Lecture" — 15:00–16:00 today
  - One **past-term** event with same time slot but different dates (for CLAS-06 filter test)
- [ ] **6.4** Verify events appear on iPhone Calendar within 1 minute (pull-to-refresh).
- [ ] **6.5** In System Settings → Privacy & Security → Calendars: pre-grant unibrain (won't show up until first launch — leave for Stage 7).

## Stage 7 — First-run onboarding UAT (Phase 5)

Reference: `05-UAT.md`, requirements `ONBD-01/04/05`.

- [ ] **7.1** Launch unibrain from Xcode (⌘R) on macOS.
- [ ] **7.2** Verify first-run wizard sequence: Welcome → Vault picker → Mic permission → Calendar permission → Term label → Ready.
- [ ] **7.3** On Vault picker page: select the iCloud `AngelicaVault` from Stage 5. Verify bookmark persists (reopen app → vault path remembered).
- [ ] **7.4** Mic permission dialog: grant.
- [ ] **7.5** Calendar permission dialog: select **Full Access** (NOT Write-Only — Write-Only degrades to manual picker for everything).
- [ ] **7.6** Term label: enter "Fall 2026", start = today − 7 days, end = today + 90 days.
- [ ] **7.7** Reach "Ready" screen → main menu-bar UI appears.
- [ ] **7.8** Open unibrain Settings (menu bar popover → gear icon or ⌘,) → Permissions tab → verify mic + calendar show "On", vault path matches Stage 5.
- [ ] **7.9** Revoke calendar in System Settings → Privacy & Security → Calendars → toggle unibrain off. Re-open unibrain → verify `PermissionDeniedSheet` appears with a "Open System Settings" deep-link. Tap link → confirm it opens the right pane.
- [ ] **7.10** Re-grant calendar permission. Continue to Stage 8.

## Stage 8 — macOS capture + transcribe UAT (Phase 3, 9 scenarios)

Reference: `03-UAT.md`. **Note**: Phase 3 plans 03-02 deferred whisper.cpp SPM integration — `WhisperCppTranscriber.swift` line 81 still has `// TODO: Wire whisper.cpp SPM API once macOS CI validates the import.` If transcription fails at 8.5, this is the most likely culprit. File a `/gsd-debug` issue.

- [ ] **8.1** Cold start: launch app → brain icon (gray) appears in menu bar → no crash, no beachball within 60s. (Background model download may start if Stage 5.8 left to first-run.)
- [ ] **8.2** Idle popover: click brain icon → popover opens ~280pt wide → shows "Ready to record" with model status (download progress or "Ready") + Record button.
- [ ] **8.3** Start recording: click Record → icon turns `brain.fill` red → popover shows live MM:SS timer (advancing), animated waveform Canvas, 3-segment mic-level meter (green/yellow/red reacting to ambient noise).
- [ ] **8.4** Pause/Resume: mid-recording click Pause → icon turns yellow, timer freezes, waveform dims. Click Resume → icon red again, timer continues from frozen point. Stop → resulting `.m4a` is **ONE contiguous file** (verify in vault attachment folder). Pause/resume timestamps preserved in frontmatter.
- [ ] **8.5** Stop → transcription: click Stop → within ~200ms popover transitions to "Transcribing…" with spinner + ETA. Menu bar remains interactive (click around — no beachball). This is the `Task.detached(priority: .userInitiated)` enforcement (TRAN-03).
- [ ] **8.6** Transcription completion: macOS notification fires ("Lecture transcribed"). Click notification → focuses the vault file in Obsidian (or opens Finder). Icon returns to gray.
- [ ] **8.7** Vault file written: `~/Library/Mobile Documents/iCloud~unibrain/Documents/AngelicaVault/lectures/YYYY-MM-DD-Lecture.md` exists within 5 min of stop (for a 1-min recording on `small.en`). Contents: YAML frontmatter (`title`, `date`, `duration_seconds`, `source`, snake_case keys) followed by title heading + transcript body. No `.icloud` placeholder fragments.
- [ ] **8.8** Icon state transitions: across the full session, icon went idle → record (red) → pause (yellow) → resume (red) → transcribe (accent) → idle. No stuck/missing states.
- [ ] **8.9** RAM discipline: open Activity Monitor → filter "unibrain". Baseline should be ~200-400 MB. During transcription, expect transient spike to ~1 GB (whisper model loaded at inference time). Within 60s of completion, RAM should return to baseline (TRAN-06).

## Stage 9 — Course classification smart routing UAT (Phase 4, 8 scenarios)

Reference: `04-VERIFICATION.md` Human Verification Required + `06-UAT.md` scenario 4.1.

**This stage is the first end-to-end device verification of Phase 4 integration wiring.** 04-06-PLAN claimed closure of 4 source-level gaps; behavior has never been observed on a device. Treat failures here as **expected**, not surprising.

- [ ] **9.1** **Single overlapping event** (CLAS-01, CLAS-02, CLAS-05): during the BIO 101 timeslot, record a 30-sec clip + stop. Verify resulting note appears at `AngelicaVault/{term}/bio-101/YYYY-MM-DD-BIO-101-Lecture.md` with frontmatter `course: "BIO 101"`, `term: "Fall 2026"`, `tags: ["bio-101", "lecture"]`.
- [ ] **9.2** **Multiple overlapping events**: contrive two overlapping events at the same time. Record → `CourseSelector` sheet should appear inline in the popover (NOT as a detached `.sheet` window — this is the FB11984872 regression check).
- [ ] **9.3** **No overlapping events** (CLAS-04): record outside any scheduled class timelot. Verify UNCLASSIFIED + manual picker appears with recent courses + search field.
- [ ] **9.4** **Adjacent events (5-min gap)**: schedule two events 5 minutes apart. Record at the boundary. Verify orchestrator parks at `.awaitingUserChoice` → picker fires.
- [ ] **9.5** **All-day event overlapping**: create an all-day event "Study Day" overlapping today. Record during a regular lecture slot. Verify the all-day event is SKIPPED (not matched as the course).
- [ ] **9.6** **Event with no location** (FolderNameSanitizer path): create "PHIL 220 Lecture" with no location field. Record during its timeslot. Verify no crash; folder name derived from title only.
- [ ] **9.7** **Empty CourseMappingStore** (fallback path): if Stage 7 was the first launch with empty store, the first recording should fall back to using the calendar event title directly → auto-create sanitized folder.
- [ ] **9.8** **Folder name sanitization**: create a deliberately messy event title like `"C/S 101: Intro!"`. Record during its timeslot. Verify the resulting folder name is sanitized — no slashes, colons, or trailing punctuation. Acceptable: `c-s-101-intro` or similar.
- [ ] **9.9** **CLAS-07 manual override remembered**: pick "BIO 101" manually for one ambiguous recording. Next recording during the same timeslot should auto-route to BIO 101 without showing the picker.
- [ ] **9.10** **CLAS-06 term filter**: create a past-term event (term end date in the past) overlapping today's recording timeslot. Verify the past-term event is NOT matched — recording routes to current-term folder or triggers picker, never to past-term folder.

## Stage 10 — iOS capture + iCloud handoff UAT (Phase 5, 3-4 scenarios)

Reference: `05-UAT.md`. Requires iPhone access + TestFlight deploy.

- [ ] **10.1** **TestFlight deploy**: Xcode → Product → Archive (iOS scheme) → Distribute App → TestFlight → internal testers. Wait for Apple processing (15 min – 1 hour). Install on iPhone via TestFlight app.
- [ ] **10.2** **Background recording survival** (CAPT-03, DISC-04): on iPhone, open unibrain Record tab → tap Record → lock screen → wait 30 minutes → unlock. Timer should show correct elapsed time. Lock screen should display "Recording" with Stop/Pause controls. Tap Stop → file saved to `_inbox/` on iCloud Drive.
- [ ] **10.3** **Interruption auto-pause/resume** (IOS-03): start iPhone recording → use a second phone to call the iPhone → recording should auto-pause on incoming call → decline the call → recording should auto-resume → final `.m4a` is ONE contiguous file.
- [ ] **10.4** **iCloud Drive end-to-end handoff**: record a 1-minute clip on iPhone → stop. File should appear on MacBook Neo `_inbox/` via iCloud Drive within 1-5 minutes. `InboxWatcher` on macOS detects it → pipeline processes (transcribe → classify → write) without user intervention. Resulting note appears in the correct course folder on MacBook Neo.

## Stage 11 — Gated summarization + cloud providers UAT (Phase 6, 8 scenarios)

Reference: `06-UAT.md`.

- [ ] **11.1** **Ollama setup**: Settings → General → toggle Summarization ON. LLM provider = Local (Ollama). Verify "Ollama: Running" callout appears.
- [ ] **11.2** **Local summarization** (SUMM-01..06): open a transcribed note in the vault → trigger "Summarize" from the menu-bar popover or note context menu. Within 30-60s, a `## Summary` section appears at the bottom of the note with 5-8 bullet points. Frontmatter should now contain `summary_model: llama-3.2:3b` and `llm_provider: ollama` (verifies Gap 1 closure from 06-07).
- [ ] **11.3** **Regenerate Summary** (SUMM-06): edit the transcript (add or remove a paragraph). Click "Regenerate Summary". Verify ONLY the `## Summary` section changes — rest of the note (frontmatter, transcript body, other sections) is unchanged.
- [ ] **11.4** **ModelLoadGate** (SUMM-07, DISC-01): trigger a summary WHILE a transcription is running. The Ollama summarization should refuse with `.busy` — either queue, fall back, or surface a clear error. Verify no OOM crash and no simultaneous model load.
- [ ] **11.5** **Cloud provider setup**: Settings → Providers → LLM section → add OpenAI (or another). Enter API key in the SecureField. Verify key stores in Keychain (open Keychain Access → search "unibrain" → entry present). Toggle LLM provider to OpenAI.
- [ ] **11.6** **Consent gate** (CON-01, CLOUD-08): trigger a cloud summarization. First call should show `ConsentSheet` on the menu-bar popover: "Allow OpenAI to summarize this recording?" with buttons [Only this once] / [Always allow OpenAI for LLM] / [Cancel]. Tap "Always allow". Summary proceeds. Trigger a second cloud summary → no sheet appears (consent persisted).
- [ ] **11.7** **Cloud failure recovery** (CF-01..04):
  - (a) Disconnect WiFi mid-cloud-summary → `CloudFailureSheet` appears with "{Provider} unreachable — network down" + buttons [Fall back to local] / [Cancel] (NO Retry — CF-02 fast-fail). Tap "Fall back to local" → pipeline switches to Ollama.
  - (b) Reconnect WiFi. Force a 429 rate-limit (use a throwaway key with no quota). Verify `RetryComposer` attempts 3× with backoff [2, 8, 30] seconds. After 3 failures, `CloudFailureSheet` shows "{Provider} rate-limited" + [Retry] / [Fall back to local] / [Cancel].
- [ ] **11.8** **Audit tab** (CF-04, CLOUD-13): Settings → Audit tab. Verify table populates from vault scan — columns: Date, Note, Provider, Modality, Status. Filter by Date Range / Provider / Status. Click "Export Audit Log" → NSSavePanel → save `unibrain-audit-log.csv` to Desktop → verify CSV opens in Numbers/Excel with valid rows. Click "Clear History" → confirm → table empties.

## Stage 12 — iOS Settings + iCloud consent sync (Phase 6, 2 scenarios)

Reference: `06-UAT.md` scenarios 6.1, 6.5.

- [ ] **12.1** **iOS Settings tab** (SET-03): on iPhone, open unibrain → Settings tab. Verify all 5 sections render: PROVIDERS (read-only, "Configure on Mac" alert), COURSES (current term, mapping count, "Manage on Mac" alert), PERMISSIONS (mic/calendar status, actionable → PermissionsSheet with re-grant buttons), AUDIT ("View full log on Mac" alert), ABOUT (version + "Local-first. Zero telemetry."). Tap each non-actionable row → verify alert fires.
- [ ] **12.2** **iCloud consent sync** (DISC-06, CON-03):
  - On macOS: grant consent for OpenAI LLM (Stage 11.6).
  - Verify `.unibrain/consent.json` is written to the iCloud-synced app group container.
  - Wait 30s–2min for iCloud Drive sync.
  - On iPhone: open Settings tab → verify provider info reflects the granted consent (OpenAI marked as configured).
  - On macOS: revoke consent in Settings → Audit. Wait for sync. Verify iPhone reflects revoked state. Verify `consent.json` is valid JSON on BOTH devices (no iCloud conflict corruption).

## Stage 13 — Zero-telemetry mitmproxy audit (CLOUD-12)

Reference: `06-UAT.md` scenario 6.6 + `MAINTAINERS.md`.

- [ ] **13.1** Start mitmproxy:
  ```bash
  mitmproxy --listen-port 8080
  ```
- [ ] **13.2** Trust the mitmproxy CA:
  ```bash
  # Install the cert
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/.mitmproxy/mitmproxy-ca-cert.pem
  ```
- [ ] **13.3** Configure macOS HTTP proxy: System Settings → Network → Wi-Fi → Details → Proxies → Web Proxy (HTTP) + Secure Web Proxy (HTTPS) → both `127.0.0.1:8080`.
- [ ] **13.4** Quit and relaunch unibrain. Verify it starts normally (no proxy-related crash).
- [ ] **13.5** Observe traffic for **60 seconds idle**: ZERO outbound connections of any kind. (App may open its menu-bar window — that's local, doesn't count.)
- [ ] **13.6** Record a 10-second clip locally (no cloud). ZERO outbound connections during record.
- [ ] **13.7** Stop → local transcription (whisper.cpp). ZERO outbound connections.
- [ ] **13.8** Trigger cloud summarization (OpenAI). The ONLY outbound traffic should be `api.openai.com:443`. Verify no other domains: no `*.amazonaws.com`, no `*.akamai.net`, no analytics endpoints (mixpanel, segment, amplitude, sentry, firebase, datadog all absent).
- [ ] **13.9** Disconnect proxy + restore original network settings.
- [ ] **13.10** Record findings: confirm zero telemetry for the lifecycle. This is the CLOUD-12 ship gate.

## Stage 14 — Local-first offline test (DISC-05)

Reference: `06-UAT.md` scenario 6.7.

- [ ] **14.1** Turn off WiFi on MacBook Neo (System Settings → Wi-Fi → toggle off). Also disable Ethernet if connected.
- [ ] **14.2** Launch unibrain → verify it functions normally (no "network required" dialogs).
- [ ] **14.3** Record 5 seconds → file saved to disk.
- [ ] **14.4** Stop → whisper.cpp loads model → transcribes → releases model. (Local-only.)
- [ ] **14.5** CourseClassifier runs via local EventKit calendar (no network).
- [ ] **14.6** Note written to vault in correct course folder.
- [ ] **14.7** Open note in Obsidian → valid Markdown, correct frontmatter, transcript present.
- [ ] **14.8** Reconnect WiFi → wait 60s. If mitmproxy still running, verify NO retroactive telemetry burst — unibrain should never send queued analytics.

## Stage 15 — Milestone sign-off

Estimated 1 hour.

- [ ] **15.1** Collect all UAT scenario results (pass/fail + screenshots/logs for failures) into a single validation summary.
- [ ] **15.2** Update `03-UAT.md` with actual test results + dates for scenarios 1-9.
- [ ] **15.3** Update `05-UAT.md` with actual results for scenarios 1-4.
- [ ] **15.4** Update `06-UAT.md` with actual results for scenarios 6.1-6.8 + the deferred 3.1, 4.1, 5.1 sections.
- [ ] **15.5** Mark `04-VERIFICATION.md` Human Verification items (1-4) as resolved with device-verification evidence.
- [ ] **15.6** Update `STATE.md` → clear the "Deferred Verification" table (all phases verified).
- [ ] **15.7** Update `REQUIREMENTS.md` traceability → any remaining "device-deferred" statuses flip to "device-verified".
- [ ] **15.8** Update `PROJECT.md` "Current State" → "v1.0 milestone ship-ready, all 15 device UAT scenarios pass".
- [ ] **15.9** Update `ROADMAP.md` Phase 3 row → mark "Complete" with today's date.
- [ ] **15.10** Run `/gsd-complete-milestone` to formally close v1.0.
- [ ] **15.11** Tag the release: `git tag v1.0 -m "unibrain v1.0 — Record-to-Obsidian loop ship-ready" && git push origin v1.0`.
- [ ] **15.12** Final state check: `swift test` still green, CI still green, no untracked planning changes.

---

## Rollback / failure handling

If any stage fails:

1. **Capture the failure**: screenshot + Console.app log (filter process "unibrain") + Xcode debug console output + any crash `.ips` files from `~/Library/Logs/DiagnosticReports/`.
2. **Check known risks** below — is this a documented high-risk area?
3. **File a GitHub issue** with the failure artifacts on the `gr3gg0rk/unibrain` repo.
4. **For blocking failures**: create a `/gsd-debug` session to investigate root cause. Do NOT mark milestone complete with open blockers.
5. **For non-blocking failures** (UI polish, flaky behavior): document as a Phase 7 / v2 follow-up, mark the scenario as "Pass with caveat" in the UAT record, and proceed.
6. **Re-run the failed stage** after the fix. Stages 3 and 9 are the most likely to require iteration.

## Known risks / likely failure surfaces

Ranked by likelihood × impact:

1. **Xcode project creation (Stage 3.4)** — never done before, no `.xcodeproj` exists. Swift 6 strict-concurrency warnings not surfaced on Linux SPM will likely fire. Plan 2-4 hours here, including a debugging round.
2. **Phase 4 wiring (Stage 9)** — integration claimed closed by 04-06 commit but never device-verified. The 4 original gaps (resolver wiring, `.awaitingUserChoice` state observer, picker data binding, manage-courses data) may have residual issues that only surface at runtime. Stage 9.1 is the first end-to-end smart-routing test ever.
3. **whisper.cpp Metal integration (Stage 8)** — Phase 3 plan 03-02 deferred whisper.cpp SPM to "macOS CI validation" which never happened. `Sources/UnibrainProviders/Transcription/WhisperCppTranscriber.swift:81` has `// TODO: Wire whisper.cpp SPM API once macOS CI validates the import.` This may block Stage 8.5 transcription entirely. **Fallback**: evaluate `SpeechAnalyzerTranscriber.swift` (line 60 has the same TODO for SpeechAnalyzer) — may need a Phase 3 follow-up.
4. **iOS background recording (Stage 10.2)** — background audio on iOS is notoriously finicky. Background Modes entitlement, audio session category, lock-screen Now Playing controls all need to work together. Plan for at least one debugging round.
5. **ModelLoadGate singleton flakes (Stage 11.4)** — `ModelLoadGateOllamaTests` has documented isolation flakes (2-3 tests per run). The logic is correct but the test infrastructure is broken. Don't be alarmed if SUMM-07 verification is noisy.
6. **Known UI stubs (non-blocking)**:
   - `CoursesTab.swift`: "Edit…" term editor + "Import from Calendar" buttons are no-ops (06-05 Known Stubs #1, #2)
   - `AuditTab.swift`: retry/fallback buttons in failed operations section not wired (06-06 Known Stub #1)
   - `ModelPullCallout.swift`: actual `ollama pull` Process invocation not wired (06-02 Known Stub #1)
   These are documented in SUMMARYs and do not block the core goal. Document as Phase 7 polish.

## Time estimates (rough)

| Stage | Active time | Wait time |
|-------|-------------|-----------|
| 0 — WSL2 pre-flight | 30 min | CI run (~5 min) |
| 1 — MacBook first-boot setup | 1-2 hours | Xcode download (~30 min) |
| 2 — Apple Dev activation | 5 min | 1-2 days (Apple verification) |
| 3 — Repo + Xcode project bootstrap | 2-4 hours | — |
| 4 — iOS target setup | 1-2 hours | — |
| 5 — Local infrastructure | 30 min | iCloud sync (5-30 min) |
| 6 — Test calendar | 15 min | iCloud sync (~1 min) |
| 7 — Onboarding UAT | 30 min | — |
| 8 — Phase 3 macOS UAT | 1-2 hours | — |
| 9 — Phase 4 smart routing UAT | 2-3 hours | — |
| 10 — Phase 5 iOS + iCloud UAT | 1-2 hours | TestFlight processing (1 hr) + iCloud sync |
| 11 — Phase 6 summarization UAT | 2-3 hours | — |
| 12 — Phase 6 iOS Settings UAT | 30 min | iCloud sync |
| 13 — Zero-telemetry audit | 1 hour | — |
| 14 — Local-first offline test | 30 min | — |
| 15 — Milestone sign-off | 1 hour | — |
| **Total** | **~15-22 hours active** | **+ 1-2 days wait** |

Spread across 1-3 weeks, gated on Apple activation + iCloud sync + Angelica's iPhone availability for Stage 10.

---

*Authored: 2026-07-17 via quick task `260717-fil`.*
*Phase 6 source-complete; all 15 device UAT scenarios documented above.*
*Track results inline as stages are completed.*
