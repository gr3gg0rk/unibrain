# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 1-Foundation
**Areas discussed:** Apple Dev + Repo, SPM module structure, ModelLoadGate conflict policy, Provider protocol contract

---

## Apple Dev + Repo

### Q1: Apple Developer Program — $99/yr paid or free account?

| Option | Description | Selected |
|--------|-------------|----------|
| Paid $99/yr (Recommended) | TestFlight, push, crash logs, real-device install beyond 7-day builds. Research recommended. | |
| Free account | 7-day signed builds, no TestFlight, no crash logs. Weekly reinstall friction. | |
| Defer decision | Pay $99/yr but make the call a Phase 3 dependency — don't block Phase 1 SPM/CI work. | ✓ |

**User's choice:** Defer decision
**Notes:** Phase 1 work (SPM, protocols, CI) doesn't need a paid Apple Dev account. Document FOUND-06 as "pending user payment — needed for first device build in Phase 3, not blocking Phase 1." If user pays earlier, Phase 3 gate clears faster.

### Q2: Repo visibility — public or private?

| Option | Description | Selected |
|--------|-------------|----------|
| Public (Recommended) | Unlimited free macOS CI minutes. Unibrain is hobby education, no proprietary logic, no secrets. | ✓ |
| Private | ~300 effective minutes/month on free tier (10x multiplier). Sufficient for MVP but easy to exhaust. | |
| Start public, reassess | Flip to private post-ship. Public history stays public — scrubbing is painful. | |

**User's choice:** Public
**Notes:** Unibrain is single-user, hobby education tool. No monetization, no proprietary algorithm. Public is the obvious call.

### Q3: Angelica's iPhone and iPad Pro OS versions?

| Option | Description | Selected |
|--------|-------------|----------|
| Both iOS 26+ (Recommended) | Symmetric SpeechAnalyzer availability. | |
| Mixed (iPhone 26, iPad <26) | iPad is sync/view surface only — less critical. | |
| Unknown — defer | Document "verify with Angelica" in PROJECT.md. | ✓ |

**User's choice:** Unknown — defer
**Notes:** User has not yet verified the iPhone/iPad OS versions. iPad is sync/view only in MVP so this doesn't block Phase 1-4.

### Q4: Deployment target — given MacBook Neo = macOS 26 confirmed, iPhone/iPad unknown?

| Option | Description | Selected |
|--------|-------------|----------|
| macOS 26 / iOS 17 split (Recommended) | Per-platform deployment targets. Unlocks SpeechAnalyzer on macOS; iOS keeps @Observable + EventKit iOS 17+ API. SAFEST given iPhone uncertainty. | ✓ |
| macOS 26 / iOS 26 unified | Symmetric SpeechAnalyzer but locks out iPhone <26. | |
| macOS 15 / iOS 18 conservative | No SpeechAnalyzer. Wastes MacBook Neo's macOS 26 advantage. | |

**User's choice:** macOS 26 / iOS 17 split
**Notes:** Per-platform deployment targets is the standard Apple multiplatform pattern. iOS 17 baseline works regardless of which iPhone Angelica has.

**Clarifying exchange:** User clarified that Angelica's MacBook is the new MacBook Neo (released March 2026, $599, A-series chip) running macOS 26 Tahoe. Web search confirmed the MacBook Neo announcement and macOS 26 default. This updated PROJECT.md's assumption (was "Apple Silicon" generically) and unlocked SpeechAnalyzer as a viable Phase 3 ASR strategy.

### Q5: MacBook Neo RAM config — confirm 8GB?

| Option | Description | Selected |
|--------|-------------|----------|
| Confirmed 8GB | RAM discipline thesis stays load-bearing. ModelLoadGate ships strict. | ✓ |
| 16GB or higher | Relaxes RAM discipline somewhat; gate can be a safety primitive. | |
| Unknown — assume 8GB | Verify later; gate ships strict regardless. | |

**User's choice:** Confirmed 8GB
**Notes:** MacBook Neo base config confirmed as 8GB. The whole project's "8GB RAM discipline" framing in PROJECT.md remains load-bearing.

---

## SPM Module Structure

### Q1: SPM module layout — how many library targets and what boundaries?

| Option | Description | Selected |
|--------|-------------|----------|
| Three targets: Core/Providers/App (Recommended) | UnibrainCore (Foundation, Linux-buildable), UnibrainProviders (Apple-framework + cloud scaffolds), UnibrainApp (SwiftUI). | ✓ |
| Two targets: Core + App | Single Core with canImport guards. Simpler Package.swift but mixed concerns. | |
| Five targets: full split | Core/Providers/Platform-macOS/Platform-iOS/App. Overkill for MVP. | |

