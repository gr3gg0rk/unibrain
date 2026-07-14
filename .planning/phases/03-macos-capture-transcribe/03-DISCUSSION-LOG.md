# Phase 3: macOS Capture + Transcribe - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 3-macOS Capture + Transcribe
**Areas discussed:** ASR engine choice, Menu-bar recording UI, Hardcoded vault path, First-run model download

---

## ASR engine choice

### Q1: Which engine is the PRIMARY ASR for Phase 3?

| Option | Description | Selected |
|--------|-------------|----------|
| SpeechAnalyzer primary + whisper.cpp fallback | Apple-native (WWDC 2025, macOS 26 Tahoe). Zero third-party deps, fastest on A-series Neural Engine. whisper.cpp + small.en retained as fallback. Ships TWO backends. | ✓ |
| whisper.cpp + Metal only (as planned) | Current REQUIREMENTS TRAN-01 plan. Battle-tested, simplest SPM integration. 4.4x Metal speedup figure was M1-based. | |
| whisper.cpp + CoreML encoder | whisper.cpp engine with CoreML encoder on ANE (~3x speedup). Two model artifacts to manage. | |
| WhisperKit (full CoreML) | argmaxinc — compiles encoder+decoder to CoreML. Max ANE utilization. Newer SPM, more setup friction. | |

**User's choice:** SpeechAnalyzer primary + whisper.cpp fallback
**Notes:** This is the option PROJECT.md was pointing toward ("Phase 3 will re-evaluate vs SpeechAnalyzer / WhisperKit on MacBook Neo A-series"). Accepts the cost of shipping two backends in Phase 3. Amends REQUIREMENTS TRAN-01.

---

### Q2: How does the runtime decide which engine to use for a given recording?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-fallback on SpeechAnalyzer error | If SpeechAnalyzer throws, automatically retry the same recording through whisper.cpp. Angelica never sees the failure. | ✓ |
| OS-version gate (`if #available`) | `if #available(macOS 26, *)` → SpeechAnalyzer; else → whisper.cpp. Angelica's MacBook Neo always uses SpeechAnalyzer; fallback never exercised on her hardware. | |
| Both wired, SpeechAnalyzer live, whisper.cpp verified-by-test only | whisper.cpp exists and is tested on CI but is dormant in the live app until Phase 6 provider selector. | |
| SpeechAnalyzer live, whisper.cpp as stub | whisper.cpp conforms to AudioTranscriber but throws `.unavailable`. Fallback is aspirational. | |

**User's choice:** Auto-fallback on SpeechAnalyzer error
**Notes:** Most robust UX. Means the small.en model must be on disk before the first fallback can fire (addresses in First-run model download area). Worst-case latency = SpeechAnalyzer-failure-time + full-whisper.cpp-runtime (whole-recording re-transcription, accepted).

---

### Q3: SpeechAnalyzer-on-lectures is unproven. How do we validate accuracy before locking it in as primary?

| Option | Description | Selected |
|--------|-------------|----------|
| CI fixture test (macOS runner) | macos-15/macos-26 runner runs SpeechAnalyzer on fixture lecture audio on every push. Catches regressions but doesn't validate Angelica's real content. | |
| Angelica-facing debug mode | 'test transcript' mode she can run on her device before first real lecture. Relies on her availability. | |
| Dual-run shadow comparison on first 3 real lectures | First 3 lectures silently run both engines; Greg reviews both transcripts; locks primary based on observed quality. | |
| Trust + ship, fix forward | Trust Apple's claims. Ship as primary. Fix forward if Angelica reports issues. Auto-fallback is the safety net. | ✓ |

**User's choice:** Trust + ship, fix forward
**Notes:** The auto-fallback is the safety net. Planner should still add a minimal CI smoke test (non-empty transcript on fixture audio) to catch build/runtime regressions — but that's a build-breakage check, not accuracy validation.

---

### Q4: For the whisper.cpp fallback integration, which SPM package?

| Option | Description | Selected |
|--------|-------------|----------|
| SwiftWhisper (exPHAT) SPM | Zero-dependency SPM wrapper. Easiest. May lag upstream. | |
| Official whisper.cpp SPM (ggml-org) | Direct from source. Stays at latest. More manual SPM configuration. | |
| Direct C binding (manual XCFramework) | Max control. Significant integration effort. | |
| Defer to planner (research both, decide at planning) | Planner researches current SPM state for both, evaluates against Phase 3 risk threshold, picks at plan-review time. | ✓ |

**User's choice:** Defer to planner (research both, decide at planning)
**Notes:** Consistent with treating whisper.cpp as fallback (simplicity > maximum control). Planner has research budget to evaluate Swift 6 compatibility and build complexity of both options.

---

