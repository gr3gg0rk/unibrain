# Phase 3: macOS Capture + Transcribe - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

The first end-to-end vertical slice ships on macOS. A user clicks the menu-bar record button, sees live confirmation (timer + waveform + mic-level meter), can pause/resume, stops the recording, and within minutes sees a transcript written as a Markdown note into a hardcoded vault folder — proving the `whisper.cpp`/SpeechAnalyzer integration, the `Task.detached` threading model, the 8GB RAM discipline (ASR model loaded only at inference time then released), and the full capture→transcribe→normalize→write pipeline on macOS.

**Hardcoded routing:** Phase 3 writes to `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md` with `course: UNCLASSIFIED`. No schedule-aware routing (Phase 4), no iOS capture (Phase 5), no summarization (Phase 6), no Settings UI (Phase 6).

**Phase 2 dependency:** Phase 3 assumes Phase 2 ships first — `NoteNormalizer`, `NoteWriter` protocol + `TestNoteWriter`, `PipelineOrchestrator` actor, `PipelineInputs`, and the segments-in contract (`N-03`) must exist before Phase 3 can wire them.

</domain>

<decisions>
## Implementation Decisions

### ASR Engine Selection (amends REQUIREMENTS TRAN-01)

- **P-01: SpeechAnalyzer is the PRIMARY ASR.** Apple's WWDC 2025 `SpeechAnalyzer` framework, available on macOS 26 (Tahoe) via `if #available(macOS 26, *)`, runs first for every recording. Zero third-party dependencies, Apple Intelligence-powered, A-series Neural Engine native, no model download needed (model ships with the OS). **This amends REQUIREMENTS TRAN-01** which originally locked `whisper.cpp + Metal` as the local ASR backend. Rationale: MacBook Neo is A-series (not M-series); the original 4.4x Metal speedup benchmark was M1-based; macOS 26 deployment target (D-05) unlocks SpeechAnalyzer; PROJECT.md Key Decisions explicitly deferred this re-evaluation to Phase 3.
- **P-02: whisper.cpp + small.en is the FALLBACK ASR, auto-triggered on SpeechAnalyzer error.** If SpeechAnalyzer throws (error, timeout, or unsupported on the running OS), the same recording transparently retries through whisper.cpp + small.en. Angelica never sees the failure — she just gets a transcript, possibly slower. The `small.en` model (~466MB disk, ~852MB runtime RAM) MUST be on disk before the first fallback can fire (see P-13).
- **P-03: Accuracy validation = trust + ship, fix forward.** SpeechAnalyzer on lecture content (long-form, accented, technical) is unproven. We ship it as primary without pre-validation. The auto-fallback (P-02) is the safety net. If Angelica reports bad transcripts on real lectures, we tune the fallback trigger or swap the primary in a later phase. **Minimum CI check** (Claude discretion): a `macos-15`/`macos-26` CI fixture test runs SpeechAnalyzer on a 60-90s Creative-Commons lecture audio file and asserts non-empty transcript output within a latency budget — catches build/runtime regressions, NOT accuracy validation.
- **P-04: whisper.cpp SPM package choice deferred to planner.** Research current state of `SwiftWhisper (exPHAT)` vs `ggml-org/whisper.cpp` official SPM at plan time. Pick based on Swift 6 compatibility, build complexity against Phase 3's risk threshold, and maintenance cadence. Planner presents the choice at plan-review.

### Engine Selection Architecture

- **P-05: Engine selection lives in a `TranscriberRouter` (or similarly-named) facade.** A thin selector wraps `SpeechAnalyzerTranscriber` + `WhisperCppTranscriber` and itself conforms to `AudioTranscriber`. The Orchestrator depends on `any AudioTranscriber` (unchanged from Phase 2 O-05) — it doesn't know which engine ran. Router logic: try SpeechAnalyzer; on throw, retry via whisper.cpp; if whisper.cpp also throws, propagate the whisper.cpp error (the more informative failure).
- **P-06: Auto-fallback re-transcribes the WHOLE recording.** SpeechAnalyzer and whisper.cpp produce different segment boundaries; partial-state pickup across engines is infeasible. On SpeechAnalyzer failure, whisper.cpp starts fresh on the full `.m4a`. Cost: worst-case latency = SpeechAnalyzer-failure-time + full-whisper.cpp-runtime. Acceptable for an edge case.
- **P-07: ModelLoadGate interaction.** whisper.cpp fallback requires `ModelLoadGate.acquire(.asr)` before loading (TRAN-06 releases after). SpeechAnalyzer likely DOESN'T need ModelLoadGate (Apple Intelligence model is OS-managed, not app-loaded) — planner to verify against Apple docs. If SpeechAnalyzer needs no gate, the Router only acquires when falling back.

