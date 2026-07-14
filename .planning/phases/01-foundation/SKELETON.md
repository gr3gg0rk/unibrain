# Walking Skeleton — unibrain Phase 1 Foundation

**Recorded:** 2026-07-14
**Phase:** 1 — Foundation
**Status:** Complete

## Capability Proven

Swift Package Manager package with **UnibrainCore** library builds and tests green on WSL2 Linux (Swift 6.0.3, strict concurrency mode). GitHub Actions CI runs the same build + test on macOS (macos-15, Xcode 16.4+) with SPM and DerivedData caching. The walking skeleton proves:

1. `swift build --target UnibrainCore` succeeds on Linux
2. `swift test --filter UnibrainCoreTests` passes 17 tests on Linux (ModelLoadGate deny-on-conflict, FrontmatterSchema Yams round-trip, provider protocol mock conformances)
3. `UnibrainApp/` source files exist for a future Xcode project to reference (NOT in Package.swift per D-09)
4. CI workflow at `.github/workflows/ci.yml` runs both Linux and macOS jobs on push

## Architectural Decisions

| Layer | Decision | Reference |
|-------|----------|-----------|
| **Framework** | SwiftUI native multiplatform (NOT Mac Catalyst, NOT cross-platform) | D-07, D-09 |
| **Build system** | Swift Package Manager (`swift-tools-version: 6.0`, `.swiftLanguageMode(.v6)` strict concurrency) | D-07 |
| **Data layer** | File system + YAML frontmatter via Yams 6.2.2. No Core Data, no Realm, no SQLite in MVP | D-10 |
| **Auth** | None — single-user (Angelica). No auth surface in v1 | PROJECT.md Constraints |
| **Deployment targets** | macOS 26 (Tahoe) / iOS 17 via Xcode multiplatform. Unlocks SpeechAnalyzer on macOS; keeps EventKit iOS 17+ API | D-05 |
| **Directory layout** | Feature-grouped under `Sources/UnibrainCore/` with `Protocols/`, `Errors/`, `ModelLoadGate/`, `Schemas/` subdirs. App shell in `UnibrainApp/` (separate from SPM) | D-07, D-09 |
| **Provider protocols** | Four standalone protocols in UnibrainCore (LLMSummarizer, AudioTranscriber, VisionDescriber, AudioSynthesizer) with `associatedtype Request/Response`. Single-shot `async throws`. No streaming in v1 | D-15, D-17 |
| **Shared error type** | `ProviderError` enum with 6 cases: networkFailure, modelError, rateLimited, invalidResponse, cancelled, underlying | D-16 |
| **RAM gating** | `ModelLoadGate` actor with acquire/release lease pattern. Deny-on-conflict (throws `.busy`). No internal timeout. Local heavy models only (cloud bypasses gate) | D-11..D-14 |
| **Test framework** | Swift Testing (`import Testing`, `@Test`, `@Suite`). Not XCTest | RESEARCH.md |
| **Apple Dev Program** | Deferred to Phase 3 — $99/yr paid membership recommended for TestFlight + crash logs. Not blocking Phase 1 SPM/CI work | D-01, FOUND-06 |
| **Repo visibility** | Public — unlimited free macOS CI minutes on GitHub Actions | D-02 |
| **Hardware target** | MacBook Neo (A-series chip, macOS 26 Tahoe, 8GB unified memory). Affects ASR strategy: CoreML/ANE may favor WhisperKit over Metal | D-03, D-06 |

## Stack Touched in Phase 1

| Slice | Status | Notes |
|-------|--------|-------|
| **Project scaffold** | Checked | Package.swift with 4 targets, Yams dep, Swift 6 mode |
| **Routing** | N/A | Phase 1 has no routes — no navigation, no URL handling |
| **Database** | N/A | File-based storage — no database in MVP |
| **UI** | Shell only | App shell exists (`UnibrainApp.swift`, `ContentView.swift`) but no user interaction. Phase 3 adds recording UI |
| **Deployment** | CI pipeline | GitHub Actions workflow with Linux + macOS matrix and caching. NOT app store deployment |

## Out of Scope (Deferred to Future Phases)

All Phase 2-6 functionality is explicitly out of scope for the walking skeleton:

- **Phase 2:** Transcription pipeline (pure logic), note normalization, course classification matching, embeddings/retrieval
- **Phase 3:** macOS record-transcribe-write slice, whisper.cpp/Metal integration, ASR engine decision (whisper.cpp vs SpeechAnalyzer vs WhisperKit)
- **Phase 4:** Calendar-based routing via EventKit, course schedule classification
- **Phase 5:** iOS capture, onboarding flow, device OS verification
- **Phase 6:** Gated summarization via Ollama, cloud provider integration (OpenAI, Anthropic, X/Grok, Z.ai)

## Subsequent Slice Plan

| Phase | Slice | Key Deliverable |
|-------|-------|-----------------|
| **Phase 2** | Pure pipeline logic on Linux | NoteNormalizer, CourseClassifier (pure matching), FrontmatterSchema encode/decode — all testable on WSL2 |
| **Phase 3** | macOS record-transcribe-write slice | AVFoundation recording, whisper.cpp transcription, Obsidian vault write-out — the MVP core loop |
| **Phase 4** | Calendar-based routing | EventKit integration, recording timestamp → course mapping, auto-populated frontmatter |
| **Phase 5** | iOS capture + onboarding | iPhone recording, first-run setup, iCloud Drive vault sync verification |
| **Phase 6** | Gated summary + cloud providers | Ollama summarization (opt-in), cloud provider layer (OpenAI/Anthropic/Grok/Z.ai), per-modality Settings UI |

## Conventions Established in Phase 1

1. **`.macOS(.v15)` in Package.swift** — Swift 6.0.3 toolchain lacks `.v26` enum value. CI runner with Xcode 16 can update later. Deployment target is a build setting, not runtime requirement.
2. **`#if canImport(FoundationNetworking)`** for URLRequest/URLError on Linux (not in Foundation on Linux Swift).
3. **`swift test --filter UnibrainCoreTests`** (NOT `--test-product` — unsupported in Swift 6.0.3 SPM).
4. **Commit format:** `<type>(phase-plan): description` (e.g., `feat(01-01): scaffold UnibrainCore`).
5. **Attribution disabled** — no Co-Authored-By trailers.
6. **UnibrainCore has zero Apple-framework imports** — enforced by Linux build success (DISC-02).

---

*This document locks the architectural decisions Phase 2-6 will build on. Do not re-litigate these without a documented superseding decision.*
