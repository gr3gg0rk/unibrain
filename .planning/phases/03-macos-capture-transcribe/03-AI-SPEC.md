# AI-SPEC — Phase 3: macOS Capture + Transcribe

> AI design contract. Consumed by `gsd-planner` and `gsd-eval-auditor`.
> Locks framework selection, implementation guidance, and evaluation strategy before planning begins.

---

## 1. System Classification

**System Type:** Extraction (Speech-to-Text / ASR)

**Description:**
A local-first speech-to-text system that transcribes university lecture recordings (30–90 min M4A audio) on a MacBook Neo (A-series, 8GB unified memory, macOS 26 Tahoe). The primary engine is Apple's `SpeechAnalyzer` (WWDC 2025, Apple Intelligence-powered, OS-managed model); the fallback is `whisper.cpp` with the `small.en` model (Metal-accelerated, app-managed model loaded only at inference time). A `TranscriberRouter` facade wraps both engines behind a single `any AudioTranscriber` conformance so the `PipelineOrchestrator` (Phase 2) stays engine-agnostic. Output is a list of timestamped transcript segments fed into Phase 2's `NoteNormalizer`.

**Critical Failure Modes:**
1. SpeechAnalyzer throws on long-form / accented / technical lecture audio and the fallback fails to trigger (silent data loss).
2. whisper.cpp model loads while SpeechAnalyzer is still holding resources → OOM on 8GB (8GB RAM discipline violated).
3. Transcript segments arrive with wrong timestamp shape → `NoteNormalizer` contract violation (Phase 2 N-03).
4. UI freezes during transcription because work leaks onto MainThread (violates TRAN-03).
5. Model file corrupted on disk (SHA256 mismatch) → fallback silently produces garbage or crashes.

---

## 1b. Domain Context

**Industry Vertical:** Education (university lecture capture for a single student).