**User's choice:** Three targets: Core/Providers/App
**Notes:** Clean DAG. Anything testable on Linux lives in Core. Researchers + planners can target Phase 2 work into Core precisely.

### Q2: Test target structure — how organized?

| Option | Description | Selected |
|--------|-------------|----------|
| Split: CoreTests + ProvidersTests (Recommended) | Linux-runnable + macOS-only. CI matrix runs CoreTests on Linux, both on macOS. | ✓ |
| Single Tests target | `#if os(macOS)` guards inside tests. Harder to reason about. | |
| Split + shared TestSupport lib | Cleaner reuse but more files upfront. | |

**User's choice:** Split: CoreTests + ProvidersTests
**Notes:** Matches DISC-03 cleanly (pure-logic tests on WSL2 Linux Swift toolchain).

### Q3: App entry point — Phase 1 ships an empty app shell or defers it?

| Option | Description | Selected |
|--------|-------------|----------|
| Xcode app target + SPM deps (Recommended) | Standard SwiftUI multiplatform. Empty shell launches, proves build pipeline. | ✓ |
| SPM executable target only | Loses Asset Catalog, entitlements editor, signing UI. Not recommended for SwiftUI. | |
| Defer app target to Phase 3 | Saves Phase 1 work but pushes "first launchable build" risk into Phase 3. | |

**User's choice:** Xcode app target + SPM deps
**Notes:** Phase 1 ships an empty SwiftUI app shell that just launches — proves the SPM→App build pipeline end-to-end.

### Q4: Phase 1 dependencies — what ships in Package.swift?

| Option | Description | Selected |
|--------|-------------|----------|
| Yams in Core only, rest later (Recommended) | Clean DAG. Backends ship in Phase 3+ / Phase 6. | ✓ |
| Include SwiftWhisper early | Adds C++ dependency that doesn't build on Linux. Risk to green-build criterion. | |
| Include HTTP client scaffolding | Premature — Phase 6 can pick the client then. | |

**User's choice:** Yams in Core only
**Notes:** Phase 1 ships Yams 6.2.2 in UnibrainCore only. whisper.cpp, Ollama HTTP client, cloud provider clients are explicitly anti-scoped.

---

## ModelLoadGate Conflict Policy

### Q1: Conflict policy — when two heavy models collide?

| Option | Description | Selected |
|--------|-------------|----------|
| Deny-on-conflict (throw) (Recommended) | Throws `.busy(currentModel:)`. Caller decides retry/queue/surface. Maps to Phase 6 SUMM-07. | ✓ |
| Async FIFO queue (await) | Caller awaits; second request blocks. Hides latency from UI. | |
| Priority preemption | Higher-priority cancels active model. Complex; mid-transcription cancellation wastes work. | |

**User's choice:** Deny-on-conflict (throw)
**Notes:** Most predictable for the user. No implicit waiting. SUMM-07 ("LLM refuses while ASR loaded") maps directly onto this.

### Q2: Gate scope — what counts as a "heavy model"?

| Option | Description | Selected |
|--------|-------------|----------|
| Local heavy models only (Recommended) | Matches DISC-01. Cloud bypasses the gate. | ✓ |
| All models (local + cloud) | Stricter but over-restricts — cloud doesn't compete for local RAM. | |
| Local + cloud rate-limit tracking | Conflates two concerns. Premature. | |

**User's choice:** Local heavy models only
**Notes:** DISC-01 verbatim: "Cloud providers don't count toward local RAM budget." `HeavyModelKind = .asr | .llm`.

### Q3: API shape — acquire/release lease vs closure scope?

| Option | Description | Selected |
|--------|-------------|----------|
| acquire/release + ModelLease (Recommended) | `acquire(_ kind:) async throws -> ModelLease`, `lease.release() async`. Sendable. Swift 6 data-race-safe. | ✓ |
| withModel<T> closure scope | RAII scoped. Harder to inspect state; doesn't model pre-acquire warmup. | |
| register/unregister manual | Most flexible but easiest to leak on error paths. | |

**User's choice:** acquire/release + ModelLease
**Notes:** Standard lease pattern. Caller scope owns the lease; defer-style release.

### Q4: Lease lifecycle — what if caller holds too long?

