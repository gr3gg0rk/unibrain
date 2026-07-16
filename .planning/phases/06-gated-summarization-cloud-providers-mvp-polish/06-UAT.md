---
status: pending
phase: 06-gated-summarization-cloud-providers-mvp-polish
source:
  - 06-06-PLAN.md
  - 06-04-SUMMARY.md
  - 06-05-SUMMARY.md
  - .planning/phases/03-macos-capture-transcribe/03-UAT.md
  - .planning/phases/04-course-classification-smart-routing/04-VERIFICATION.md
  - .planning/phases/05-ios-capture-icloud-handoff-onboarding/05-UAT.md
created: 2026-07-16T22:00:00Z
updated: 2026-07-16T22:00:00Z
---

# Phase 6 UAT: Gated Summarization + Cloud Providers + MVP Polish

## Device Requirements

- MacBook Neo (macOS 26 Tahoe, 8GB unified memory, A-series chip)
- iPhone (iOS 17+)
- iCloud Drive configured on both devices with same Apple ID
- Ollama installed on MacBook Neo (`ollama pull llama-3.2:3b`)
- At least one cloud provider API key (OpenAI, Anthropic, Grok, or Z.ai)
- Apple Developer Program membership (for device deployment)

## Test Scenarios

### Phase 6: Gated Summarization + Cloud Providers + Settings UI

#### 6.1 iOS Settings Tab Rendering (SET-03)

**Prerequisites:** App installed on iPhone, iCloud Drive syncs `.unibrain/` between Mac and iPhone, provider configured on macOS.

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open unibrain on iPhone | App launches, TabView visible |
| 2 | Tap Settings tab | Settings form appears |
| 3 | Verify PROVIDERS section | Shows LLM: Local (Ollama), ASR: Local (whisper.cpp), Vision: Off, TTS: Off |
| 4 | Verify "Configure providers on your Mac" text | Present below provider rows |
| 5 | Tap LLM row | Alert: "Provider configuration is available on macOS. Open Settings on your Mac to change providers." |
| 6 | Tap OK, tap ASR row | Same alert appears |
| 7 | Verify COURSES section | Current Term: Fall 2026, Course Mappings: 3 |
| 8 | Tap Current Term | Alert: "Manage courses on your Mac..." |
| 9 | Verify PERMISSIONS section | Microphone: On (green dot), Calendar: On (green dot), Vault: ~/Documents/Unibrain/ |
| 10 | Tap Permissions row | PermissionsSheet opens with re-grant buttons |
| 11 | Verify AUDIT section | Recent Activity: Last 7 days |
| 12 | Tap Recent Activity | Alert: "View the full audit log on your Mac..." |
| 13 | Verify About section | unibrain v1.0, "Local-first. Zero telemetry." |

**Pass criteria:** All sections render, read-only alerts fire correctly, Permissions is actionable.
**Result:** [pending]

---

#### 6.2 macOS Audit Tab (CF-04, CLOUD-13)

**Prerequisites:** At least 5 notes in vault with frontmatter, at least 1 with cloud provider usage, at least 1 with a summary.

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Settings → Audit tab on macOS | AuditTabFull renders |
| 2 | Verify filter bar | Date Range: Last 7 days, Provider: All, Status: All, Refresh button |
| 3 | Verify table columns | Date, Note, Provider, Modality, Status |
| 4 | Verify status icons | Green checkmark for success, orange warning for failed |
| 5 | Change Date Range to "All time" | Table updates to show all entries |
| 6 | Change Provider to "Ollama" | Table filters to ollama-provider entries |
| 7 | Change Status to "Success" | Table filters to successful entries only |
| 8 | Click "Export Audit Log" | NSSavePanel appears, default name "unibrain-audit-log.csv" |
| 9 | Save to Desktop | CSV file created with header row + data rows |
| 10 | Click "Clear History" | Confirmation alert appears |
| 11 | Confirm clear | All audit entries removed from display |

**Pass criteria:** Table populates from vault scan, filters work, CSV export creates valid file.
**Result:** [pending]

---

#### 6.3 Consent Sheet (CON-01, CON-02)