## Menu-bar recording UI

### Q1: Which surface is primary for Angelica's actual in-class recording?

| Option | Description | Selected |
|--------|-------------|----------|
| Menu-bar popover primary, window minimal | MenuBarExtra popover is primary recording surface. Discreet, doesn't obstruct lecture app. Main window is minimal (app state). | ✓ |
| Full window primary, menu-bar opens it | Voice Memos / QuickTime style. Larger visualization. Less discreet. | |
| Symmetric — both surfaces, same UI | Both render the same recording UI, sync via shared @Observable RecordingSession. | |

**User's choice:** Menu-bar popover primary, window minimal
**Notes:** Angelica is recording during lectures — discreet menu-bar access matters. Current app shell has both WindowGroup + MenuBarExtra; Phase 3 keeps both but makes menu-bar the real surface.

---

### Q2: Recording-state popover layout?

| Option | Description | Selected |
|--------|-------------|----------|
| Compact rows (timer / waveform / meter / buttons) | Stacked: large timer, thin waveform, mic meter, [Pause][Stop]. All visible at a glance. Matches CAPT-05 'glance to confirm mic is hot' UX. | ✓ |
| Visual-first (waveform centerpiece) | Animated waveform dominates. Timer overlays. Mic as badge. Prettier; more SwiftUI canvas code. | |
| Minimal + expand for detail | Default: timer + stop. Chevron reveals waveform + meter. Less noisy; extra friction. | |

**User's choice:** Compact rows (timer / waveform / meter / buttons)
**Notes:** CAPT-05 explicitly wants Angelica to confirm the lecturer is audible without extra clicks. Compact rows fit a ~280pt popover.

---

### Q3: What does the popover show when Angelica opens it BEFORE recording (idle state)?

| Option | Description | Selected |
|--------|-------------|----------|
| Status + Record button | Status line (model + mic readiness) above single large Record button. Confirms fallback model is present. | ✓ |
| Just a Record button | Minimal, zero friction. No readiness confirmation. | |
| Status + Record + recent list | Status + Record at top; recent recordings list below with 'Open in Obsidian' links. | |
| Status only, no Record button | No in-popover Record; recording started via shortcut/window. Deviates from CAPT-01. | |

**User's choice:** Status + Record button
**Notes:** Readiness confirmation matters given Phase 3 ships the dual-engine setup. Recent-recordings list deferred to Phase 6 polish.

---

### Q4: What does Angelica see during transcription (after Stop, before note appears)?

| Option | Description | Selected |
|--------|-------------|----------|
| Popover progress + system notification | 'Transcribing…' spinner + disabled Record button; on completion, system notification fires. Clear feedback during class + proactive ping when done. | ✓ |
| Progress bar, no notification | Segment-progress bar (engine-dependent granularity). She has to check popover to know it's done. | |
| Background-only + system notification | Popover returns to Ready immediately. ONLY system notification signals completion. No visible working state. | |
| Auto-open the note on completion | On completion, note opens in Obsidian (or Finder). Could be intrusive. | |

**User's choice:** Popover progress + system notification
**Notes:** Clear visible 'working' state + proactive ping when done. Phase 2 O-02 .alreadyRunning rejection enforces disabled Record button during transcription.

---

## Hardcoded vault path

### Q1: Where does Phase 3 write notes by default?

| Option | Description | Selected |
|--------|-------------|----------|
| ~/Documents/Unibrain/ | User-visible, Obsidian-openable as vault. iCloud-Drive-syncable if 'Desktop & Documents' enabled. Phase 5 picker overrides. | ✓ |
| ~/Library/Application Support/Unibrain/vault/ | Sandbox-friendly. NOT iCloud-syncable by default. Hidden; Angelica must manually point Obsidian there. | |
| Minimal folder picker at first launch | One-question folder picker pre-onboarding. Suggests ~/Documents/Unibrain/. Slightly blurs Phase 3/5 boundary. | |
| Config-file path (no UI) | Hardcode in Config.swift. Not user-friendly; Phase 3 is a vertical slice. | |

**User's choice:** ~/Documents/Unibrain/
**Notes:** Cleanest path, Obsidian-idiomatic, zero friction for Phase 3 testing. Phase 5 picker overrides for Angelica's real iCloud-synced vault.

---

### Q2: Folder structure + course/term placeholders for Phase 3 notes?