### Menu-bar Recording UI

- **P-08: Menu-bar popover is the PRIMARY recording surface.** `MenuBarExtra` (.window style) holds the full recording UI. Angelica starts/stops from the menu-bar icon without switching away from Notes/PowerPoint. The main `WindowGroup` is minimal (app state indicator, future Settings entry point — Phase 6).
- **P-09: Recording-state popover layout = compact rows.** Stacked vertically in a ~280pt-wide popover: large timer at top → thin live waveform across the middle → horizontal mic-level meter (green/yellow/red segments) → `[Pause] [Stop]` buttons at bottom. All indicators visible at a glance (CAPT-05 "confirm lecturer is audible" without extra clicks). Waveform animation MUST stay off MainThread (TRAN-03).
- **P-10: Idle-state popover = status line + Record button.** Status line shows readiness: `Ready to record • small.en model downloaded • Microphone available` (or warnings if any precondition fails). Single large `[Record]` button below. Confirms the fallback model is present and mic permission is granted before her first lecture.
- **P-11: Transcribing-state popover = progress + system notification.** After Stop, popover shows `Transcribing… (est. ~2 min)` with a spinner and a disabled Record button (Phase 2 O-02 `.alreadyRunning` rejection enforces no concurrent run). On note-write completion, popover clears to `Ready` AND a macOS system notification fires (`Lecture transcript ready — opened in vault`).
- **P-12: Pause-state UI = distinct visual + Resume/Stop buttons.** When paused, the popover shows a paused icon, frozen timer, dimmed waveform, and `[Resume] [Stop]` buttons replace `[Pause] [Stop]`. CAPT-02 pause/resume timestamps preservation location is UNDECIDED — see Claude's Discretion (P-D1).

### Hardcoded Vault Path

- **P-13: Default vault root = `~/Documents/Unibrain/`.** User-visible, Obsidian-openable as a vault directly, iCloud-Drive-syncable if Angelica enables "Desktop & Documents in iCloud Drive" (System Setting). Phase 5's onboarding folder picker overrides this default; Phase 3 always falls back here if no picker has run.
- **P-14: Phase 3 note path = `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md`.** Flat unrouted-output folder. Frontmatter placeholders: `course: UNCLASSIFIED`, `course_name: Phase 3 Test`, `term: phase-3`. Phase 4 routes NEW recordings to `{vault}/{term}/{course}/`; existing Phase 3 notes stay in `lectures/` (no migration burden — Phase 3 notes are test artifacts).
- **P-15: Audio file sits alongside the note.** `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.m4a` per CAPT-06 and WRITE-03. Referenced via Obsidian wiki-link `![[YYYY-MM-DD-Lecture.m4a]]` inline in the note body (Phase 2 N-01 contract).
- **P-16: `_inbox/` is RESERVED for Phase 5 iCloud handoff INPUT.** Phase 3 must NOT write output notes to `_inbox/` — that folder is specifically for iPhone-originated audio awaiting macOS pipeline (Phase 5 success criterion). Reusing it for Phase 3 output would conflate input/output semantics.

### First-run Model Download