**Prerequisites:** Cloud provider configured (e.g., OpenAI API key in Keychain), no consent record exists for `openai×llm`.

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Trigger a cloud summarization (record → stop → transcribe → trigger summary) | Pipeline runs, reaches summary stage |
| 2 | Verify ConsentSheet appears on menu-bar popover | Sheet shows "Allow OpenAI to summarize this recording?" with 3 buttons |
| 3 | Verify buttons present | [Only this once] [Always allow OpenAI for LLM] [Cancel] |
| 4 | Click "Always allow OpenAI for LLM" | Consent persists to `.unibrain/consent.json`, summary proceeds |
| 5 | Trigger another cloud summarization | No consent sheet appears (consent already granted) |
| 6 | Open Settings → Audit tab → find consent record | Consent record visible in consent.json with `alwaysAllow: true` |

**Pass criteria:** Consent gate fires on first use, persists, and doesn't re-prompt on subsequent uses.
**Result:** [pending]

---

#### 6.4 Cloud Failure Recovery (CF-01, CF-02)

**Prerequisites:** Cloud provider configured, network disconnect or invalid API key to force failure.

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Disconnect WiFi / use invalid API key | Force cloud provider failure |
| 2 | Trigger cloud summarization | TCPReachability check fails (2s) |
| 3 | Verify CloudFailureSheet appears | Shows "{Provider} unreachable — network down" |
| 4 | Verify buttons | [Fall back to local] [Cancel] (no Retry — network unreachable) |
| 5 | Click "Fall back to local" | Pipeline switches to Ollama (if available) or skips summary |
| 6 | Reconnect WiFi, trigger with valid key, force rate limit (429) | RetryComposer attempts 3x with backoff |
| 7 | Verify CloudFailureSheet appears after 3 retries | Shows "OpenAI rate-limited" with [Retry] [Fall back to local] [Cancel] |
| 8 | Click "Retry" | Provider attempts again |

**Pass criteria:** Network unreachable skips retry, rate-limited shows retry, fallback works.
**Result:** [pending]

---

#### 6.5 iCloud Consent Sync (DISC-06, CON-03)

**Prerequisites:** Consent granted on macOS for `openai×llm`, iCloud Drive syncs `.unibrain/consent.json` to iPhone.

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On macOS: grant consent for OpenAI LLM (Task 6.3) | `.unibrain/consent.json` written with consent record |
| 2 | Wait for iCloud Drive sync (30s-2min) | consent.json syncs to iPhone |
| 3 | On iPhone: open Settings tab | Read-only provider info shows OpenAI as LLM provider |
| 4 | On macOS: revoke consent in Settings → Audit | consent.json updated, syncs to iPhone |
| 5 | Verify no file corruption on either device | consent.json valid JSON on both |

**Pass criteria:** Consent state syncs between devices without corruption.
**Result:** [pending]

---

#### 6.6 Zero Telemetry Verification (CLOUD-12)

**Prerequisites:** mitmproxy or Proxyman installed and configured for HTTPS interception.

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start mitmproxy with HTTPS interception | Proxy captures traffic |
| 2 | Launch unibrain on macOS | App starts normally |
| 3 | Observe traffic for 60 seconds idle | Zero outbound connections (no background telemetry) |
| 4 | Record a 10-second audio clip | Zero outbound connections (local recording only) |
| 5 | Stop recording, trigger local transcription | Zero outbound connections (whisper.cpp local) |
| 6 | Trigger cloud summarization (OpenAI) | ONLY `api.openai.com:443` traffic appears |
| 7 | Verify no other domains contacted | No analytics, telemetry, or tracking domains |

**Pass criteria:** Zero telemetry traffic during entire lifecycle. Only user-configured cloud provider endpoints contacted.
**Result:** [pending]

---

#### 6.7 Local-First Offline Test (DISC-05)

**Prerequisites:** MacBook with whisper.cpp model downloaded, vault configured.

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Turn off WiFi on MacBook | Network fully disconnected |
| 2 | Open unibrain menu bar popover | App functions normally (no network required) |
| 3 | Start recording (5 seconds) | AVAudioRecorder writes WAV to disk |
| 4 | Stop recording | Recording stops, file saved |
| 5 | Transcription begins | whisper.cpp loads model, transcribes, releases model |
| 6 | Classification runs | CourseClassifier maps via EventKit (local calendar) |
| 7 | Note written to vault | Markdown + YAML frontmatter appears in correct course folder |
| 8 | Open note in Obsidian | Note is valid, frontmatter is correct, transcript is present |
| 9 | Reconnect WiFi | Verify no retroactive telemetry sent (check mitmproxy) |