| Option | Description | Selected |
|--------|-------------|----------|
| `lectures/` folder + UNCLASSIFIED frontmatter | Path: ~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md. course: UNCLASSIFIED, term: phase-3. Clear unrouted-output semantics. Phase 4 routes new recordings; existing stay. | ✓ |
| Full Phase 4 structure with placeholder values | ~/Documents/Unibrain/2026-Fall/PHASE3-TEST/... Tests path-construction code. Creates real-looking folders Phase 4 must reuse or clean. | |
| Flat at vault root | ~/Documents/Unibrain/YYYY-MM-DD-Lecture.md. Simplest. Clutter at root. | |
| `_inbox/` folder (reuses Phase 5 staging) | Conflates input (iPhone audio) and output (Phase 3 notes) semantics. | |

**User's choice:** `lectures/` folder + UNCLASSIFIED frontmatter
**Notes:** `_inbox/` is RESERVED for Phase 5 iPhone-input staging. `lectures/` is clearly unrouted-output. Phase 4 starts fresh with `{term}/{course}/`; no migration needed.

---

## First-run model download

### Q1: When does the small.en model download happen?

| Option | Description | Selected |
|--------|-------------|----------|
| Background download after first launch | Starts silently on first launch. Angelica can record immediately via SpeechAnalyzer. Status line shows progress. Ready within ~5 min. | ✓ |
| Blocking modal before first record | Modal blocks recording until download + checksum complete. Guarantees fallback ready. Multi-minute wait before first record. | |
| Bundle model inside app binary | No download ever. App install ~500MB+ larger. iOS cellular-download limits may force Wi-Fi. | |
| Lazy download on first fallback failure | Don't download until SpeechAnalyzer fails. First failure triggers 466MB inline download. Worst UX for edge case. | |

**User's choice:** Background download after first launch
**Notes:** Enables "record immediately on first launch." Tradeoff: if SpeechAnalyzer fails before download completes (rare), Angelica sees an error instead of fallback — accepted.

---

### Q2: What happens if the background download fails or the checksum doesn't match?

| Option | Description | Selected |
|--------|-------------|----------|
| Retry once, then non-blocking warning | Auto-retry once on failure or checksum mismatch. If still fails, surface warning in popover status. SpeechAnalyzer primary still works; fallback unavailable until retry. | ✓ |
| Exponential backoff retry, persistent | Auto-retry with 1s/2s/4s/8s/16s... up to 5 min intervals until success. Most resilient. Burns cycles if network is genuinely broken. | |
| Modal error, block recording | Block recording until model is downloaded. Violates 'SpeechAnalyzer works without the model' principle. | |
| Checksum mismatch → delete + retry once | Specific to checksum failure: delete corrupted file, retry once, then warning. Two-layer integrity. | |

**User's choice:** Retry once, then non-blocking warning
**Notes:** SpeechAnalyzer primary recording NEVER blocked by model availability. Fallback is best-effort. Checksum mismatch path folded into the same retry-once flow.

---

## Claude's Discretion

Areas where the user deferred to Claude / planner:

- **P-D1: CAPT-02 pause/resume timestamp preservation location** — inline transcript marker vs. frontmatter extension vs. .m4a metadata only.
- **P-D2: Audio file lifecycle** — record-direct-to-final vs. temp-then-move (safer against crashes).
- **P-D3: Menu-bar icon variations by state** — idle/recording/paused/transcribing systemImage variations.
- **P-D4: Keyboard shortcut to start/stop** — global shortcut via KeyboardShortcuts SPM or native NSEvent/UIKeyCommand.
- **P-D5: Waveform rendering approach** — SwiftUI Canvas vs. pre-sampled buffer visualization.
- **P-D6: Download source URL + SHA256 embedding** — HuggingFace vs. GitHub releases vs. mirror vs. multi-source chain.
- **P-D7: macOS CI provisioning of small.en** — download-once-per-run with actions/cache vs. skip whisper.cpp tests on CI.
- **P-D8: SpeechAnalyzer timeout budget** — how long Router waits before declaring failure and falling back.
- **P-D9: Speech framework API specifics** — SpeechAnalyzer vs. legacy SFSpeechRecognizer, entitlement requirements, on-device model availability.

## Deferred Ideas

Ideas mentioned during discussion that were noted for future phases:

- Settings UI provider selector (per-modality) → Phase 6 (CLOUD-01)
- "Regenerate transcript with whisper.cpp" user action → Phase 6 polish
- Title → course-code mapping table → Phase 4 (CLAS-02)
- Schedule-aware routing → Phase 4
- iOS background recording → Phase 5 (CAPT-03)
- Vault folder picker onboarding → Phase 5 (ONBD-01, ONBD-04)
- Live transcript display → Out of scope per TRAN-04
- WhisperKit as a third engine option → Re-evaluate if both engines underperform
- Streaming ASR → v2 per Phase 1 D-17
- iPad-native capture → Phase 5+
- Cloud ASR providers → Phase 6 (CLOUD-03..06)
- Multi-speaker diarization → v2
- Confidence score in transcript → v2
