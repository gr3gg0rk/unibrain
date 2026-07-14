# Phase 1: Foundation - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

The architectural bedrock ships: SPM multiplatform project with three library/app targets, four provider protocols behind `#if canImport()` guards, GitHub Actions macOS CI with Linux + macOS matrix, the `ModelLoadGate` actor that enforces 8GB RAM discipline (one heavy local model at a time), Yams integrated for YAML, and the Apple Developer Program decision documented. Phase 1 produces a `swift build` + `swift test` that succeeds on WSL2 Linux for `UnibrainCore`, an empty SwiftUI app shell that launches on macOS, and a CI workflow that proves the pipeline green on the second run (caches hit). No feature code (capture, transcription, classification, write-out, summary) ships here.

</domain>

<decisions>
## Implementation Decisions

### Apple Dev + Repo

- **D-01:** Apple Developer Program membership decision is **deferred to Phase 3 dependency**. Document FOUND-06 in PROJECT.md Key Decisions as "pending user payment — needed for first device build in Phase 3, not blocking SPM/CI work in Phase 1." If the user pays earlier, the Phase 3 gate clears faster; Phase 1 work proceeds regardless.
- **D-02:** Repo is **public**. Unibrain is a hobby education tool with no proprietary logic, no secrets, single-user. Public repo unlocks unlimited free macOS CI minutes on GitHub Actions (no 10x private-repo multiplier). No downside identified.
- **D-03:** Angelica's MacBook Neo (released March 2026, $599) is confirmed **macOS 26 (Tahoe)** with an **A-series chip** and **8GB unified memory**. This is a significant update to PROJECT.md which assumed "Apple Silicon, 8GB" generically — the A-series vs M-series distinction affects Metal/CoreML performance expectations (whisper.cpp + Metal benchmark from research was M1-based; needs revalidation in Phase 3).
- **D-04:** iPhone and iPad Pro OS versions are **unknown** — document in PROJECT.md as "verify with Angelica before Phase 5 iOS capture work." iPad is view/sync surface only in MVP, so the unknown doesn't block Phase 1-4.
- **D-05:** Per-platform deployment targets: **macOS 26 (Tahoe) / iOS 17**. Uses Apple's standard multiplatform per-platform deployment target mechanism. Unlocks SpeechAnalyzer (WWDC 2025) on macOS via `if #available(macOS 26, *)` checks; iOS keeps `@Observable` macro and EventKit `requestFullAccessToEvents` iOS 17+ API. SAFEST given iPhone uncertainty. Phase 3 ASR strategy can pick SpeechAnalyzer primary with whisper.cpp fallback without dropping iOS 17 device support.
- **D-06:** MacBook Neo RAM is **confirmed 8GB**. The 8GB RAM discipline thesis (one heavy model at a time, ModelLoadGate, sequential ASR/LLM gating) stays load-bearing for the whole project.

### SPM Module Structure

- **D-07:** Three SPM targets:
  - **`UnibrainCore`** — Foundation-only library. Protocols, schemas, pure logic (NoteNormalizer, FrontmatterSchema, CourseClassifier pure matching, PipelineOrchestrator state machine). Builds and tests on WSL2 Linux Swift toolchain without Apple frameworks. Depends on `Yams` only.
  - **`UnibrainProviders`** — macOS/iOS-only library. Provider protocol conformances that wrap Apple frameworks (AVFoundation, EventKit, Speech, etc.) and the local backends (whisper.cpp, Ollama HTTP). Phase 1 ships ONLY protocol definitions and `#if canImport()` guards — no concrete backends yet. Depends on `UnibrainCore`.
  - **`UnibrainApp`** — Xcode-generated SwiftUI multiplatform app target (App protocol + scene + menu bar). Phase 1 ships an empty app shell that launches. Depends on `UnibrainCore` + `UnibrainProviders`.
