---
phase: "01"
plan: "01"
subsystem: foundation
tags: [spm, swift6, protocols, model-load-gate, yams, ci-foundation]
requires:
  - "None — this is the Wave 0 foundation plan"
provides:
  - "SPM Package.swift with 4 targets (UnibrainCore, UnibrainProviders, UnibrainCoreTests, UnibrainProvidersTests)"
  - "Four provider protocols (LLMSummarizer, AudioTranscriber, VisionDescriber, AudioSynthesizer)"
  - "ProviderError enum with 6 cases (D-16)"
  - "ModelLoadGate actor system (gate, lease, kind enum, error enum)"
  - "FrontmatterSchema Codable Sendable struct with Yams"
  - "ProviderDefaults.swift with #if canImport() guards (FOUND-02)"
  - "Swift 6.0.3 toolchain installed and verified on WSL2"
affects:
  - "All Phase 1 plans (01-02, 01-03, 01-04) depend on this build succeeding"
  - "All subsequent phases depend on UnibrainCore protocols and ModelLoadGate"
tech-stack:
  added:
    - "Swift 6.0.3 toolchain on Ubuntu 24.04 x86_64"
    - "Yams 6.2.2 (SPM dependency)"
    - "Swift Testing (built into toolchain)"
  patterns:
    - "Protocol-abstraction layer: 4 standalone protocols in UnibrainCore, conformances in UnibrainProviders behind #if canImport()"
    - "Actor-based resource gating: ModelLoadGate with acquire/release lease pattern"
    - "Linux-buildable core: UnibrainCore has zero Apple-framework imports"
    - "Swift 6 strict concurrency (.swiftLanguageMode(.v6) on all targets)"
key-files:
  created:
    - Package.swift
    - .gitignore
    - Sources/UnibrainCore/Protocols/LLMSummarizer.swift
    - Sources/UnibrainCore/Protocols/AudioTranscriber.swift
    - Sources/UnibrainCore/Protocols/VisionDescriber.swift
    - Sources/UnibrainCore/Protocols/AudioSynthesizer.swift
    - Sources/UnibrainCore/Errors/ProviderError.swift
    - Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift
    - Sources/UnibrainCore/ModelLoadGate/ModelLease.swift
    - Sources/UnibrainCore/ModelLoadGate/HeavyModelKind.swift
    - Sources/UnibrainCore/ModelLoadGate/ModelLoadGateError.swift
    - Sources/UnibrainCore/Schemas/FrontmatterSchema.swift
    - Sources/UnibrainProviders/ProtocolDefaults/ProviderDefaults.swift
    - Tests/UnibrainCoreTests/ModelLoadGateTests.swift
    - Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift
    - Tests/UnibrainCoreTests/ProviderProtocolTests.swift
    - Tests/UnibrainProvidersTests/.gitkeep
  modified: []
decisions:
  - "Used .macOS(.v15) instead of .macOS(.v26) because Swift 6.0.3 toolchain does not have .v26 enum value; deployment target is a build setting not runtime requirement"
  - "Added #if canImport(FoundationNetworking) to ProviderError.swift and ProviderProtocolTests.swift for URLRequest/URLError availability on Linux"
  - "Used swift test --filter UnibrainCoreTests instead of --test-product UnibrainCoreTests (latter not supported in Swift 6.0 SPM)"
  - "Installed Swift 6.0.3 to ~/swift-toolchain (user-space, no sudo) with libncurses symlink fix in ~/lib-fix"
metrics:
  duration: "16m"
  tasks: 2
  files-created: 17
  files-modified: 0
  tests-passing: 8
status: complete
---

# Phase 01 Plan 01: SPM Foundation Summary

Swift 6.0.3 toolchain installed on WSL2, SPM package with 4 targets builds green, 8 tests across 3 suites pass on Linux — the architectural bedrock for all subsequent phases.

## What Was Built

### Swift Toolchain
- Swift 6.0.3 (swift-6.0.3-RELEASE) installed at `~/swift-toolchain` from swift.org
- Dependencies: libcurl4, libxml2, libsqlite3-0 (pre-installed on Ubuntu 24.04)
- Fix applied: `~/lib-fix/libncurses.so.6` symlink to `libncursesw.so.6` (Ubuntu 24.04 ships wide variant only)
- PATH and LD_LIBRARY_PATH added to `~/.bashrc` for persistence

### SPM Package Structure (Package.swift)
- **swift-tools-version: 6.0** with `.swiftLanguageMode(.v6)` on all targets
- 4 targets: UnibrainCore (library), UnibrainProviders (library), UnibrainCoreTests, UnibrainProvidersTests
- Single dependency: Yams 6.2.2 (pinned in UnibrainCore only, per D-10)
- Platforms: `.macOS(.v15)` (highest available in Swift 6.0.x; `.v26` not in this toolchain) and `.iOS(.v17)`
- Package.resolved committed for reproducible builds

### Provider Protocols (UnibrainCore)
Four standalone protocols with `associatedtype Request/Response` and single-shot `async throws` methods:
- **LLMSummarizer** — `func summarize(_ request: Request) async throws -> Response`
- **AudioTranscriber** — `func transcribe(_ request: Request) async throws -> Response`
- **VisionDescriber** — `func describe(_ request: Request) async throws -> Response`
- **AudioSynthesizer** — `func synthesize(_ request: Request) async throws -> Response`

### Shared Error Type (UnibrainCore)
**ProviderError** enum with exactly 6 cases per D-16:
- `.networkFailure(URLRequest, URLError)` — network-level failures
- `.modelError(String)` — model produced error or invalid output
- `.rateLimited(retryAfter: TimeInterval?)` — provider throttled
- `.invalidResponse(String)` — unparseable response
- `.cancelled` — user-initiated cancellation
- `.underlying(any Error)` — backend-specific errors

