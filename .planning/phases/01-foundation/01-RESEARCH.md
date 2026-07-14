# Phase 1: Foundation - Research

**Researched:** 2026-07-13
**Domain:** Swift Package Manager multiplatform architecture, Swift 6 strict concurrency, GitHub Actions macOS CI, WSL2 Linux Swift development
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Apple Developer Program membership deferred to Phase 3 dependency. Document FOUND-06 as "pending user payment — needed for first device build in Phase 3, not blocking SPM/CI work in Phase 1."
- **D-02:** Repo is **public**. Unlimited free macOS CI minutes on GitHub Actions.
- **D-03:** Angelica's MacBook Neo is **macOS 26 (Tahoe)** with **A-series chip** and **8GB unified memory**.
- **D-04:** iPhone and iPad Pro OS versions unknown — document as "verify before Phase 5."
- **D-05:** Per-platform deployment targets: **macOS 26 (Tahoe) / iOS 17**.
- **D-06:** MacBook Neo RAM is **confirmed 8GB**. ModelLoadGate is load-bearing.
- **D-07:** Three SPM targets: `UnibrainCore` (Foundation-only, Linux-buildable), `UnibrainProviders` (Apple-only, protocols+guards), `UnibrainApp` (Xcode-generated SwiftUI).
- **D-08:** Test target split: `UnibrainCoreTests` (Linux-runnable), `UnibrainProvidersTests` (macOS-only). CI matrix: Linux runs CoreTests only; macOS runs both.
- **D-09:** App entry point is Xcode-generated SwiftUI app target + SPM deps (NOT SPM executable).
- **D-10:** Phase 1 deps: **Yams 6.2.2 in UnibrainCore only**. No concrete backends, no HTTP client, no SwiftWhisper.
- **D-11:** Conflict policy: **deny-on-conflict (throw)**. `ModelLoadGateError.busy(currentModel:)`.
- **D-12:** Gate scope: **local heavy models only**. `.asr | .llm` (extendable to `.vision`). Cloud bypasses gate.
- **D-13:** API shape: **acquire/release + ModelLease**. `actor ModelLoadGate`, `func acquire(_ kind:) async throws -> ModelLease`, `struct ModelLease: Sendable`.
- **D-14:** Lease lifecycle: **no internal timeout**. Explicit `release()`. Process restart reclaims RAM on crash.
- **D-15:** Four **standalone protocols** in `UnibrainCore`, no common ancestor. Each provider conforms to exactly one (cloud providers can conform to multiple independently).
- **D-16:** Single shared **`ProviderError` enum** in `UnibrainCore` with `.networkFailure`, `.modelError`, `.rateLimited`, `.invalidResponse`, `.cancelled`, `.underlying`.
- **D-17:** Protocols are **single-shot only in Phase 1**: `func run(_:) async throws -> Response`. No streaming.
- **D-18:** Phase 1 ships **protocols only, no concrete backends**. Mock conformances exist in `UnibrainProvidersTests`.

### Claude's Discretion

- Bundle identifier convention (suggest `com.griak.unibrain` or `app.unibrain` — pick one and document in PROJECT.md Key Decisions).
- Swift 6 language mode enforcement (`.enableExperimentalFeature("StrictConcurrency")` in Package.swift).
- Test framework choice (XCTest vs swift-testing) — recommend swift-testing for new code given Swift 6 alignment.
- CI cache strategy specifics (SPM cache via `actions/cache@v4` with `~/Library/Caches/org.swift.swiftpm` key; DerivedData via `actions/cache@v4` with `DerivedData` key).
- `ModelLoadGateError` additional variants beyond `.busy(currentModel:)`.
- Provider protocol default implementations.
- Info.plist + entitlements baseline content for the empty app shell.

### Deferred Ideas (OUT OF SCOPE)