- **D-08:** Test target split:
  - **`UnibrainCoreTests`** — Linux-runnable. XCTest or swift-testing framework. Tests pure logic (FrontmatterSchema encode/decode, Normalizer output matching, CourseClassifier matching, Orchestrator state transitions, ModelLoadGate conflict behavior).
  - **`UnibrainProvidersTests`** — macOS-only. Tests protocol conformances with mock Apple-framework stubs. Behind `#if canImport(...)` guards.
  - CI matrix: Linux job runs `UnibrainCoreTests` only; macOS job runs both.
- **D-09:** App entry point is **Xcode-generated SwiftUI app target + SPM deps** (NOT SPM executable target). Standard Apple multiplatform shape. Xcode manages Info.plist, entitlements, asset catalogs, code signing. Phase 1 ships an empty app shell that launches — proves the build pipeline end-to-end.
- **D-10:** Phase 1 dependencies in `Package.swift`: **Yams 6.2.2 in `UnibrainCore` only**. Concrete backends (whisper.cpp/SwiftWhisper, Ollama HTTP client, cloud provider clients) ship in Phase 3+ (whisper.cpp) and Phase 6 (cloud). HTTP client scaffolding and SwiftWhisper integration are explicitly Phase 1 anti-scope — early integration risks the green-build criterion.

### ModelLoadGate Conflict Policy

- **D-11:** Conflict policy is **deny-on-conflict (throw)**. When a heavy model is already loaded (e.g., ASR running) and another heavy request arrives (e.g., LLM summary), the gate throws `ModelLoadGateError.busy(currentModel: HeavyModelKind?)` immediately. Caller decides: retry, queue, or surface to user. Maps directly onto Phase 6 SUMM-07 ("LLM refuses to run while ASR is loaded"). Most predictable for the user; no implicit waiting; no surprise preemption.
- **D-12:** Gate scope is **local heavy models only**. `HeavyModelKind = .asr | .llm` (extendable to `.vision` if Phase 2 vision ingestion requires a heavy local model). Cloud providers (OpenAI, Anthropic, Grok, Z.ai) bypass the gate entirely — they don't count toward local RAM (matches DISC-01 verbatim). Cloud calls can fire concurrently with local ASR.
- **D-13:** API shape is **acquire/release + ModelLease**:
  ```swift
  actor ModelLoadGate {
      func acquire(_ kind: HeavyModelKind) async throws -> ModelLease
      // throws .busy(currentModel:) if a conflicting heavy model is held
  }
  struct ModelLease: Sendable {
      let kind: HeavyModelKind
      func release() async
  }
  ```
  Lease is `Sendable`. Caller scope owns the lease; defer-style release. Swift 6 data-race-safe.
- **D-14:** Lease lifecycle: **no internal timeout**. Caller owns the lease until explicit `release()`. If caller crashes mid-inference, app process restart reclaims RAM. Phase 6 SUMM-07 pattern: Ollama summarizer acquires, runs `keep_alive: 0` inference, releases explicitly in a `defer`. Simplest, most predictable.

### Provider Protocol Contract

- **D-15:** Four **standalone protocols** in `UnibrainCore`, no common ancestor:
  - `protocol LLMSummarizer { associatedtype Request; associatedtype Response; func summarize(_ request: Request) async throws -> Response }`
  - `protocol AudioTranscriber { associatedtype Request; associatedtype Response; func transcribe(_ request: Request) async throws -> Response }`
  - `protocol VisionDescriber { associatedtype Request; associatedtype Response; func describe(_ request: Request) async throws -> Response }`
  - `protocol AudioSynthesizer { associatedtype Request; associatedtype Response; func synthesize(_ request: Request) async throws -> Response }`
  Each provider type conforms to exactly one protocol. Cloud providers can conform to multiple protocols independently (e.g., a future `OpenAIProvider` can conform to both `LLMSummarizer` AND `VisionDescriber`).