**User Population:** Angelica — incoming university freshman, MacBook Neo (A-series, 8GB RAM, macOS 26), non-technical. Records lectures in class, expects transcripts in her Obsidian vault without any manual organization. Same shape later serves Isabella (master's program).

**Stakes Level:** Medium. A bad or missing transcript is a wasted lecture — costly but recoverable (Angelica has her notes, can re-record). Not safety-critical, not financial.

**Output Consequence:** Transcript lands as a Markdown note in `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md` with YAML frontmatter. Angelica reads it for study. Phase 4 will route future recordings to course-specific folders; Phase 3 output stays in `lectures/` (test artifacts).

### What Domain Experts Evaluate Against

| Dimension | Good (expert accepts) | Bad (expert flags) | Stakes | Source |
|-----------|----------------------|-------------------|--------|--------|
| Word accuracy on clear single-speaker audio | ≥ 90% of words correct vs. ground truth (rough whisper.cpp small.en / SpeechAnalyzer baseline on clean lecture audio) | < 70% — too many garbled words to study from | High | whisper.cpp small.en published WER (~4-5% on clean English), Apple SpeechAnalyzer marketing claims (unverified on lecture content) |
| Paragraph segmentation | Breaks at natural topic boundaries (Phase 2 N-04 3-second gap threshold) | Wall of text, or breaks mid-sentence | Medium | Phase 2 NoteNormalizer contract |
| Timestamp drift | Segment timestamps within ±2s of actual audio position | Timestamps meaningless / monotonic but wrong | Medium | Phase 2 N-03 segments-in contract |
| Latency on 60-min lecture | Transcript ready within 3× realtime (≤ 3 min on Apple Intelligence; ≤ 20 min via whisper.cpp small.en fallback) | > 10× realtime — Angelica gives up waiting | Medium | Apple SpeechAnalyzer realtime claims; whisper.cpp small.en ~3× realtime on Metal (M1 benchmark — A-series unverified) |
| Proper-noun / technical-term handling | Recognizes common technical terms from the lecture domain (not required to be perfect) | Produces phonetically implausible garbage for common terms | Low (accepted loss for MVP) | Trust-and-ship per CONTEXT P-03 |

### Known Failure Modes in This Domain

- Long-form audio → engine loses context or hits internal timeouts. SpeechAnalyzer is unproven on 60–90 min lecture audio; whisper.cpp handles it but is slower.
- Accented English / non-native lecturers → WER degrades. whisper.cpp small.en is an English-only model; SpeechAnalyzer's multilingual behavior on macOS 26 is undocumented for this use case.
- Technical vocabulary (discipline-specific jargon) → both engines produce phonetically plausible but wrong words. Accepted loss for MVP; "Regenerate with whisper.cpp" deferred to Phase 6 Settings.
- Room acoustics (large lecture hall, echo, distant mic) → accuracy drops. Mic-level meter (CAPT-05) is the mitigation — Angelica can see if she's audible before trusting the transcript.
- Simultaneous speakers / student questions → single-speaker assumption violated. Diarization is v2 (PROJECT.md Out of Scope). Phase 3 assumes single-lecturer audio.

### Regulatory / Compliance Context

**None identified.** Single-user, local-first, no PII leaving the device. Audio stays on disk; transcripts stay in the vault. FERPA / student-record rules do not apply to a student's own recordings for personal study. Cloud ASR providers are explicitly Phase 6 and gated behind per-modality consent — Phase 3 ships local-only.

### Domain Expert Roles for Evaluation

| Role | Responsibility |
|------|---------------|
| Angelica (end user, subject matter expert on her own lectures) | UAT: spot-check transcript quality on her real recordings during the first 2 weeks of classes; report bad transcripts |
| Claude (automated eval) | CI smoke test: assert non-empty transcript + timestamp shape on a fixture; not an accuracy gate |
| Greg (developer) | Pre-release device test on MacBook Neo; tune fallback trigger timeout (P-D8) if SpeechAnalyzer hangs |

---

## 2. Framework Decision

**Selected Framework:** Dual-engine — **Apple `SpeechAnalyzer`** (primary) + **whisper.cpp** (fallback).

**Versions:**
- `SpeechAnalyzer`: ships with macOS 26 Tahoe (WWDC 2025 API; no separate version — OS-managed model)
- `whisper.cpp`: v1.7.x+ (target v1.9.x); integrated via SPM (SwiftWhisper exPHAT or ggml-org/whisper.cpp official — planner's pick per CONTEXT P-04)
- Model: `ggml-small.en.bin` (~466 MiB disk, ~852 MB runtime RAM, English-only, ~4–5% WER on clean audio)

**Rationale:**
- **SpeechAnalyzer primary** — zero third-party dependencies, Apple Intelligence-powered, A-series Neural Engine native, no model download gating first-run UX. MacBook Neo is A-series (not M-series); the original Metal 4.4× speedup benchmark was M1-based (CONTEXT P-01), so SpeechAnalyzer (OS-optimized for A-series) is the better-matched primary path.
- **whisper.cpp fallback** — mature, battle-tested, well-understood RAM footprint. Auto-triggered on SpeechAnalyzer error (CONTEXT P-02). `small.en` is the recommended sweet spot on 8GB (CLAUDE.md model table).
- **TranscriberRouter facade** (CONTEXT P-05) — wraps both engines behind `any AudioTranscriber`. Orchestrator stays engine-agnostic. Phase 6's cloud provider selector can later swap the Router itself.

**Alternatives Considered:**

| Framework | Ruled Out Because |
|-----------|------------------|
| WhisperKit (argmaxinc) | Deeper ANE integration but more setup friction (pre-converted CoreML models). Re-evaluate in Phase 2 (post-MVP) if SpeechAnalyzer + whisper.cpp underperforms. NOT riskiest-step material for Phase 3. |
| MLX-Whisper | Python-based — requires embedding Python runtime in a SwiftUI app. Violates Apple-native mandate (CLAUDE.md "What NOT to Use"). |
| Apple `SFSpeechRecognizer` (legacy) | Weaker accuracy on long-form / lecture content. Deprecated in iOS 26. Only viable as a quick fallback; SpeechAnalyzer supersedes it. |
| Cloud ASR (OpenAI Whisper-1, etc.) | Violates local-first mandate for Phase 3. Deferred to Phase 6 (CLOUD-03..06) with explicit consent gate. |
| whisper.cpp as PRIMARY (not fallback) | Original REQUIREMENTS TRAN-01 locked this; CONTEXT P-01 amends it. whisper.cpp is the safety net, not the primary, because SpeechAnalyzer avoids the 466MB model-download gating UX. |

**Vendor Lock-In Accepted:** Partial. SpeechAnalyzer locks us to macOS 26+ (deployment target D-05 already set). whisper.cpp is portable C/C++ — no lock-in. The `AudioTranscriber` protocol abstraction means either engine is independently replaceable.

---

## 3. Framework Quick Reference

> Distilled from Apple Developer docs + whisper.cpp repo for this specific use case (single-shot post-capture lecture transcription on macOS 26 / A-series).

### Installation

**SpeechAnalyzer:** No install — ships with macOS 26 Tahoe. Add Speech framework to Xcode target; gate calls with `if #available(macOS 26, *)`.

**whisper.cpp via SPM** (planner picks one — CONTEXT P-04):
```swift
// Option A: SwiftWhisper (exPHAT) — zero-dependency wrapper, pre-bundles whisper.cpp
.package(url: "https://github.com/exPHAT/SwiftWhisper.git", from: "latest")

// Option B: official ggml-org/whisper.cpp SPM target
.package(url: "https://github.com/ggml-org/whisper.cpp.git", branch: "master")
```

Add the dependency to the `UnibrainProviders` target ONLY (not `UnibrainCore` — keeps Linux-buildable invariant, CONTEXT code_context).

### Core Imports

```swift
// SpeechAnalyzer (primary) — macOS 26+
import Speech  // SpeechAnalyzer, SpeechTranscriber (macOS 26+ API)

// whisper.cpp fallback
import SwiftWhisper  // OR whisper.cpp C bridge directly

// Shared
import AVFoundation  // AVAudioFile, AVAsset
import UnibrainCore   // AudioTranscriber protocol, ModelLoadGate, TranscriptSegment
```

### Entry Point Pattern

```swift
// SpeechAnalyzerTranscriber (primary) — Conceptual shape; planner verifies against macOS 26 API
if #available(macOS 26, *) {
    let analyzer = SpeechAnalyzer()  // OS-managed, no ModelLoadGate needed (CONTEXT P-07)
    let transcript = try await analyzer.transcribe(audioURL: m4aURL)
    // Map SpeechTranscriber output → [(start: TimeInterval, end: TimeInterval, text: String)]
} else {
    // macOS < 26 not supported per D-05 deployment target — this branch is unreachable
    throw ProviderError.unsupportedPlatform
}

// WhisperCppTranscriber (fallback) — Conceptual shape
let gate = ModelLoadGate.shared
try await gate.acquire(.asr)  // CONTEXT P-07 / TRAN-06
defer { gate.release(.asr) }

let whisper = Whisper(modelPath: modelURL.path)  // ~/Library/Application Support/Unibrain/models/ggml-small.en.bin
let segments = try await whisper.transcribe(audioPath: m4aURL.path)  // Metal-accelerated

// Both engines emit [(start, end, text)] — Phase 2 NoteNormalizer consumes this shape (N-03)
```

### Key Abstractions

| Concept | What It Is | When You Use It |
|---------|-----------|-----------------|
| `TranscriberRouter` | Facade conforming to `AudioTranscriber`. Tries SpeechAnalyzer; on throw retries via whisper.cpp; propagates whisper.cpp error if both fail (CONTEXT P-05). | Always — Orchestrator depends on `any AudioTranscriber` and gets the Router. |
| `SpeechAnalyzer` (macOS 26+) | Apple's on-device ASR. OS-managed model (Apple Intelligence). No app-loaded model file. | Primary path for every recording on macOS 26+. |
| `ModelLoadGate.acquire(.asr)` | Phase 1 actor lease — denies concurrent heavy-model loads to protect 8GB RAM budget. | Required before whisper.cpp load; likely NOT needed for SpeechAnalyzer (CONTEXT P-07 — planner verifies). |
| `ggml-small.en.bin` | whisper.cpp English-only model, 466 MiB disk, ~852 MB runtime RAM. | Loaded transiently during fallback transcription; released in `defer` (TRAN-06). |
| `Task.detached` | Swift 6 structured concurrency — keeps transcription off MainThread (TRAN-03). | Every transcription call. |

### Common Pitfalls

1. **SpeechAnalyzer availability check missing** — code compiles on macOS 26 SDK but crashes on older OS. Always `if #available(macOS 26, *)`. Deployment target D-05 is macOS 26 so this is belt-and-suspenders, not a real branch.
2. **whisper.cpp model file left loaded** — 852 MB RAM held indefinitely → OOM on next operation. `gate.release(.asr)` MUST be in `defer` (TRAN-06).
3. **SpeechAnalyzer + whisper.cpp loaded simultaneously** — if SpeechAnalyzer hangs and Router times out into fallback without releasing (SpeechAnalyzer holds no gate, but if planner discovers it DOES need one), both models compete for RAM. Router logic must guarantee SpeechAnalyzer task is cancelled before whisper.cpp load begins.
4. **MainThread transcription** — any AVFoundation / Speech callback that touches SwiftUI state synchronously will freeze the popover. All transcription is `Task.detached` (TRAN-03); UI updates via `@MainActor` hops.
5. **Segment timestamp shape mismatch** — SpeechAnalyzer and whisper.cpp emit different segment structures. The Router MUST normalize both into `[(start: TimeInterval, end: TimeInterval, text: String)]` (Phase 2 N-03) before returning. Drift here breaks `NoteNormalizer` silently.
6. **SwiftWhisper version lag** — exPHAT's wrapper may lag behind upstream whisper.cpp. Pin the version explicitly (CONTEXT P-04); if critical upstream fix is needed, fork or switch to official SPM.

### Recommended Project Structure

```
Sources/
├── UnibrainCore/
│   └── Protocols/
│       └── AudioTranscriber.swift        # Phase 1 protocol (exists)
├── UnibrainProviders/                    # macOS/iOS-only — Phase 3 adds:
│   ├── Transcription/
│   │   ├── TranscriberRouter.swift       # Facade (CONTEXT P-05)
│   │   ├── SpeechAnalyzerTranscriber.swift
│   │   ├── WhisperCppTranscriber.swift
│   │   └── ModelDownload/
│   │       └── SmallEnDownloader.swift   # Background download + SHA256 (P-17/P-18)
│   └── Capture/                          # Phase 3 new
│       ├── AudioRecorder.swift           # AVAudioRecorder wrapper
│       └── RecordingSession.swift        # State machine: idle → recording → paused → transcribing
└── UnibrainApp/                          # Phase 3 wires the menu-bar popover
    ├── ContentView.swift                 # Main window (minimal)
    ├── MenuBarPopover.swift              # P-08..P-12 recording UI
    └── UnibrainApp.swift                 # App shell (exists from Phase 1)
```

---

## 4. Implementation Guidance

**Model Configuration:**
- SpeechAnalyzer: OS-default configuration. Apple Intelligence model auto-selected based on system language & hardware. No temperature / token-budget knobs exposed at the app level.
- whisper.cpp `small.en`: English-only, greedy decoding (temperature 0 — deterministic, best for study transcripts), no beam search (keeps latency predictable on A-series).

**Core Pattern:**
1. User taps Stop in menu-bar popover.
2. `RecordingSession` finalizes the `.m4a` (AAC, 16kHz mono per CLAUDE.md audio config).
3. `PipelineOrchestrator.run(inputs:)` called with `PipelineInputs(recordingURL:…, events: [])` (Phase 3 — no calendar events yet).
4. Orchestrator calls `transcriber.transcribe(inputs.recordingURL)` — `transcriber` is the `TranscriberRouter`.
5. Router tries `SpeechAnalyzerTranscriber`; on throw, retries via `WhisperCppTranscriber` (re-transcribes the WHOLE recording, CONTEXT P-06).
6. Router returns `[(start, end, text)]` to Orchestrator.
7. Orchestrator calls `NoteNormalizer.normalize(segments:)` (Phase 2) → `NoteWriter.write(note, to: path)` (Phase 2 `NSFileCoordinatorNoteWriter`).
8. UI: popover shows `Ready`; macOS notification fires.

**Tool Use:**
- `ModelLoadGate.shared` (Phase 1) — acquire/release `.asr` around whisper.cpp load.
- `SmallEnDownloader` — background URLSession to HuggingFace or GitHub releases (P-D6); SHA256 verification; retry-once on failure (P-18).
- `NSFileCoordinator` — Phase 2's `NSFileCoordinatorNoteWriter` ships in Phase 3 `UnibrainProviders`.

**State Management:**
- `RecordingSession` actor: `idle → recording → paused → transcribing → idle` state machine.
- `SmallEnDownloader` actor: `not-started → downloading(Double) → verified → failed` state machine.
- Both are `Sendable` (Swift 6 strict concurrency).

**Context Window Strategy:**
- N/A — ASR has no context window. whisper.cpp handles arbitrary-length audio internally via its own chunking. SpeechAnalyzer same. No app-level chunking needed for MVP.

---

## 4b. AI Systems Best Practices

> Adapted from cross-cutting patterns. Phase 3 is Swift/ASR, not Python/LLM, so several LLM-specific patterns are marked N/A.

### Structured Outputs (N/A for ASR)

ASR output is natively structured (`[(start, end, text)]`) — no Pydantic / structured-output prompt needed. The `TranscriberRouter` is responsible for normalizing both engine outputs into the shared segment shape before returning. Validation: the Orchestrator's `init` (Phase 2 O-01) asserts segment shape on first access.

### Async-First Design

Both engines are inherently async (`async throws`). The one common mistake: calling `transcribe` on `@MainActor` — it blocks the UI thread. Pattern:
```swift
await Task.detached(priority: .userInitiated) {
    let segments = try await transcriber.transcribe(url)
    await MainActor.run { /* update popover state */ }
}.value
```
No streaming for MVP (single-shot post-capture per TRAN-04). Streaming ASR is v2 (Phase 1 D-17).

### Prompt Engineering Discipline

N/A for ASR — no prompts. Engine selection + model choice (SpeechAnalyzer vs. whisper.cpp small.en) IS the equivalent of "prompt engineering" for ASR.

### Context Window Management

N/A — ASR processes the full audio file. No chunking / summarization / context compaction needed at the app level for MVP.

### Cost and Latency Budget

| Path | Expected latency on 60-min lecture | RAM peak | Cost |
|------|-----------------------------------|----------|------|
| SpeechAnalyzer (primary) | 1–3 min (Apple Intelligence realtime claim — unverified on A-series lecture content) | OS-managed (not app RAM) — likely < 500 MB | $0 (on-device) |
| whisper.cpp small.en (fallback) | ~20 min (~3× realtime on M1 Metal benchmark; A-series unverified) | ~852 MB | $0 (on-device) |
| Both paths fail | Error surfaced to user | — | User re-records or gives up |

No caching (each recording transcribed once). No sub-task model routing (single ASR task per recording).

---

## 5. Evaluation Strategy

### Dimensions

| Dimension | Rubric (Pass/Fail or 1-5) | Measurement Approach | Priority |
|-----------|--------------------------|---------------------|----------|
| Non-empty transcript | Pass = > 0 segments returned from a ≥ 30s fixture | Code (assertion in CI smoke test) | Critical |
| Segment shape | Pass = every segment has valid `start ≤ end`, `text.count > 0` | Code (contract assertion) | Critical |
| UI does not freeze during transcription | Pass = popover animates (timer ticks) while transcription runs | Human (device test — Angelica / Greg) | Critical |
| Model released after transcription (TRAN-06) | Pass = `ModelLoadGate.isAcquired(.asr) == false` after transcription completes or throws | Code (post-condition assertion in tests) | Critical |
| First-run not gated by model download (P-17) | Pass = user can record via SpeechAnalyzer immediately on first launch before `small.en` finishes downloading | Human (device test — fresh install) | High |
| SpeechAnalyzer → whisper.cpp auto-fallback fires on error | Pass = injecting a SpeechAnalyzer error produces a whisper.cpp transcript, no user-visible error | Code (mock SpeechAnalyzerTranscriber in `UnibrainProvidersTests`) | High |
| SHA256 verification rejects corrupted model (P-18) | Pass = deliberate hash mismatch triggers retry-once-then-warning | Code (fixture with wrong hash) | High |
| Transcript accuracy on clean lecture audio | 1–5 (Angelica rates "is this usable for study?" after first real lecture) | Human (UAT — first 2 weeks of classes) | Medium |
| Latency budget on real recording | Pass = transcript ready before Angelica next checks (≤ 30 min for 90-min lecture worst case) | Human (UAT) | Medium |

### Eval Tooling

**Primary Tool:** Swift Testing (`@Test`, `#expect`) — already established in Phase 1.

**Setup:** No additional eval framework. ASR accuracy evaluation is human UAT, not automated (Trust + Ship per CONTEXT P-03).

**CI/CD Integration:**
```bash
# On macos-15 / macos-26 runner (Phase 1 CI job extended):
swift test --filter UnibrainProvidersTests
# Includes:
#   - testTranscriberRouter_PrimaryPath (mock SpeechAnalyzer returns fixture segments)
#   - testTranscriberRouter_FallbackOnSpeechAnalyzerError (whisper.cpp path if model provisioned per P-D7)
#   - testWhisperCppTranscriber_ReleasesGateOnSuccess (TRAN-06)
#   - testWhisperCppTranscriber_ReleasesGateOnThrow (TRAN-06 error path)
#   - testSmallEnDownloader_RetriesOnceOnSHA256Mismatch (P-18)
#   - testSmallEnDownloader_DoesNotBlockFirstRun (P-17 contract)
```

SpeechAnalyzer runtime test on CI requires `macos-26` runner (or `depot-macos-26`) — planner verifies availability (P-D7).

### Reference Dataset

**Size:** 1 fixture for CI smoke test; 5–10 real recordings for UAT over Angelica's first 2 weeks.

**Composition:**
- CI fixture: 60–90s Creative-Commons lecture audio (single speaker, clean audio). Tests non-empty output + segment shape, NOT accuracy.
- UAT recordings: Angelica's actual lectures (discipline-specific jargon, varied room acoustics, accented English possible). NOT committed to the repo — privacy.

**Labeling:**
- CI fixture: expected transcript committed alongside fixture (hand-transcribed once).
- UAT recordings: Angelica self-rates "is this usable for study?" (binary). No formal WER calculation — Trust + Ship (P-03). Bad transcripts reported to Greg; trigger fallback tuning or engine swap in a later phase.

---

## 6. Guardrails

### Online (Real-Time)

| Guardrail | Implementation | Why |
|-----------|---------------|-----|
| ModelLoadGate denies concurrent ASR + LLM loads | Phase 1 `ModelLoadGate` actor — only one heavy model loaded at a time on 8GB | Prevent OOM |
| SpeechAnalyzer task cancellation before whisper.cpp load | `TranscriberRouter` cancels SpeechAnalyzer `Task` before calling `gate.acquire(.asr)` | Prevent dual-engine RAM contention |
| Transcription off MainThread | `Task.detached(priority: .userInitiated)` for all transcription calls (TRAN-03) | Prevent UI freeze |
| SHA256 verification on model download | `SmallEnDownloader` computes SHA256 of downloaded file; compares to `static let` hash embedded in binary | Detect corrupted / tampered model before loading |
| Download retry-once on failure | Auto-retry once; then non-blocking warning in popover (P-18); NEVER block recording | Tolerate flaky network without making model download a hard dependency |

### Offline (Batch)

- Phase 3 has no batch processing — every recording is transcribed once, on-device, immediately after Stop. No batch eval runs.
- Phase 6 may add a "Regenerate transcript" action that re-transcribes an existing recording through a different engine — that is a user-initiated one-shot, not batch.

### N/A for This System

- **Prompt injection** — no LLM in Phase 3 (LLM summarization is Phase 6, gated). No user-facing prompt surface in the transcription path.
- **PII redaction** — transcript is the output; there's nothing to redact (lecture content is the point). Audio stays on disk for Angelica's reference.
- **Toxicity / safety filtering** — N/A. Transcription is verbatim; lecture content is assumed non-abusive.

---

## 7. Production Monitoring

**Telemetry:** Zero per CLAUDE.md "Privacy: Local-only is the default mode (zero cloud, zero telemetry)." Phase 3 does NOT add any analytics, crash reporting, or usage tracking.

**Crash logs:** macOS built-in crash dialog handles crashes locally. Apple Developer Program membership (FOUND-06, Phase 1 blocker) unlocks TestFlight + crash log aggregation if Greg opts in later — out of Phase 3 scope.

**Manual feedback channel:** Angelica reports bad transcripts verbally / via text to Greg. Greg inspects the recording + transcript pair on-device. No in-app feedback UI for MVP.

**Health checks (local-only, in-app):**
- Popover status line (P-10) surfaces preconditions: `Ready to record • small.en model downloaded • Microphone available` — or warnings if any precondition fails.
- `SmallEnDownloader` state machine surface in popover: `Fallback model: downloading (40%)` / `verified` / `download failed — [Retry]` (P-17/P-18).

---

## Checklist

- [x] Framework selected with rationale (§2 — SpeechAnalyzer primary + whisper.cpp fallback, with TranscriberRouter facade)
- [x] Domain context + expert rubric ingredients (§1b — education / lecture capture, Angelica as domain expert)
- [x] Framework quick reference (§3 — installation, imports, entry point, abstractions, pitfalls)
- [x] Implementation guidance (§4 + §4b — Swift/ASR patterns adapted; LLM-specific patterns marked N/A)
- [x] Eval strategy grounded in domain context (§5 — CI smoke test for shape/contract; human UAT for accuracy)
- [x] Guardrails defined (§6 — ModelLoadGate, SHA256, MainThread, retry-once; LLM guardrails marked N/A)
- [x] Production monitoring (§7 — zero telemetry per privacy mandate; in-app status surface)
- [x] Trust + Ship / fix-forward posture documented (§1b + §5 — CONTEXT P-03 carried through)

---

*Phase: 3 — macOS Capture + Transcribe*
*AI-SPEC generated: 2026-07-14*
*Source: distilled from 03-CONTEXT.md (P-01..P-19) + CLAUDE.md (technology stack)*