- SwiftWhisper vs whisper.cpp direct SPM vs WhisperKit integration decision (Phase 3)
- SpeechAnalyzer vs whisper.cpp as primary ASR (Phase 3)
- Cloud provider concrete stubs (Phase 6)
- Streaming ASR / streaming LLM token output (v2)
- Ollama HTTP client integration (Phase 6)
- Bundle ID, code signing strategy, App Store Connect setup (Phase 3)
- iPad-native capture (Phase 5+)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | SPM multiplatform target (macOS + iOS) sharing non-UI logic | SPM Package.swift with multiplatform targets, per-platform deployment targets, Linux-buildable core target (see Standard Stack, Architecture Patterns) |
| FOUND-02 | Protocol-abstraction layer covering all inference modalities | Four standalone protocols with associatedtypes behind `#if canImport()` guards in UnibrainCore (see Architecture Patterns, Code Examples) |
| FOUND-03 | GitHub Actions macOS CI with SPM cache and DerivedData cache | macos-15 runner Xcode 16.4+, actions/cache@v4 for SPM + DerivedData paths, matrix with Linux job (see Code Examples, Environment Availability) |
| FOUND-04 | ModelLoadGate actor enforcing one-heavy-model-at-a-time | Swift 6 actor with acquire/release lease API, Sendable ModelLease, deny-on-conflict policy (see Architecture Patterns, Code Examples) |
| FOUND-05 | Yams YAML library integrated | Yams 6.2.2 SPM dependency in UnibrainCore, Codable via YamsEncoder (see Standard Stack, Code Examples) |
| FOUND-06 | Apple Developer Program membership decision documented | $99/yr paid vs free analysis (see Assumptions Log, Open Questions) |
| DISC-01 | One heavy local model at a time (cloud doesn't count) | ModelLoadGate scope is local heavy models only (D-12); cloud providers bypass gate entirely |
| DISC-02 | All Apple-framework deps behind protocols | Protocol-abstraction layer in UnibrainProviders; UnibrainCore has zero Apple-framework imports |
| DISC-03 | Pure-logic unit tests run on WSL2 Linux Swift toolchain | Swift Testing ships with Swift 6 toolchain on Linux; UnibrainCoreTests target has no Apple-framework dependencies |
</phase_requirements>

## Summary

Phase 1 is a greenfield foundation phase that creates the SPM layered architecture, four provider protocols, the `ModelLoadGate` actor, macOS CI pipeline, and Yams integration. The critical constraint is that `UnibrainCore` must build and test on WSL2 Linux using a Swift 6 toolchain, while `UnibrainProviders` and `UnibrainApp` are Apple-only targets gated behind `#if canImport()` and `#if os()` checks. No feature code ships here — only the architectural bedrock.

**Primary recommendation:** Install Swift 6.0.x toolchain on WSL2 as the first task. Use `swift-tools-version: 6.0` with `swiftLanguageMode(.v6)` for strict concurrency by default. Use Swift Testing (`import Testing`) over XCTest for new code. The `ModelLoadGate` actor pattern is straightforward Swift 6 concurrency — the actor serializes access, the `ModelLease` is a `Sendable` struct, and the deny-on-conflict policy maps to a throwing `acquire()` method. For CI, use a matrix strategy with `ubuntu-latest` (runs UnibrainCoreTests) and `macos-15` (runs both test targets), with `actions/cache@v4` for SPM and DerivedData.

**Critical gap:** Swift is NOT currently installed on this WSL2 system. Phase 1 success criteria #1 and #2 require `swift build` and `swift test` to succeed locally. The plan MUST include a Swift toolchain installation task as Wave 0.

## Project Constraints (from CLAUDE.md)

- **Apple-native mandate:** SwiftUI + native frameworks only. No Electron, no web wrapper, no cross-platform abstraction in v1.
- **Local-first by default, cloud by choice:** Local is never removed, only augmented. No cloud call without user configuration.
- **Hardware constraint:** 8GB unified memory — only one local heavy model loaded at a time.
- **Single-user:** No auth, no multi-tenant, no sharing surface.
- **Coding style:** Immutability (create new objects, never mutate), many small files (200-400 lines), comprehensive error handling, input validation at boundaries.
- **Testing:** 80%+ coverage, TDD mandatory (write tests first), unit + integration + E2E all required.
- **Security:** No hardcoded secrets, all user inputs validated, error messages must not leak sensitive data.
- **GSD enforcement:** Do not make direct repo edits outside a GSD workflow.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SPM Package.swift manifest | Build system | — | Single manifest declares all targets, deps, platform targets |
| Provider protocols (4x) | UnibrainCore (library) | — | Pure-Swift protocol definitions with associatedtypes; no Apple-framework imports; compile on Linux |
| ProviderError enum | UnibrainCore (library) | — | Shared error type; pure Swift; no platform deps |
| ModelLoadGate actor | UnibrainCore (library) | — | Pure Swift concurrency; no Apple-framework deps; testable on Linux |
| Yams YAML integration | UnibrainCore (library) | — | Foundation-only dependency; Codable encoding/decoding; Linux compatible |
| `#if canImport()` guards | UnibrainProviders (library) | — | Apple-framework imports live here; Linux skips this target entirely |
| Mock provider conformances | UnibrainProvidersTests | — | Test-only; macOS-only; verify protocol conformances compile |
| SwiftUI app shell | UnibrainApp (Xcode target) | — | `@main App` + `WindowGroup` + `MenuBarExtra`; macOS/iOS only |
| CI workflow | GitHub Actions | — | `.github/workflows/ci.yml`; matrix: ubuntu-latest + macos-15 |
| Apple Dev decision | PROJECT.md | — | Documentation only; no code dependency in Phase 1 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard | Confidence |
|---------|---------|---------|--------------|------------|
| **Swift** | 6.0.x | Primary language | Swift 6.0 brings data-race safety, structured concurrency, strict concurrency by default. `swift-tools-version: 6.0` enables `swiftLanguageMode(.v6)`. [CITED: swift.org/install/linux/ubuntu/24_04] | HIGH |
| **Swift Testing** | Built into Swift 6 toolchain | Test framework | Ships with Swift 6 toolchain and Xcode 16 — no SPM dependency needed. `import Testing`, `@Test`, `@Suite`. Runs in parallel by default. Works on Linux via `swift test`. [CITED: github.com/swiftlang/swift-testing] | HIGH |
| **Yams** | 6.2.2 | YAML frontmatter serialization | Mature Swift YAML library by JP Simard. Built on LibYAML (bundled C library). Supports Codable via `YamsEncoder`/`YamsDecoder`. No external SPM dependencies. Linux compatible. [CITED: github.com/jpsim/Yams] [CITED: swiftpackageindex.com/jpsim/Yams] | HIGH |
| **SwiftUI** | macOS 26 / iOS 17+ | UI framework | Apple's standard for new apps. `@main App`, `WindowGroup`, `MenuBarExtra`. `@Observable` macro requires iOS 17/macOS 14+. [CITED: developer.apple.com/documentation/swiftui/windowgroup] | HIGH |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **actions/cache@v4** | Latest | CI caching | SPM cache + DerivedData cache on GitHub Actions macos-15 runner |
| **maxim-lobanov/setup-xcode** | v1 | Xcode version selection | Optional: pin specific Xcode version on macos-15 runner |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Swift Testing | XCTest | XCTest is legacy. Swift Testing ships with Swift 6 toolchain, has better concurrency alignment, parallel by default, less boilerplate. Use XCTest only if targeting older toolchains. |
| Yams | Codable + manual YAML string | Manual YAML generation is error-prone (escaping, indentation). Yams is the standard. No real alternative for Swift YAML. |
| macos-15 runner | macos-26 (preview) | macos-26 is in public preview (as of Sept 2025). macos-15 is GA with Xcode 16.4+. Use macos-15 for stability in Phase 1; evaluate macos-26 in Phase 3 if macOS 26 Tahoe SDK is needed. [CITED: github.blog/changelog/2025-09-11-actions-macos-26-image-now-in-public-preview] |
| Official Swift tarball | Swiftly | Swiftly is a newer installer with version management. Official tarball from swift.org is more stable and well-documented for Ubuntu 24.04. Use tarball for Phase 1. |

**Installation:**

Phase 1 has exactly ONE external SPM dependency: Yams 6.2.2 in `UnibrainCore`.

```swift
// In Package.swift
.package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")
```

Swift Testing requires NO SPM dependency — it ships with the Swift 6 toolchain.

**Swift toolchain installation on WSL2 (Ubuntu 24.04):**
```bash
# Install dependencies
sudo apt-get install -y libcurl4 libpython3.10 libxml2 libsqlite3-0

# Download Swift 6.0.x for Ubuntu 24.04 from swift.org/install/linux/ubuntu/24_04/
# Extract and add to PATH
```

**Version verification:** [CITED: swift.org/install/linux/ubuntu/24_04/]
- Swift 6.0.3 is available for Ubuntu 24.04 Noble (x86_64) as of this research.
- Yams 6.2.2 verified on Swift Package Index — requires Swift 5.7+/Xcode 14+. [CITED: swiftpackageindex.com/jpsim/Yams]

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| Yams | Swift Package Index / GitHub | ~9 years (since 2017) | High (widely used Swift YAML lib) | github.com/jpsim/Yams | OK | Approved |
| Swift Testing | Built into Swift 6 toolchain | Since 2024 (WWDC24) | N/A (ships with toolchain) | github.com/swiftlang/swift-testing | OK | Approved |

**Packages removed due to SLOP verdict:** none

**Packages flagged as suspicious [SUS]:** none

*Note: Yams was checked via `gsd-tools query package-legitimacy check --ecosystem npm` which returned SLOP (does-not-exist on npm). This is a cross-ecosystem false negative — Yams is a Swift package, not an npm package. Verified via Swift Package Index (swiftpackageindex.com/jpsim/Yams) and GitHub (github.com/jpsim/Yams with 1k+ stars). [CITED: swiftpackageindex.com/jpsim/Yams]*

*Swift Testing is not an installable package — it ships with the Swift 6 toolchain and Xcode 16. No registry check applicable.*

## Architecture Patterns

### System Architecture Diagram

```
                         Package.swift (swift-tools-version: 6.0)
                                    |
                   +----------------+----------------+
                   |                |                |
              UnibrainCore    UnibrainProviders   UnibrainApp
              (library)        (library)         (Xcode app target)
                   |                |                |
         +---------+---------+     |           SwiftUI App shell
         |         |         |     |           (@main, WindowGroup,
    Protocols  ModelLoadGate Yams  |            MenuBarExtra)
    (4x)       actor         dep   |
         |                      +--+--+
         |                      |     |
         +----+----+----+      Apple  Mock
         |    |    |    |      frameworks conformances
        LLM  ASR  Vis  TTS    (AVFoundation,  (test-only)
             criber er  Syn   EventKit, etc.)
                           
    #if canImport() guards separate Apple from Linux
```

**Data flow for Phase 1 (no feature code, just compilation):**

```
swift build (Linux)     swift build (macOS)      xcodebuild (macOS)
       |                       |                        |
  UnibrainCore            UnibrainCore               UnibrainApp
  UnibrainCoreTests       UnibrainProviders          (links both libs)
                          UnibrainProvidersTests
```

### Recommended Project Structure

```
unibrain/
├── Package.swift                          # SPM manifest (swift-tools-version: 6.0)
├── Sources/
│   ├── UnibrainCore/                      # Foundation-only library (Linux-buildable)
│   │   ├── Protocols/
│   │   │   ├── LLMSummarizer.swift         # protocol with associatedtype Request/Response
│   │   │   ├── AudioTranscriber.swift
│   │   │   ├── VisionDescriber.swift
│   │   │   └── AudioSynthesizer.swift
│   │   ├── Errors/
│   │   │   └── ProviderError.swift         # shared error enum
│   │   ├── ModelLoadGate/
│   │   │   ├── ModelLoadGate.swift         # actor
│   │   │   ├── ModelLease.swift            # Sendable struct
│   │   │   ├── HeavyModelKind.swift        # enum: .asr, .llm, .vision
│   │   │   └── ModelLoadGateError.swift    # .busy(currentModel:)
│   │   └── Schemas/                        # placeholder for Phase 2
│   │       └── FrontmatterSchema.swift      # Codable struct for YAML frontmatter
│   └── UnibrainProviders/                 # Apple-only library (NOT Linux-buildable)
│       └── ProtocolDefaults/
│           └── (empty in Phase 1 — protocols only)
├── Tests/
│   ├── UnibrainCoreTests/                 # Linux-runnable tests
│   │   ├── ModelLoadGateTests.swift        # acquire/release/conflict tests
│   │   ├── ProtocolConformanceTests.swift  # mock conformances verify protocol shape
│   │   └── FrontmatterSchemaTests.swift    # Yams encode/decode tests
│   └── UnibrainProvidersTests/            # macOS-only tests
│       └── MockProviderTests.swift         # mock conformances behind #if canImport()
├── UnibrainApp/                           # Xcode-generated app target (NOT in Package.swift)
│   ├── UnibrainApp.swift                   # @main struct, App protocol, WindowGroup
│   ├── ContentView.swift                   # empty placeholder view
│   ├── Info.plist
│   ├── UnibrainApp.entitlements
│   └── Assets.xcassets/
└── .github/
    └── workflows/
        └── ci.yml                         # matrix: ubuntu-latest + macos-15
```

**Key structural decision:** `UnibrainApp/` is NOT inside the SPM package targets. It is an Xcode-generated app project that references the local SPM package as a dependency. Xcode manages Info.plist, entitlements, asset catalogs, and code signing. The SPM `Package.swift` declares only library targets (`UnibrainCore`, `UnibrainProviders`) and test targets.

### Pattern 1: Linux-Buildable Core with Apple-Only Providers

**What:** Split code into two library targets based on framework dependencies. `UnibrainCore` imports only `Foundation` (available on Linux). `UnibrainProviders` imports Apple frameworks (`AVFoundation`, `EventKit`, `Speech`, etc.) and is gated behind `#if canImport()` checks.

**When to use:** Any time you need pure-logic unit tests to run on Linux without Xcode.

**Example:**
```swift
// Sources/UnibrainCore/Protocols/AudioTranscriber.swift
// No Apple-framework imports — compiles on Linux
import Foundation

public protocol AudioTranscriber {
    associatedtype Request
    associatedtype Response
    func transcribe(_ request: Request) async throws -> Response
}

// Sources/UnibrainProviders/WhisperTranscriber.swift (Phase 3 — NOT Phase 1)
// Apple frameworks gated behind canImport
#if canImport(AVFoundation)
import AVFoundation
// concrete conformance to AudioTranscriber using whisper.cpp
#endif
```

### Pattern 2: ModelLoadGate Acquire/Release Lease

**What:** An actor that serializes access to heavy local models. Only one heavy model (`HeavyModelKind.asr` or `.llm`) can be loaded at a time. Callers acquire a lease before loading a model and release it when done.

**When to use:** Any phase that loads local ASR or LLM models (Phase 3 ASR, Phase 6 LLM summary).

**Example:**
```swift
// Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift
import Foundation

public actor ModelLoadGate {
    private var currentModel: HeavyModelKind? = nil

    public init() {}

    public func acquire(_ kind: HeavyModelKind) async throws -> ModelLease {
        if let current = currentModel, current != kind {
            throw ModelLoadGateError.busy(currentModel: current)
        }
        currentModel = kind
        return ModelLease(kind: kind, gate: self)
    }

    public func release(_ kind: HeavyModelKind) async {
        if currentModel == kind {
            currentModel = nil
        }
    }
}

// Sources/UnibrainCore/ModelLoadGate/ModelLease.swift
import Foundation

public struct ModelLease: Sendable {
    public let kind: HeavyModelKind
    private let gate: ModelLoadGate

    init(kind: HeavyModelKind, gate: ModelLoadGate) {
        self.kind = kind
        self.gate = gate
    }

    public func release() async {
        await gate.release(kind)
    }
}
```

**Data-race safety:** The actor serializes all access to `currentModel`. The `ModelLease` is `Sendable` (immutable `let kind` + `ModelLoadGate` is an actor which is inherently `Sendable`). The `release()` method is `async` because it crosses the actor boundary. This is provably data-race-safe under Swift 6 strict concurrency. [CITED: swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety]

**Wait — is `ModelLease` actually Sendable?** The `gate` property is a `ModelLoadGate` which is an `actor`. Actors are implicitly `Sendable` in Swift 6. The `kind` property is a `HeavyModelKind` enum (value type, Sendable by default). So `ModelLease: Sendable` is valid. However, storing an actor reference inside a struct means the struct is a "thin wrapper around an actor reference" — this is a known-safe pattern in Swift 6. [ASSUMED]

### Pattern 3: Four Standalone Provider Protocols

**What:** Four independent protocols with no common ancestor. Each defines `associatedtype Request; associatedtype Response` and a single-shot `async throws` method. Cloud providers can conform to multiple protocols independently.

**When to use:** Whenever a new inference modality is added (LLM, ASR, Vision, TTS).

**Example:**
```swift
// Sources/UnibrainCore/Protocols/LLMSummarizer.swift
import Foundation

public protocol LLMSummarizer {
    associatedtype Request
    associatedtype Response
    func summarize(_ request: Request) async throws -> Response
}

// Sources/UnibrainCore/Protocols/AudioTranscriber.swift
import Foundation

public protocol AudioTranscriber {
    associatedtype Request
    associatedtype Response
    func transcribe(_ request: Request) async throws -> Response
}

// Sources/UnibrainCore/Protocols/VisionDescriber.swift
import Foundation

public protocol VisionDescriber {
    associatedtype Request
    associatedtype Response
    func describe(_ request: Request) async throws -> Response
}

// Sources/UnibrainCore/Protocols/AudioSynthesizer.swift
import Foundation

public protocol AudioSynthesizer {
    associatedtype Request
    associatedtype Response
    func synthesize(_ request: Request) async throws -> Response
}
```

**Note on associatedtypes and `#if canImport()`:** The protocol definitions themselves have NO Apple-framework dependencies and live in `UnibrainCore` (Linux-buildable). Protocol *conformances* that use Apple frameworks live in `UnibrainProviders` behind `#if canImport()`. The protocols themselves need no guards. [CITED: stackoverflow.com/questions/61053928/swift-package-and-if-canimport-how-does-it-work]

### Anti-Patterns to Avoid

- **Do NOT put the app target in Package.swift.** The `UnibrainApp` Xcode target is managed by Xcode, not SPM. Mixing an `.executableTarget` in Package.swift with an Xcode app target creates build conflicts. The Xcode project references the SPM package as a local dependency.
- **Do NOT import Apple frameworks in UnibrainCore.** Any `import AVFoundation`, `import EventKit`, `import Speech` in UnibrainCore breaks the Linux build. All Apple imports go in `UnibrainProviders` behind `#if canImport()`.
- **Do NOT use XCTest for new Phase 1 code.** Swift Testing (`import Testing`) ships with Swift 6, is designed for concurrency, and requires less boilerplate. XCTest is legacy.
- **Do NOT add concrete backend dependencies in Phase 1.** No SwiftWhisper, no Ollama HTTP client, no cloud provider stubs. Phase 1 ships protocols and mock conformances only (D-10, D-18).
- **Do NOT use `swiftLanguageMode(.v5)` as a "migration step."** This is a greenfield project — start in Swift 6 mode from day one. Strict concurrency is free when there's no legacy code.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML serialization | Manual YAML string builder | Yams 6.2.2 | Edge cases: escaping, indentation, multi-line strings, Unicode. Yams handles all of these via LibYAML. |
| Test framework | Custom test runner | Swift Testing (built into Swift 6) | Parallel execution, `@Test`/`@Suite` macros, built-in assertions, Linux support. |
| RAM gating logic | Lock manager / semaphore wrapper | Swift `actor` (ModelLoadGate) | Actors serialize access by language guarantee. No manual locking needed. Data-race-safe by construction. |
| CI caching | Custom cache script | `actions/cache@v4` | Standard GitHub Action. Handles cache keys, hit/miss, restore. |
| Package manifest | Hand-written build script | SPM `Package.swift` | Apple's standard dependency manager. Handles cross-platform builds, dependency resolution, test target management. |

**Key insight:** Swift 6's actor model eliminates the entire class of manual concurrency bugs that a lock-based ModelLoadGate would introduce. The actor serializes access by language guarantee — no `DispatchQueue`, no `NSLock`, no `semaphore_wait`.

## Common Pitfalls

### Pitfall 1: Swift Not Installed on WSL2

**What goes wrong:** `swift build` and `swift test` fail with "command not found" on WSL2.
**Why it happens:** Swift is not pre-installed on Ubuntu 24.04. It must be downloaded from swift.org and added to PATH manually.
**How to avoid:** Install Swift 6.0.x toolchain from swift.org/install/linux/ubuntu/24_04/ as the FIRST task in the plan. Verify with `swift --version`.
**Warning signs:** `command -v swift` returns nothing. Any `swift` command fails.

### Pitfall 2: SwiftPM Hangs on Incremental Builds (Swift 6.2 on Ubuntu 24.04)

**What goes wrong:** `swift build` hangs indefinitely during "resolving package graph" or incremental compilation on Ubuntu 24.04 with Swift 6.2.
**Why it happens:** Known bug in Swift 6.2 SwiftPM on Ubuntu 24.04. [CITED: stackoverflow.com/questions/79837922]
**How to avoid:** Use Swift 6.0.x (not 6.2) on Ubuntu 24.04 for Phase 1. Verify the toolchain version after installation.
**Warning signs:** Build hangs for 5+ minutes during dependency resolution.

### Pitfall 3: Yams C Subdependency "Missing Required Module"

**What goes wrong:** `swift build` fails with "missing required module 'CYaml'" when building Yams.
**Why it happens:** Yams bundles a C library (CYaml/libYAML). Compiling via `swiftc` CLI (not Xcode) sometimes doesn't find the C module. [CITED: forums.swift.org/t/swiftpm-missing-required-module-when-compiling-with-a-library-dependency-and-a-c-subdependency-yams]
**How to avoid:** Ensure the SPM resolution step completes fully before building. Use `swift package resolve` explicitly before `swift build` if this occurs.
**Warning signs:** Build error mentioning "CYaml" or "missing required module".

### Pitfall 4: Xcode-Generated App Target Conflicts with SPM Package

**What goes wrong:** Adding an `.executableTarget` in Package.swift for the app creates conflicts with the Xcode-generated app target.
**Why it happens:** Xcode manages the app target (Info.plist, entitlements, code signing, asset catalogs). SPM manages library targets. Mixing them in Package.swift causes double-resolution.
**How to avoid:** Keep Package.swift to library + test targets ONLY. The Xcode project (`.xcodeproj`) references the local SPM package as a dependency via `File > Add Package Dependencies > Add Local`.
**Warning signs:** Build errors about duplicate symbols or conflicting module names.

### Pitfall 5: macOS Deployment Target Mismatch

**What goes wrong:** Code using `MenuBarExtra` (macOS 13+) fails to compile because the deployment target is set too low, or SpeechAnalyzer APIs (macOS 26+) aren't available.
**Why it happens:** The `platforms:` array in Package.swift sets deployment targets. If `.macOS(.v14)` is set but code uses macOS 26 APIs, compilation fails.
**How to avoid:** Set `.macOS(.v26)` in Package.swift platforms (per D-05). Use `if #available(macOS 26, *)` for APIs that require the latest OS. iOS stays at `.iOS(.v17)`.
**Warning signs:** "is only available in macOS 26.0 or newer" compiler errors.

### Pitfall 6: Swift Testing Not Discovered on Linux

**What goes wrong:** `swift test` on Linux runs 0 tests despite test files existing.
**Why it happens:** XCTest on Linux requires a manually maintained `LinuxMain.swift` or `tests: [.testTarget(...)]` entries. Swift Testing should auto-discover, but misconfigured test targets can fail.
**How to avoid:** Use Swift Testing (not XCTest) — it auto-discovers `@Test` functions without `LinuxMain.swift`. Ensure the test target is declared correctly in Package.swift with `.testTarget(name: "UnibrainCoreTests", dependencies: ["UnibrainCore"])`.
**Warning signs:** `swift test` output shows "Test Suite 'All tests' passed (0 tests)".

## Code Examples

### Package.swift (Phase 1 Foundation)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "unibrain",
    platforms: [
        .macOS(.v26),    // macOS 26 Tahoe (per D-05)
        .iOS(.v17),      // iOS 17 (per D-05)
    ],
    products: [
        .library(name: "UnibrainCore", targets: ["UnibrainCore"]),
        .library(name: "UnibrainProviders", targets: ["UnibrainProviders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
    ],
    targets: [
        .target(
            name: "UnibrainCore",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "UnibrainProviders",
            dependencies: ["UnibrainCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "UnibrainCoreTests",
            dependencies: ["UnibrainCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "UnibrainProvidersTests",
            dependencies: ["UnibrainCore", "UnibrainProviders"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
```

**Source:** Synthesized from [CITED: useyourloaf.com/blog/strict-concurrency-checking-in-swift-packages], [CITED: donnywals.com/setting-the-swift-language-mode-for-an-spm-package], [CITED: swiftpackageindex.com/jpsim/Yams]

### ModelLoadGate Test (Swift Testing)

```swift
// Tests/UnibrainCoreTests/ModelLoadGateTests.swift
import Testing
@testable import UnibrainCore

@Suite("ModelLoadGate")
struct ModelLoadGateTests {

    @Test("Acquire ASR lease succeeds when gate is free")
    func acquireASRSucceeds() async throws {
        let gate = ModelLoadGate()
        let lease = try await gate.acquire(.asr)
        #expect(lease.kind == .asr)
        await lease.release()
    }

    @Test("Acquiring LLM while ASR is held throws .busy")
    func denyOnConflict() async throws {
        let gate = ModelLoadGate()
        let asrLease = try await gate.acquire(.asr)

        await #expect(throws: ModelLoadGateError.self) {
            _ = try await gate.acquire(.llm)
        }

        await asrLease.release()
    }

    @Test("Acquiring same model kind twice succeeds (reentrant)")
    func reentrantSameKind() async throws {
        let gate = ModelLoadGate()
        let lease1 = try await gate.acquire(.asr)
        let lease2 = try await gate.acquire(.asr) // same kind, no conflict
        #expect(lease1.kind == .asr)
        #expect(lease2.kind == .asr)
        await lease1.release()
        await lease2.release()
    }

    @Test("After release, gate accepts different model")
    func releaseAllowsNewModel() async throws {
        let gate = ModelLoadGate()
        let asrLease = try await gate.acquire(.asr)
        await asrLease.release()
        let llmLease = try await gate.acquire(.llm) // should succeed now
        #expect(llmLease.kind == .llm)
        await llmLease.release()
    }
}
```

**Source:** Swift Testing syntax from [CITED: github.com/swiftlang/swift-testing], [CITED: developer.apple.com/documentation/testing]

### Yams Frontmatter Codable

```swift
// Sources/UnibrainCore/Schemas/FrontmatterSchema.swift
import Foundation
import Yams

public struct FrontmatterSchema: Codable, Sendable {
    public var schemaVersion: Int
    public var course: String
    public var courseName: String
    public var term: String
    public var datetime: Date
    public var durationSeconds: Int
    public var source: String
    public var audioFile: String
    public var tags: [String]
    public var syllabusLink: String?
    public var vectorId: String?
    public var summaryModel: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case course
        case courseName = "course_name"
        case term
        case datetime
        case durationSeconds = "duration_seconds"
        case source
        case audioFile = "audio_file"
        case tags
        case syllabusLink = "syllabus_link"
        case vectorId = "vector_id"
        case summaryModel = "summary_model"
    }
}

// Encoding example
public func encodeFrontmatter(_ schema: FrontmatterSchema) throws -> String {
    let encoder = YAMLEncoder()
    encoder.keyEncodingStrategy = .useDefaultKeys  // CodingKeys handle snake_case
    let yaml = try encoder.encode(schema)
    return "---\n\(yaml)---\n"
}
```

**Source:** Yams API from [CITED: github.com/jpsim/Yams]

### CI Workflow (.github/workflows/ci.yml)

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  linux-tests:
    name: Linux (UnibrainCore only)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.0.3"
      - name: Swift version
        run: swift --version
      - name: Resolve dependencies
        run: swift package resolve
      - name: Build UnibrainCore
        run: swift build --target UnibrainCore
      - name: Test UnibrainCore
        run: swift test --test-product UnibrainCoreTests

  macos-tests:
    name: macOS (all targets)
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.4.app
      - name: SPM cache
        uses: actions/cache@v4
        with:
          path: |
            ~/Library/Caches/org.swift.swiftpm
            ~/Library/org.swift.swiftpm
          key: ${{ runner.os }}-spm-${{ hashFiles('Package.resolved') }}
          restore-keys: |
            ${{ runner.os }}-spm-
      - name: DerivedData cache
        uses: actions/cache@v4
        with:
          path: ~/Library/Developer/Xcode/DerivedData
          key: ${{ runner.os }}-dd-${{ hashFiles('Package.resolved', 'Package.swift') }}
          restore-keys: |
            ${{ runner.os }}-dd-
      - name: Build
        run: swift build
      - name: Test
        run: swift test
```

**Source:** CI caching patterns from [CITED: nowham.dev/posts/github-actions-ios-caching], SPM cache paths from [CITED: stackoverflow.com/questions/68081067]

### SwiftUI App Shell (UnibrainApp/UnibrainApp.swift)

```swift
import SwiftUI

@main
struct UnibrainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        MenuBarExtra("Unibrain", systemImage: "brain") {
            Text("Unibrain — Phase 1 Shell")
        }
        #endif
    }
}
```

**Source:** Multiplatform app pattern from [CITED: developer.apple.com/documentation/swiftui/windowgroup], [CITED: fatbobman.com/en/posts/building-multiple-platforms-swiftui-app], MenuBarExtra from [CITED: nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| XCTest | Swift Testing | WWDC24 / Swift 6 (2024) | New code should use `import Testing`, `@Test`, `@Suite`. Parallel by default. No `LinuxMain.swift`. |
| `swift-tools-version: 5.9` | `swift-tools-version: 6.0` | Swift 6.0 release (2024) | Enables `swiftLanguageMode(.v6)`, per-target language mode, strict concurrency by default. |
| `@ObservedObject` / `@StateObject` | `@Observable` macro | iOS 17 / macOS 14 (2023) | Phase 1 targets iOS 17+, so `@Observable` is available. (App shell doesn't use it yet, but future phases will.) |
| macos-14 runner | macos-15 runner | Aug 2025 | `macos-latest` migrated to macos-15. macos-14 deprecated Nov 2025. Xcode 16.4+ pre-installed. |
| Manual Swift install scripts | `swift-actions/setup-swift@v2` | 2024+ | GitHub Action that installs Swift toolchain on Linux runners. Simplifies CI Swift setup. |
| Lock-based concurrency | Actor isolation | Swift 5.5+ (2021), enforced in Swift 6 | Actors serialize access by language guarantee. No manual locking. ModelLoadGate uses this. |

**Deprecated/outdated:**
- **CocoaPods:** Deprecated dependency manager. SPM is Apple's standard. Do not use.
- **XCTest on Linux with LinuxMain.swift:** Legacy. Swift Testing auto-discovers without LinuxMain.
- **macos-14 runners:** Deprecated Nov 2025. Use macos-15.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ModelLease` storing an actor reference (`ModelLoadGate`) inside a `Sendable` struct is a known-safe pattern in Swift 6. | Architecture Patterns / Pattern 2 | If this triggers a Sendable warning, the planner needs to refactor `ModelLease` to store a token/handle instead of a direct actor reference. Low risk — actors are Sendable by definition. |
| A2 | `swift-actions/setup-swift@v2` is the correct GitHub Action for installing Swift on Linux runners. | Code Examples / CI Workflow | If the action is deprecated or broken, the planner should fall back to manual tarball installation in the CI step. |
| A3 | `swift build --target UnibrainCore` correctly builds only the core target and skips Apple-only targets on Linux. | Code Examples / CI Workflow | SPM might try to resolve all targets including Apple-only ones on Linux. If it fails, the plan needs conditional target exclusion or a separate Package.swift for Linux. Low risk — `#if canImport()` in source should prevent compilation issues. |
| A4 | Yams 6.2.2 builds cleanly on Ubuntu 24.04 with Swift 6.0.x without additional system dependencies beyond libcurl4/libpython3.10. | Standard Stack / Installation | Yams bundles LibYAML (C library). If the bundled C library fails to compile on Ubuntu 24.04, a system-level libyaml-dev package may be needed. |
| A5 | `swift test --test-product UnibrainCoreTests` correctly filters to only the core test target on Linux. | Code Examples / CI Workflow | The exact flag syntax may differ. Alternative: `swift test --filter UnibrainCoreTests`. Planner should verify. |
| A6 | Apple Developer Program free account is sufficient for Phase 1 SPM/CI work. No paid membership needed until device builds. | Phase Requirements / FOUND-06 | If SPM builds or CI require signing even for library targets, this would be a Phase 1 blocker. Very unlikely — SPM library builds never require code signing. |

## Open Questions

1. **macOS 26 deployment target in Package.swift**
   - What we know: macOS 26 (Tahoe) is the target per D-05. Swift Package Manager uses semantic versioning for platforms (`.macOS(.v14)`, `.macOS(.v15)`).
   - What's unclear: What is the exact SPM platform enum for macOS 26? Is it `.macOS(.v26)` or does SPM use a different naming convention for new OS versions?
   - Recommendation: The planner should verify `.macOS(.v26)` compiles with the installed Swift 6.0.x toolchain. If not, use the numeric equivalent or the `.macoS("26.0")` string form. [ASSUMED: `.macOS(.v26)` is correct based on Apple's versioning pattern]

2. **Xcode app target + local SPM package integration**
   - What we know: The Xcode project references the local SPM package. The app links against `UnibrainCore` and `UnibrainProviders`.
   - What's unclear: Since there's no Mac in the dev loop, how is the Xcode project (`.xcodeproj`) created and maintained? Can it be created from WSL2 Linux, or must the first `xcodebuild` invocation on CI create it?
   - Recommendation: The plan should include creating a minimal `.xcodeproj` via `xcodebuild` or a project generation tool on the macOS CI runner. Alternatively, use `xcodegen` (a YAML-driven Xcode project generator) to maintain the project file from WSL2. [ASSUMED: a minimal .xcodeproj can be checked into git and built on CI]

3. **Swift Testing `@Test` on Linux — exact discovery mechanism**
   - What we know: Swift Testing auto-discovers `@Test` functions without `LinuxMain.swift`. It ships with the Swift 6 toolchain.
   - What's unclear: Does the Swift 6.0.x toolchain on Ubuntu 24.04 include Swift Testing out of the box, or does it need a separate install step?
   - Recommendation: Verify with `swift test` after installing the toolchain. If `import Testing` fails, the toolchain may need the `swift-testing` package added explicitly. [ASSUMED: bundled in Swift 6 toolchain]

4. **macos-15 runner exact Xcode version**
   - What we know: macos-15 has Xcode 16.4+ as default, with Xcode 26 RC being added.
   - What's unclear: Which exact Xcode version is the default as of today? Does the CI need `sudo xcode-select -s` to pin a specific version?
   - Recommendation: Use `xcodebuild -version` in the CI to log the version. Pin with `maxim-lobanov/setup-xcode` action if reproducibility is critical. [ASSUMED: Xcode 16.4 is default and sufficient]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| **Swift 6.0.x toolchain** | UnibrainCore build + test on WSL2 | NO | — | Install from swift.org (Wave 0 task) |
| **Ubuntu 24.04** | Linux CI + local dev | YES | 24.04.3 LTS | — |
| **WSL2 kernel** | Local dev environment | YES | 6.6.87.2 | — |
| **GitHub Actions macos-15** | macOS CI | YES (GitHub-hosted) | Xcode 16.4+ | — |
| **GitHub Actions ubuntu-latest** | Linux CI | YES (GitHub-hosted) | Latest Ubuntu | — |
| **Git** | Version control | Verify | — | — |
| **Yams (via SPM)** | FrontmatterSchema | Auto-resolved by SPM | 6.2.2 | No fallback needed |
| **Xcode (local)** | App target development | NO (no Mac in dev loop) | — | CI macos-15 runner is the build path |

**Missing dependencies with no fallback:**
- **Swift 6.0.x toolchain on WSL2** — BLOCKING. Must be installed before any `swift build` / `swift test` can run locally. This is a Wave 0 task.

**Missing dependencies with fallback:**
- **Xcode (local)** — Not available on WSL2. Fallback: GitHub Actions macos-15 runner is the macOS build path. App shell changes are verified via CI only, not locally.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (built into Swift 6 toolchain) |
| Config file | Package.swift (test targets declared in manifest) |
| Quick run command | `swift test --test-product UnibrainCoreTests` |
| Full suite command | `swift test` (runs all test targets) |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | SPM multiplatform Package.swift builds | smoke | `swift build --target UnibrainCore` (Linux) | Wave 0 |
| FOUND-02 | Four provider protocols compile | unit | `swift build --target UnibrainCore` | Wave 0 |
| FOUND-03 | CI workflow runs on push with cache hits | smoke | GitHub Actions (automatic on push) | Wave 0 |
| FOUND-04 | ModelLoadGate enforces one-heavy-model-at-a-time | unit | `swift test --filter ModelLoadGateTests` | Wave 0 |
| FOUND-05 | Yams integrates and encodes/decodes frontmatter | unit | `swift test --filter FrontmatterSchemaTests` | Wave 0 |
| FOUND-06 | Apple Dev decision documented | manual | Verify PROJECT.md has the decision | N/A |
| DISC-01 | ModelLoadGate denies conflicting model load | unit | `swift test --filter ModelLoadGateTests.denyOnConflict` | Wave 0 |
| DISC-02 | UnibrainCore has zero Apple-framework imports | smoke | `swift build` on Linux succeeds | Wave 0 |
| DISC-03 | Pure-logic tests run on WSL2 Linux | smoke | `swift test --test-product UnibrainCoreTests` on Linux | Wave 0 |

### Sampling Rate

- **Per task commit:** `swift test --test-product UnibrainCoreTests` (fast — core tests only, ~5 seconds)
- **Per wave merge:** `swift test` (full suite — runs on macOS CI, ~30 seconds)
- **Phase gate:** Full suite green on both Linux and macOS CI before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] Swift 6.0.x toolchain NOT installed on WSL2 — must install before any build/test
- [ ] `Package.swift` — must be created (greenfield)
- [ ] `Tests/UnibrainCoreTests/ModelLoadGateTests.swift` — must be created
- [ ] `Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift` — must be created
- [ ] `.github/workflows/ci.yml` — must be created
- [ ] Git repository not yet initialized (`Is directory a git repo: No` from environment)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Single-user app, no auth in v1 |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | Single-user, local-first |
| V5 Input Validation | yes | Swift type system + Codable validation at boundaries (future phases validate transcript/course input) |
| V6 Cryptography | no | No crypto in Phase 1 (API keys in Keychain is Phase 6) |
| V7 Error Handling | yes | `ProviderError` enum with structured error types; no sensitive data leakage in error messages |
| V8 Data Protection | yes | Local-first storage; no cloud data in Phase 1; vault stays on device |

### Known Threat Patterns for Swift/SPM Foundation

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Supply chain (malicious SPM dependency) | Tampering | Pin Yams to exact version `from: "6.2.2"`; verify Package.resolved checksum |
| Data race in ModelLoadGate | Tampering | Swift 6 actor isolation (language-enforced serialization) |
| ProviderError leaking internal state | Information Disclosure | Error messages use structured enum cases, not raw strings from backends |

## Sources

### Primary (HIGH confidence)

- [Apple Developer: Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app) — multiplatform target approach
- [Apple Developer: WindowGroup](https://developer.apple.com/documentation/swiftui/windowgroup) — SwiftUI scene API
- [Apple Developer: Swift Testing](https://developer.apple.com/documentation/testing) — `import Testing`, `@Test`, `@Suite`
- [swiftlang/swift-testing (GitHub)](https://github.com/swiftlang/swift-testing) — ships with Swift 6 toolchain, Linux support
- [Swift.org: Data Race Safety](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/) — actor isolation, Sendable
- [Swift.org: Install on Ubuntu 24.04](https://swift.org/install/linux/ubuntu/24_04/) — official Swift 6.0.x tarball
- [GitHub Blog: macos-latest migration](https://github.blog/changelog/2025-07-11-upcoming-changes-to-macos-hosted-runners-macos-latest-migration-and-xcode-support-policy-updates/) — macos-15 is GA, Xcode support policy
- [macos-15 Runner Readme](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) — pre-installed Xcode versions
- [jpsim/Yams (GitHub)](https://github.com/jpsim/Yams) — SPM URL, Codable support, LibYAML bundling
- [Yams on Swift Package Index](https://swiftpackageindex.com/jpsim/Yams) — version 6.2.2, compatibility
- [Apple Developer: Compare Memberships](https://developer.apple.com/support/compare-memberships/) — Free vs $99/yr differences
- [Apple Developer: TestFlight](https://developer.apple.com/testflight/) — requires paid membership

### Secondary (MEDIUM confidence)

- [Use Your Loaf: Strict Concurrency in Swift Packages](https://useyourloaf.com/blog/strict-concurrency-checking-in-swift-packages/) — `.swiftLanguageMode(.v6)` in Package.swift
- [Donny Wals: Setting Swift Language Mode](https://www.donnywals.com/setting-the-swift-language-mode-for-an-spm-package/) — per-target language mode
- [Pol Piella: Enable Upcoming Swift Features](https://www.polpiella.dev/enable-upcoming-swift-features-in-spm/) — `.enableUpcomingFeature()` syntax
- [nowham.dev: GitHub Actions iOS Caching](https://nowham.dev/posts/github-actions-ios-caching/) — SPM cache + DerivedData cache strategies
- [Stack Overflow: SPM cache on GitHub Actions](https://stackoverflow.com/questions/68081067/spm-cache-not-working-on-github-actions-any-ideas) — cache paths
- [Stack Overflow: #if canImport in SPM](https://stackoverflow.com/questions/61053928/swift-package-and-if-canimport-how-does-it-work) — canImport mechanics
- [Fatbobman: Building Cross-Platform SwiftUI Apps](https://fatbobman.com/en/posts/building-multiple-platforms-swiftui-app/) — multiplatform patterns
- [Nil Coalescing: macOS Menu Bar Utility](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI) — MenuBarExtra pattern
- [Swift Forums: Concurrency Settings for New Project](https://forums.swift.org/t/what-should-the-concurrency-settings-be-for-a-brand-new-project/83109) — Swift 6 mode defaults
- [Stack Overflow: SwiftPM hangs on 6.2/Ubuntu 24.04](https://stackoverflow.com/questions/79837922/swift-package-manager-hangs-on-incremental-builds-swift-6-2-linux-ubuntu-24-04) — known Swift 6.2 bug

### Tertiary (LOW confidence)

- [linuxcapable.com: Install Swift on Ubuntu](https://linuxcapable.com/how-to-install-swift-on-ubuntu-linux/) — community install guide
- [Medium: Understanding SwiftUI App Template](https://medium.com/@nsuneelkumar98/understanding-the-swiftui-app-template-main-windowgroup-and-more-7e76bae7b8f2) — app template breakdown

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Swift 6, Swift Testing, Yams, SwiftUI are all well-documented Apple/official technologies with current information.
- Architecture: MEDIUM — The three-target SPM split and Linux-buildable core pattern is sound but has not been verified by building on this WSL2 system (Swift not yet installed).
- Pitfalls: HIGH — Swift installation gap is a confirmed finding; SwiftPM 6.2 hang is a known reported issue; Yams C subdependency is a documented forum issue.
- CI: MEDIUM — macos-15 runner and Xcode 16.4+ are confirmed, but exact Xcode version selection and cache hit verification need CI runtime validation.

**Research date:** 2026-07-13
**Valid until:** 2026-08-13 (30 days — stable Apple/SPM ecosystem, but macOS runner images update frequently)