- **D-16:** Single shared **`ProviderError` enum** in `UnibrainCore`:
  ```swift
  enum ProviderError: Error {
      case networkFailure(URLRequest, URLError)
      case modelError(String)
      case rateLimited(retryAfter: TimeInterval?)
      case invalidResponse(String)
      case cancelled
      case underlying(any Error)
  }
  ```
  Every provider throws `ProviderError`. Phase 6 cloud retry/fallback (CLOUD-10, CLOUD-11) handles a unified error shape. Settings UI can categorize cleanly.
- **D-17:** Protocols are **single-shot only in Phase 1**: `func run(_:) async throws -> Response`. No streaming. ASR returns full transcript once complete. LLM returns full summary once generated. Live transcript / token streaming is v2 (matches TRAN-04 "Transcription is post-capture only"). If Phase 6 wants streaming, add `func stream(_:) -> AsyncThrowingStream<Response, Error>` as an optional extension protocol then — not a breaking change.
- **D-18:** Phase 1 ships **protocols only, no concrete backends** (no cloud stubs, no single StubProvider). Mock conformances exist in `UnibrainProvidersTests` for macOS build verification. Phase 6 owns cloud scaffolds; Phase 3 owns whisper.cpp conformance. Cleanest Phase 1 surface; preserves the green-build criterion.

### Claude's Discretion

- Bundle identifier convention (suggest `com.griak.unibrain` or `app.unibrain` — pick one and document in PROJECT.md Key Decisions).
- Swift 6 language mode enforcement (`.enableExperimentalFeature("StrictConcurrency")` in Package.swift).
- Test framework choice (XCTest vs swift-testing) — recommend swift-testing for new code given Swift 6 alignment.
- CI cache strategy specifics (SPM cache via `actions/cache@v4` with `~/Library/Caches/org.swift.swiftpm` key; DerivedData via `actions/cache@v4` with `DerivedData` key).
- `ModelLoadGateError` additional variants beyond `.busy(currentModel:)` (e.g., `.invalidKind`, `.releaseMismatch`).
- Provider protocol default implementations (e.g., `extension AudioTranscriber where Request == AudioFileInput { func transcribe(at url: URL) async throws -> Transcript { ... } }`).
- Info.plist + entitlements baseline content for the empty app shell (sandboxing settings, microphone usage description placeholder for Phase 3).

### Folded Todos

None — no pending todos in the project state matched Phase 1 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Planning (in this repo)
- `.planning/PROJECT.md` — project definition, constraints, key decisions, assumptions. Update Key Decisions table with D-01, D-02, D-03 (MacBook Neo macOS 26 / A-series / 8GB), D-04, D-05, D-06 before Phase 1 planning.
- `.planning/REQUIREMENTS.md` — Phase 1 requirements: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, DISC-01, DISC-02, DISC-03.
- `.planning/ROADMAP.md` §"Phase 1: Foundation" — phase goal, mode (mvp), dependencies, requirements, success criteria.
- `.planning/STATE.md` §"Blockers/Concerns" — Apple Dev decision + public/private CI minutes (both resolved by this discussion: deferred to Phase 3, public repo).