| Option | Description | Selected |
|--------|-------------|----------|
| No timeout — caller owns lease (Recommended) | Process restart reclaims RAM on crash. Simplest, most predictable. | ✓ |
| Auto-expire lease after timeout | Yanks lease mid-transcription on long lectures. Destructive. | |
| Watchdog warn-only (no auto-release) | Observability-only. Adds logging surface in Phase 1. | |

**User's choice:** No timeout — caller owns lease
**Notes:** Phase 6 SUMM-07 pattern: Ollama summarizer acquires, runs `keep_alive: 0`, releases in a defer. No internal timeout.

---

## Provider Protocol Contract

### Q1: Protocol topology — four specialized protocols or common ancestor?

| Option | Description | Selected |
|--------|-------------|----------|
| 4 standalone protocols, no ancestor (Recommended) | Each provider conforms to exactly one protocol. Cloud providers can conform to multiple independently. | ✓ |
| Common InferenceProvider ancestor | `any InferenceProvider` polymorphism in Settings UI. Adds abstraction that may not pay off in MVP. | |
| Single generic Provider protocol | `func inference(_ input: Any) async throws -> Any`. Loses type safety. Anti-pattern. | |

**User's choice:** 4 standalone protocols, no ancestor
**Notes:** Clean modality separation. OpenAI conforming to both LLMSummarizer AND VisionDescriber is natural.

### Q2: Error model — single shared ProviderError or per-protocol errors?

| Option | Description | Selected |
|--------|-------------|----------|
| Single ProviderError enum (Recommended) | Unified shape. Phase 6 retry/fallback handles one enum. | ✓ |
| Per-protocol error enums | More specific per modality but fragments handling. | |
| Result<> instead of throws | Explicit handling but loses `try await` ergonomics. | |

**User's choice:** Single ProviderError enum
**Notes:** Cases: `.networkFailure`, `.modelError`, `.rateLimited(retryAfter:)`, `.invalidResponse`, `.cancelled`, `.underlying(any Error)`. Every provider throws this.

### Q3: Streaming vs single-shot — what does the Phase 1 contract require?

| Option | Description | Selected |
|--------|-------------|----------|
| Single-shot only in Phase 1 (Recommended) | No streaming. ASR returns full transcript; LLM returns full summary. Matches TRAN-04. | ✓ |
| Optional streaming via AsyncThrowingStream | Default impl returns single-shot; future opt-in. Slightly more complex upfront. | |
| Streaming-first everywhere | Forces every caller to consume a stream. Overkill. | |

**User's choice:** Single-shot only in Phase 1
**Notes:** v2 can add streaming via an extension protocol — not a breaking change.

### Q4: Concrete backends in Phase 1 — protocols only, or include stubs?

| Option | Description | Selected |
|--------|-------------|----------|
| Protocols only, no cloud stubs (Recommended) | Cleanest Phase 1 surface. Phase 6 owns cloud; Phase 3 owns whisper.cpp. | ✓ |
| Protocols + stub cloud providers | Throws `.notImplemented`. Proves conformance early but adds four stub files. | |
| Protocols + single StubProvider | Conforms to all four; returns canned data. One extra type. | |

**User's choice:** Protocols only, no cloud stubs
**Notes:** Mock conformances live in UnibrainProvidersTests for macOS build verification only.

---

## Claude's Discretion

- Bundle identifier convention (`com.griak.unibrain` vs `app.unibrain`) — pick one and document in PROJECT.md Key Decisions.
- Swift 6 language mode enforcement (StrictConcurrency feature flag in Package.swift).
- Test framework (XCTest vs swift-testing) — recommend swift-testing for new Swift 6 code.
- CI cache strategy specifics (SPM cache + DerivedData cache paths and keys).
- `ModelLoadGateError` additional variants beyond `.busy(currentModel:)`.
- Provider protocol default implementations and convenience extensions.
- Info.plist + entitlements baseline content for the empty app shell.

## Deferred Ideas

- SwiftWhisper vs whisper.cpp direct SPM vs WhisperKit integration → Phase 3 (TRAN-01).
- SpeechAnalyzer vs whisper.cpp as primary ASR → Phase 3 ASR strategy.
- Cloud provider concrete stubs → Phase 6 (CLOUD-03..06).
- Streaming ASR / LLM token output → v2.
- Ollama HTTP client integration → Phase 6 (SUMM-01).
- Bundle ID, code signing, App Store Connect setup → Phase 3 (when Apple Dev decision lands).
- iPad-native capture → Phase 5+.