Intentionally NOT Sendable (D-16 specifies `: Error` only; `underlying(any Error)` is non-Sendable).

### ModelLoadGate System (UnibrainCore)
- **ModelLoadGate** — `actor` with deny-on-conflict `acquire(kind:) async throws -> ModelLease` and `release(kind:) async`
- **ModelLease** — `struct: Sendable` storing `kind: HeavyModelKind` and gate reference; `release() async`
- **HeavyModelKind** — `enum: String, Sendable` with `.asr` and `.llm` cases
- **ModelLoadGateError** — `enum: Error, Sendable` with `.busy(currentModel: HeavyModelKind?)`

### FrontmatterSchema (UnibrainCore)
Codable Sendable struct with 13 fields per WRITE-02:
`schemaVersion`, `course`, `courseName`, `term`, `datetime`, `durationSeconds`, `source`, `audioFile`, `tags`, `syllabusLink?`, `vectorId?`, `summaryModel?`
CodingKeys map camelCase to snake_case YAML keys.

### Provider Guard Scaffolding (UnibrainProviders)
ProviderDefaults.swift with 4 `#if canImport()` guard blocks: AVFoundation, Speech, Vision, AVFAudio. Each contains a placeholder comment for Phase 2/3 conformances.

### Test Suite (8 tests, 3 suites, all pass on Linux)
- **ModelLoadGateTests** (4): acquire success, deny-on-conflict, reentrant same kind, release allows new model
- **FrontmatterSchemaTests** (1): struct creation with sample values
- **ProviderProtocolTests** (3): ProviderError.cancelled, networkFailure, rateLimited construction

## Verification Results

- `swift --version` reports `Swift version 6.0.3` (PASS)
- `swift build --target UnibrainCore` exits 0 (PASS)
- `swift test --filter UnibrainCoreTests` exits 0 with 8 tests passing (PASS)
- Zero Apple-framework imports in Sources/UnibrainCore/ (PASS — DISC-02)
- #if canImport() guards present in ProviderDefaults.swift (PASS — FOUND-02)
- Git branch is `main` (PASS)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] FoundationNetworking import required on Linux**
- **Found during:** Task 2
- **Issue:** `URLRequest` and `URLError` are in `FoundationNetworking`, not `Foundation`, on Linux Swift. Build failed with "cannot find type 'URLRequest' in scope".
- **Fix:** Added `#if canImport(FoundationNetworking) import FoundationNetworking #endif` to ProviderError.swift and ProviderProtocolTests.swift.
- **Files modified:** Sources/UnibrainCore/Errors/ProviderError.swift, Tests/UnibrainCoreTests/ProviderProtocolTests.swift
- **Commit:** 42d0e55

**2. [Rule 3 - Blocking] macOS deployment target fallback to .v15**
- **Found during:** Task 1
- **Issue:** Plan specified `.macOS(.v26)` per D-05. Swift 6.0.3 toolchain (released before macOS 26) does not have `.v26` in the SupportedPlatform enum.
- **Fix:** Used `.macOS(.v15)` (highest available in Swift 6.0.x toolchain). The plan anticipated this: "fall back to .macOS(.v15) to get the build working." Deployment target is a build setting, not a runtime requirement — the Xcode 16 CI runner in Plan 01-03 can update this to `.v26`.
- **Files modified:** Package.swift
- **Commit:** c1ae867

**3. [Rule 3 - Blocking] Swift test product flag incompatibility**
- **Found during:** Task 2
- **Issue:** `swift test --test-product UnibrainCoreTests` fails with "no product named 'UnibrainCoreTests'" on Swift 6.0.3 SPM. The `--test-product` flag works differently than the plan expected.
- **Fix:** Used `swift test --filter UnibrainCoreTests` instead, which correctly builds and runs only the UnibrainCoreTests target. All 8 tests pass.
- **Verification:** No file changes needed — command syntax adjustment only.

**4. [Rule 3 - Blocking] libncurses symlink for Swift toolchain**
- **Found during:** Task 1
- **Issue:** Swift 6.0.3 binary expects `libncurses.so.6` (non-wide variant). Ubuntu 24.04 only ships `libncursesw.so.6` (wide variant). Swift failed to start with "cannot open shared object file".
- **Fix:** Created `~/lib-fix/libncurses.so.6 -> /usr/lib/x86_64-linux-gnu/libncursesw.so.6` symlink and added `LD_LIBRARY_PATH=~/lib-fix` to `~/.bashrc`.
- **Commit:** N/A (environment setup, not committed)

**5. [Rule 3 - Blocking] No sudo access for apt dependency install**
- **Found during:** Task 1
- **Issue:** Plan called for `sudo apt-get install libcurl4 libpython3.10 libxml2 libsqlite3-0`. No sudo access in this environment.
- **Fix:** Verified all required libraries were already pre-installed on the system except libpython3.10 (Python 3.12 is installed instead, which Swift 6.0.3 links against successfully). No action needed.

## Known Stubs

No stubs. All protocols have concrete signatures; all tests exercise real behavior (ModelLoadGate acquire/release/conflict, FrontmatterSchema construction, ProviderError case construction). No placeholder data flows to any rendering surface.

## Threat Flags

No new security-relevant surface introduced beyond what the plan's threat model covers. T-01-01 through T-01-SC mitigations are in place: Swift toolchain from swift.org, Yams pinned to exact version, Package.resolved committed, ModelLoadGate uses Swift 6 actor isolation, ProviderError uses structured enum cases.

## Self-Check: PASSED

All files verified present on disk. All commit hashes verified in git log.