### External Apple Documentation (read during planning as needed)
- [Configuring a multiplatform app (Apple Developer)](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target) — confirms per-platform deployment targets approach (D-05).
- [WWDC25: Bring advanced speech-to-text with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/) — Phase 3 ASR strategy; informs Phase 1 protocol shape (no breaking change to add SpeechAnalyzer conformance later).
- [EkEventStore requestFullAccessToEvents](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)) — Phase 4 EventKit API, confirms iOS 17+ deployment target floor (D-05).
- [Yams on Swift Package Index](https://swiftpackageindex.com/jpsim/Yams) — v6.2.2, SPM URL `https://github.com/jpsim/Yams.git` from `6.2.2` (D-10).

No external specs, ADRs, or feature docs exist in this repo yet — Phase 1 is greenfield.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

None — this is a greenfield project. Phase 1 CREATES the assets that downstream phases reuse:

- `UnibrainCore` library (created here) → reused by every subsequent phase
- Provider protocols (created here) → extended/conformed-to in Phases 3, 4, 6
- `ModelLoadGate` actor (created here) → leaned on by Phase 3 (TRAN-06 model release), Phase 6 (SUMM-07 LLM-vs-ASR enforcement)
- YAML frontmatter types (created here) → used by Phase 2 NoteNormalizer / FrontmatterSchema
- CI workflow (created here) → runs every phase's tests going forward

### Established Patterns

None yet. Phase 1 ESTABLISHES the patterns:

- Swift 6 strict concurrency (`actor`, `Sendable`, `async/await`)
- Protocol-abstraction layer over Apple frameworks (everything Apple-framework-specific lives behind a protocol in `UnibrainProviders`)
- Per-platform deployment targets with `#if os(macOS)` / `#if os(iOS)` / `if #available(...)` guards
- Single-shot async/throws API style for all inference protocols
- Acquire/release lease pattern for shared-resource gating (`ModelLoadGate`)

### Integration Points

- `UnibrainApp` is the only consumer-facing entry point. Phase 1 ships empty shell; Phase 3 adds the menu-bar record button; Phase 4 adds settings; Phase 5 adds onboarding; Phase 6 adds cloud settings.
- CI workflow at `.github/workflows/ci.yml` is the canonical build/test path — no Mac in dev loop means every push MUST pass CI to be considered shippable.
- `Package.swift` is the dependency root — adding any new library target requires updating it.

</code_context>

<specifics>
## Specific Ideas

- The MacBook Neo A-series chip detail is the most surprising finding from this discussion. The PROJECT.md assumed generic "Apple Silicon" — the reality is A-series (likely A18/A19 class, similar to iPhone). This means:
  - whisper.cpp + Metal 4.4x speedup figure from research was M1-based; A-series Neural Engine may favor CoreML encoder path (WhisperKit) over Metal.
  - The Phase 3 ASR strategy decision (whisper.cpp vs SpeechAnalyzer vs WhisperKit) is now more open than PROJECT.md suggested — SpeechAnalyzer on macOS 26 Tahoe is a viable PRIMARY path, not just fallback.
  - This doesn't change Phase 1 deliverables but changes the protocol shape thinking: protocols must be ASR-engine-agnostic so any of the three can slot in.
- "Local-first by default, cloud by choice" framing in PROJECT.md is well-served by the four-standalone-protocol decision (D-15). Cloud providers conform to the same protocol as local; Settings UI swaps conformances.
- "One heavy model at a time" is enforced structurally (D-11..D-14), not by convention. The lease pattern is borrowed from GPU resource management — fits well.
- SpeechAnalyzer availability on macOS 26 (Tahoe) means whisper.cpp's role might shrink to "fallback for accuracy-critical transcription" rather than "primary ASR." Phase 3 plan should evaluate both and pick based on accuracy benchmark on MacBook Neo specifically.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The following items were considered but explicitly belong in other phases:

- **SwiftWhisper vs whisper.cpp direct SPM vs WhisperKit integration decision** → Phase 3 (TRAN-01). Phase 1 ships no ASR backend.
- **SpeechAnalyzer vs whisper.cpp as primary ASR** → Phase 3 ASR strategy. Phase 1 just guarantees protocols are ASR-engine-agnostic.
- **Cloud provider concrete stubs (OpenAI, Anthropic, Grok, Z.ai)** → Phase 6 (CLOUD-03..06).
- **Streaming ASR / streaming LLM token output** → v2. Phase 1 protocols are single-shot (D-17).
- **Ollama HTTP client integration** → Phase 6 (SUMM-01). Phase 1 ships no LLM backend.
- **Bundle ID, code signing strategy, App Store Connect setup** → Phase 3 (when Apple Dev decision lands). Phase 1 uses placeholder bundle ID.
- **iPad-native capture** → Phase 5+ (per PROJECT.md Out of Scope for MVP).

### Reviewed Todos (not folded)

None — no todos existed in the project state.

</deferred>

---

*Phase: 1-Foundation*
*Context gathered: 2026-07-13*