**Pass criteria:** Full pipeline works offline. No network dependency for local-first path.
**Result:** [pending]

---

#### 6.8 Settings Window Visual Verify (SET-01, SET-02)

**Prerequisites:** macOS app running.

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Settings (⌘, or "Settings…" button) | Settings window opens |
| 2 | Verify 5 tabs visible | General, Providers, Courses, Permissions, Audit |
| 3 | Press ⌘+1 through ⌘+5 | Each shortcut switches to the corresponding tab |
| 4 | Open General tab | Vault path, summarization toggle (Off default), Ollama status |
| 5 | Open Providers tab | LLM/ASR/Vision/TTS sections with pickers and API key fields |
| 6 | Open Courses tab | Current term, mapping table, add/delete buttons |
| 7 | Open Permissions tab | Mic/Calendar status, vault path, full disclosure text |
| 8 | Open Audit tab | AuditTrailStore scans vault, entries appear in table |
| 9 | Trigger cloud failure, then open Settings | Settings opens to Audit tab (context-aware per CF-04) |

**Pass criteria:** All 5 tabs render, shortcuts work, context-aware opening works.
**Result:** [pending]

---

### Deferred Items from Earlier Phases

#### 3.1 macOS Device Pipeline Verification (Phase 03 Task 4)

**Status:** Deferred from Phase 03
**Blocked by:** Apple Developer Program membership

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Launch unibrain on MacBook Neo | Menu bar icon appears |
| 2 | Click "Start Recording" | AVAudioRecorder begins WAV capture at 16kHz mono |
| 3 | Speak for 10 seconds | Recording timer advances, audio levels animate |
| 4 | Click "Stop Recording" | Recording stops, WAV file saved |
| 5 | Transcription begins automatically | whisper.cpp loads small.en, transcribes, releases |
| 6 | Classification runs | EventKit maps to course based on calendar |
| 7 | Note written to vault | Markdown file appears in correct course folder |
| 8 | Open note in Obsidian | Frontmatter, wiki-link to audio, transcript sections all present |

**Result:** [pending]

---

#### 4.1 Course Classification Smart Routing (Phase 04 Task 3)

**Status:** Deferred from Phase 04 (04-05 Task 3 — 8 scenarios)

| Scenario | Description | Expected |
|----------|-------------|----------|
| A | Single overlapping event | Correct course + tags |
| B | Multiple overlapping events | CourseSelector sheet appears |
| C | No overlapping events | UNCLASSIFIED, manual override |
| D | Adjacent events (5-min gap) | Pauses at .awaitingUserChoice |
| E | All-day event overlapping | Skip all-day events |
| F | Event with no location | No crash, uses title only |
| G | CourseMappingStore empty | Falls back to calendar title |
| H | Folder name sanitization | Special chars replaced correctly |

**Result:** [pending]

---

#### 5.1 iOS Background Recording Survival (Phase 05 Task 3)

**Status:** Deferred from Phase 05 (05-UAT.md items 1-3)

| Scenario | Description | Expected |
|----------|-------------|----------|
| 1 | Background recording (30 min) | Recording continues after screen lock |
| 2 | Call interruption (IOS-03) | Auto-pause on incoming call, auto-resume on decline |
| 3 | iCloud Drive handoff | iPhone recording appears on Mac, pipeline processes |

**Result:** [pending]

---

## Summary

total: 15
passed: 0
issues: 0
pending: 15
skipped: 0
blocked: 15

## Blockers

All items are blocked by:
1. **Apple Developer Program membership** ($99/yr) — needed for device deployment
2. **No Mac in dev loop** — WSL2 Linux dev environment cannot run macOS/iOS builds
3. **No physical iPhone** — device testing deferred

Once Apple Developer Program is active and Angelica's MacBook Neo is available for TestFlight:

1. Deploy to MacBook Neo via TestFlight
2. Deploy to iPhone via TestFlight
3. Run through all Phase 6 scenarios (6.1-6.8)
4. Run through deferred Phase 3 (3.1), Phase 4 (4.1), Phase 5 (5.1) scenarios
5. Document actual results in this file
6. Sign and date below

## Sign-off

Tester: _________________________
Date: _________________________
Result: [ ] PASS  [ ] FAIL (describe issues below)

Issues:
```
(Paste any issues encountered during testing)
```