- **P-17: Background download after first launch.** The `small.en` model download starts automatically when the app first launches, runs silently in the background. Angelica can start recording IMMEDIATELY via SpeechAnalyzer (which doesn't need the model). Popover status line shows `Fallback model: downloading (40%)` so she can see progress. Within ~5 min of first launch (typical home network), the fallback is ready. If she's unlucky enough to hit a SpeechAnalyzer failure in the first few minutes, she sees a clear error instead of fallback (rare edge case, accepted).
- **P-18: Failure / checksum mismatch = retry once, then non-blocking warning.** On download failure OR SHA256 mismatch, auto-retry the download once. If still fails, surface a non-blocking warning in the popover status line: `Fallback model: download failed — [Retry]`. SpeechAnalyzer primary recording still works; the fallback is simply unavailable until Angelica clicks Retry (or the app's next launch retries). NEVER block recording on model availability.
- **P-19: Model storage at `~/Library/Application Support/Unibrain/models/ggml-small.en.bin`.** Persistent, hidden, follows macOS conventions for app resources. NOT `~/Library/Caches/` (macOS can purge Caches under storage pressure — would force a re-download of a 466MB file). Path is the same on iOS (sandboxed container's `Library/Application Support/`).

### Claude's Discretion

- **P-D1: CAPT-02 pause/resume timestamp preservation location.** Undecided between (a) inline transcript marker `[Paused 14:23–14:25]`, (b) new frontmatter field (would extend Phase 2 WRITE-02 schema — schema_version bump), or (c) `.m4a` metadata only (not visible in the note). Planner picks based on Angelica's likely consumption pattern and Phase 2 schema's extension cost.
- **P-D2: Audio file lifecycle.** Record directly to final destination, OR record to a temp directory and `rename(2)` on completion. Temp-then-move is safer against partial files from app crashes mid-recording.
- **P-D3: Menu-bar icon variations by state.**_idle / recording / paused / transcribing_ icon states (e.g., `brain` default, `brain.fill` red while recording, `brain.fill` yellow while paused). Standard SwiftUI `MenuBarExtra` `systemImage` + `label:` template.
- **P-D4: Keyboard shortcut to start/stop.** Global keyboard shortcut (e.g., ⌘⇧R) via `KeyboardShortcuts` SPM or native `NSEvent`/`UIKeyCommand`. Angelica's in-class UX value vs. implementation cost — defer if it adds complexity.
- **P-D5: Waveform rendering approach.** SwiftUI `Canvas` for the live waveform vs. pre-sampled buffer visualization. Must stay off MainThread per TRAN-03.
- **P-D6: Download source URL + SHA256 embedding.** HuggingFace (`huggingface.co/ggerulovas/whisper.cpp/...`) vs. GitHub releases (`github.com/ggml-org/whisper.cpp/releases/download/...`) vs. multi-source fallback chain vs. Greg-controlled mirror. SHA256 hash embedded in app binary as a `static let`. Planner researches current canonical source.
- **P-D7: macOS CI provisioning of `small.en`.** CI runner needs the model file to test whisper.cpp fallback. Download once per workflow run (cached via `actions/cache`), OR skip whisper.cpp tests on CI and rely on manual device testing. Planner decides based on CI minute budget.
- **P-D8: SpeechAnalyzer timeout budget.** How long does the Router wait for SpeechAnalyzer before declaring failure and falling back to whisper.cpp? Needs to distinguish "still working" from "hung". Planner picks a sensible default (e.g., 3x expected realtime).
- **P-D9: Speech framework API specifics.** `SpeechAnalyzer` (WWDC 2025, macOS 26) vs. legacy `SFSpeechRecognizer` (deprecated). Planner verifies the exact API shape, entitlement requirements, and on-device model availability.

### Folded Todos

None — no pending todos in `.planning/STATE.md` matched Phase 3 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Planning (in this repo)
- `.planning/PROJECT.md` — project definition, constraints, Key Decisions table (esp. "Phase 3 will re-evaluate vs SpeechAnalyzer / WhisperKit on MacBook Neo A-series" — this discussion IS that re-evaluation). MacBook Neo A-series / macOS 26 Tahoe / 8GB RAM constraints shape every Phase 3 decision.
- `.planning/REQUIREMENTS.md` §"Capture" — Phase 3 requirements: CAPT-01 (one-tap start/stop), CAPT-02 (pause/resume contiguous), CAPT-04 (live timer + waveform), CAPT-05 (mic meter), CAPT-06 (`.m4a` AAC export).
- `.planning/REQUIREMENTS.md` §"Transcribe" — Phase 3 requirements: TRAN-01 (AMENDED by P-01 — SpeechAnalyzer primary, whisper.cpp fallback), TRAN-02 (small.en download + checksum), TRAN-03 (Task.detached off MainThread), TRAN-04 (post-capture only), TRAN-05 (paragraph post-processing — lives in Phase 2 N-03/N-04), TRAN-06 (model released after transcription).
- `.planning/ROADMAP.md` §"Phase 3: macOS Capture + Transcribe" — phase goal, mode (mvp), depends-on (Phase 2), requirements, five success criteria.
- `.planning/STATE.md` §"Blockers/Concerns" — "whisper.cpp + Metal SPM integration flagged as riskiest technical step" (now mitigated by P-01 making SpeechAnalyzer primary).

### Phase 1 CONTEXT (decisions carried forward)
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-05 (macOS 26 / iOS 17 deployment targets, unlocks SpeechAnalyzer), D-07 (three SPM targets: `UnibrainCore` Foundation-only, `UnibrainProviders` macOS/iOS-only, `UnibrainApp` Xcode app), D-08 (test target split: `UnibrainProvidersTests` macOS-only), D-09 (Xcode app target not SPM executable), D-11..14 (ModelLoadGate acquire/release lease, deny-on-conflict), D-15..17 (four standalone provider protocols, `ProviderError`, single-shot async/throws).

### Phase 2 CONTEXT (contracts Phase 3 wires)
- `.planning/phases/02-pure-pipeline-logic/02-CONTEXT.md` — N-03 (segments-in contract: `NoteNormalizer` takes `[(start: TimeInterval, end: TimeInterval, text: String)]`; Phase 3's ASR adapter maps whisper.cpp/SpeechAnalyzer output into this shape), N-04 (3-second paragraph-break threshold), A-01..05 (`NoteWriter` protocol in `UnibrainCore`, `TestNoteWriter` Linux-runnable, macOS `NSFileCoordinatorNoteWriter` ships in Phase 3 `UnibrainProviders`), O-01..05 (`PipelineOrchestrator` actor, 8-state lifecycle, `PipelineInputs` value type with `recordingURL`/`recordingStart`/`recordingEnd`/`durationSeconds`/`source`/`events`).

### Existing Code (the assets Phase 3 extends)
- `Sources/UnibrainCore/Protocols/AudioTranscriber.swift` — Phase 1's standalone `AudioTranscriber` protocol (`associatedtype Request; associatedtype Response; func transcribe(_:) async throws -> Response`). Phase 3 ships TWO conformances in `UnibrainProviders`: `SpeechAnalyzerTranscriber` (primary) and `WhisperCppTranscriber` (fallback), wrapped by a `TranscriberRouter` facade (P-05).
- `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` — Phase 1's `actor ModelLoadGate` (acquire/release lease, deny-on-conflict). Phase 3 calls `acquire(.asr)` before whisper.cpp load; releases after transcription (TRAN-06). SpeechAnalyzer likely bypasses the gate (Apple Intelligence is OS-managed) — planner verifies (P-07).
- `Sources/UnibrainCore/ModelLoadGate/HeavyModelKind.swift` — `.asr` case (extended to `.vision` if Phase 2 vision ingestion ever needs it; not extended for SpeechAnalyzer since it bypasses the gate).
- `UnibrainApp/UnibrainApp.swift` — Phase 1's app shell with `WindowGroup { ContentView() }` + `MenuBarExtra("Unibrain", systemImage: "brain") { ... }`. Phase 3 replaces the placeholder menu-bar content with the real recording popover (P-08..P-12).
- `UnibrainApp/ContentView.swift` — Phase 1's placeholder ("Unibrain" title). Phase 3 makes this the minimal main-window surface (app state, future Settings entry).
- `Sources/UnibrainProviders/ProtocolDefaults/ProviderDefaults.swift` — Phase 1's protocol default extensions. Phase 3 may extend with engine-selection defaults.
- `Package.swift` — adds `SwiftWhisper` OR `ggml-org/whisper.cpp` SPM dependency (planner's pick, P-04) to `UnibrainProviders` only (NOT `UnibrainCore` — keeps the Linux-buildable invariant).

### External Documentation (consult during planning)
- [WWDC25: Bring advanced speech-to-text with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/) — primary ASR API, macOS 26 Tahoe.
- [Apple Speech framework reference](https://developer.apple.com/documentation/Speech) — `SpeechAnalyzer`, `SpeechTranscriber`, entitlement requirements.
- [whisper.cpp (ggml-org)](https://github.com/ggml-org/whisper.cpp) — fallback ASR, current v1.7.x+, Metal + CoreML support.
- [SwiftWhisper (exPHAT) on Swift Package Index](https://swiftpackageindex.com/exPHAT/SwiftWhisper) — SPM wrapper option (P-04).
- [argmax-oss-swift (WhisperKit)](https://swiftpackageindex.com/argmaxinc/argmax-oss-swift) — NOT chosen for Phase 3 but re-evaluated if SpeechAnalyzer+whisper.cpp underperforms.
- [AVAudioRecorder (Apple Developer)](https://developer.apple.com/documentation/avfaudio/avaudiorecorder) — recording API.
- [AVAudioSession (Apple Developer)](https://developer.apple.com/documentation/avfaudio/avaudiosession) — session/category management (`.playAndRecord`, `.default` mode).
- [MenuBarExtra (Apple Developer)](https://developer.apple.com/documentation/swiftui/menubarexa) — SwiftUI macOS menu-bar API.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`AudioTranscriber` protocol** (`Sources/UnibrainCore/Protocols/AudioTranscriber.swift`) — Phase 3 ships two conformances in `UnibrainProviders`. The `associatedtype Request`/`Response` pattern means each conformance defines its own I/O types; the `TranscriberRouter` (P-05) erases the associated types to present a single `any AudioTranscriber` to the Orchestrator.
- **`ModelLoadGate` actor** — Phase 3's whisper.cpp path calls `acquire(.asr)` before loading the small.en model, calls `release(.asr)` in a `defer` after transcription (TRAN-06). SpeechAnalyzer likely bypasses (Apple Intelligence model is OS-managed) — planner verifies.
- **`MenuBarExtra`** in `UnibrainApp.swift` — Phase 3 replaces the placeholder `Text("Unibrain — Phase 1 Shell")` with a real SwiftUI `View` rendering the recording popover (P-08..P-12).
- **Yams dependency** in `UnibrainCore` — Phase 3 reuses for frontmatter serialization (already wired in Phase 1).
- **Phase 2 contracts** (when shipped): `NormalizedNote`, `NoteWriter.write(_:to:)`, `PipelineOrchestrator.run(inputs:)`, `PipelineInputs`. Phase 3 supplies the inputs and wires the macOS-specific conformances.

### Established Patterns
- **Swift 6 strict concurrency** (`actor`, `Sendable`, `async/await`, structured concurrency) — Phase 3 leans on this for the recording session actor, the model download actor, and the `TranscriberRouter`. No exceptions.
- **Protocol-abstraction layer** — every Apple-framework-specific concern (AVFoundation, Speech, NSFileCoordinator) lives behind a protocol in `UnibrainCore`; macOS conformances ship in `UnibrainProviders`. Phase 3's `NSFileCoordinatorNoteWriter` and both `AudioTranscriber` conformances follow this exactly.
- **`#if canImport(...)` / `if #available(...)` guards** — `SpeechAnalyzer` requires `if #available(macOS 26, *)`; whisper.cpp has no availability constraint but does require Apple frameworks for Metal/CoreML.
- **Acquire/release lease** for shared-resource gating — Phase 3 uses it for whisper.cpp model load/unload.
- **swift-testing framework** — `@Test`, `#expect`. Phase 3's macOS-only tests in `UnibrainProvidersTests` continue this pattern.
- **macOS CI matrix** — `macos-15` runner (Xcode 16.x) is the current path; Phase 3 may need `macos-26` runner (or `depot-macos-26`) if SpeechAnalyzer requires macOS 26 to execute. Planner verifies runner availability.

### Integration Points
- **`UnibrainApp` is the consumer-facing entry point.** Phase 1 shipped empty shell; Phase 3 adds the menu-bar record button + popover; Phase 6 adds Settings.
- **`.github/workflows/ci.yml`** — Phase 3 extends the macOS job with the new `UnibrainProvidersTests` cases (SpeechAnalyzer smoke test, whisper.cpp fixture test if model is provisioned per P-D7).
- **`Package.swift`** — Phase 3 adds the chosen whisper.cpp SPM dependency to `UnibrainProviders` (P-04).
- **`PipelineOrchestrator`** (Phase 2) — Phase 3 wires the menu-bar Stop button to `orchestrator.cancel()`, and constructs `PipelineInputs` from the capture session + fetched calendar events (calendar empty in Phase 3 — `events: []`, deferred to Phase 4).
- **`NoteWriter`** (Phase 2) — Phase 3 ships `NSFileCoordinatorNoteWriter` conformance in `UnibrainProviders`, wired into the Orchestrator.

</code_context>

<specifics>
## Specific Ideas

- **The SpeechAnalyzer-first decision is the most consequential Phase 3 outcome.** It deviates from REQUIREMENTS TRAN-01 (which locked whisper.cpp + Metal) based on PROJECT.md's explicit deferral. The planner MUST update REQUIREMENTS.md TRAN-01 and the traceability table to reflect "SpeechAnalyzer primary + whisper.cpp fallback" before Phase 3 plans execute. This is a documented scope amendment, not scope creep — Phase 3 IS the re-evaluation point.
- **The `TranscriberRouter` facade is the architectural keystone.** By wrapping both engines behind a single `any AudioTranscriber` conformance, the Orchestrator stays engine-agnostic. Phase 6's per-modality provider selector (CLOUD-01) can later swap the Router itself for a user-configured provider, with zero Orchestrator changes.
- **Auto-fallback re-transcribes the whole recording (P-06).** This is a deliberate simplification — partial-state handoff between SpeechAnalyzer and whisper.cpp is infeasible given different segment boundaries. Worst-case latency (SpeechAnalyzer-failure-time + full-whisper.cpp-runtime) is acceptable for an edge case.
- **Trust + ship (P-03) is internally consistent with auto-fallback (P-02).** Angelica never sees a SpeechAnalyzer failure (silent retry). If SpeechAnalyzer produces a BAD-but-non-erroring transcript, that's the risk we accept — and the planner should add a "Regenerate with whisper.cpp" action (cheap future improvement, NOT Phase 3 scope) to the eventual Settings UI.
- **`lectures/` folder is ephemeral test output.** Phase 4 starts fresh with `{vault}/{term}/{course}/` routing. Phase 3 notes are test artifacts; no migration burden. This keeps Phase 4's scope clean.
- **Background model download (P-17) is the key UX decision** that enables "record immediately on first launch." Angelica's first experience isn't gated by a 466MB download. The tradeoff: in the first ~5 minutes, if SpeechAnalyzer fails, she sees an error instead of a fallback (accepted rare edge case).
- **Phase 2 dependency is load-bearing.** Phase 3 cannot ship until Phase 2's `NoteNormalizer`, `NoteWriter` protocol, `PipelineOrchestrator`, and `PipelineInputs` exist. Planner must verify Phase 2 completion before starting Phase 3 execution.
- **MacBook Neo A-series chip is the underlying hardware reality.** Metal benchmark figures from research were M1-based; A-series Neural Engine may favor CoreML/ANE paths. SpeechAnalyzer sidesteps the question entirely (Apple Intelligence is OS-optimized for the hardware). whisper.cpp + Metal remains a viable fallback even on A-series — just potentially not the fastest path.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The following items were considered but explicitly belong in other phases:

- **Settings UI provider selector (per-modality LLM/ASR/Vision/TTS)** → Phase 6 (CLOUD-01). Phase 3's `TranscriberRouter` is the architectural precursor; Phase 6 makes it user-configurable.
- **"Regenerate transcript with whisper.cpp" user action** → Phase 6 polish. Phase 3 auto-falls-back silently; explicit user-initiated regeneration is a later UX nicety.
- **Title → course-code mapping table (CLAS-02)** → Phase 4. Phase 3 writes `course: UNCLASSIFIED`.
- **Schedule-aware routing** → Phase 4. Phase 3 writes to `lectures/`.
- **iOS background recording** → Phase 5 (CAPT-03). Phase 3 is macOS-only.
- **Vault folder picker onboarding** → Phase 5 (ONBD-01, ONBD-04). Phase 3 hardcodes `~/Documents/Unibrain/`.
- **Live transcript display** → Out of scope per TRAN-04 (deliberate RAM tradeoff). Phase 3 is post-capture transcription only.
- **WhisperKit as a third engine option** → Re-evaluate if SpeechAnalyzer + whisper.cpp both underperform on Angelica's real lectures. NOT Phase 3 scope.
- **Streaming ASR (live segments during recording)** → v2 per Phase 1 D-17. Phase 3 is single-shot post-capture.
- **iPad-native capture** → Phase 5+ (PROJECT.md Out of Scope for MVP).
- **Cloud ASR providers (OpenAI Whisper-1, etc.)** → Phase 6 (CLOUD-03..06). Phase 3 ships only the two local engines.
- **Multi-speaker diarization** → v2 (PROJECT.md Out of Scope). Phase 3 assumes single-lecturer audio.
- **Confidence score in transcript** → v2. Angelica doesn't need a confidence bar in MVP.

### Reviewed Todos (not folded)

None — no todos existed in `.planning/STATE.md` §"Pending Todos" at discussion time.

</deferred>

---

*Phase: 3-macOS Capture + Transcribe*
*Context gathered: 2026-07-14*
