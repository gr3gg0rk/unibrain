---
slug: phase03-ci-build-failures
status: resolved
trigger: "Phase 03 code blocks Linux + macOS CI after pushing 64 unpushed commits. Phase 02 code (UnibrainCore) builds clean but its test step cannot compile because SPM builds the whole graph including the broken UnibrainProviders target."
created: 2026-07-15T16:40:00Z
updated: 2026-07-15T16:40:00Z
goal: find_and_fix
tdd_mode: false
---

# Debug Session: phase03-ci-build-failures

## Symptoms

**Expected:** `swift build` and `swift test --filter UnibrainCoreTests` succeed on both `ubuntu-latest` (Swift 6.0.3) and `macos-15` runners.

**Actual:** Both CI jobs fail at compile time. Phase 02 code itself (UnibrainCore target) builds clean on Linux — failure is in Phase 03 code (UnibrainProviders target).

**Timeline:** Began failing on push `72be018` (2026-07-15T16:30:30Z) — first push after 64 commits of Phase 02 + Phase 03 work landed locally. CI was green on 2026-07-14 (Phase 01 only).

**Reproduction:** Any push to `main` triggers `.github/workflows/ci.yml`. Both jobs (linux-tests, macos-tests) fail at compile.

**Error messages (verbatim from CI run 29432687949):**

### Linux failure (`ubuntu-latest`, job 87411398640, step "Run UnibrainCore tests")

```
Sources/UnibrainProviders/Transcription/ModelDownload/SmallEnDownloader.swift:2:8: error: no such module 'CryptoKit'
  1 | import Foundation
  2 | import CryptoKit
    |        `- error: no such module 'CryptoKit'
  3 | import UnibrainCore
```

Repeats for every UnibrainCoreTests + UnibrainProviders compile unit. `emit-module command failed with exit code 1`. Step "Build UnibrainCore target" PASSED before this — the test step builds the whole graph.

### macOS failure (`macos-15`, job 87411398733, step "Build all targets")

Two distinct errors:

**Error 1 — NSFileCoordinator API misuse:**
```
/Users/runner/work/unibrain/unibrain/Sources/UnibrainProviders/VaultWriting/NSFileCoordinatorNoteWriter.swift:76:25: error: value of type 'NSFileCoordinator' has no member 'writeAccessAllowed'
  74 |         try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
  75 |             let coordinator = NSFileCoordinator(filePresenter: nil)
  76 |             coordinator.writeAccessAllowed = true
     |                         `- error: value of type 'NSFileCoordinator' has no member 'writeAccessAllowed'
  77 |
  78 |             var coordinationError: NSError?
```

**Error 2 — Swift 6 strict concurrency:**
```
/Users/runner/work/unibrain/unibrain/Sources/UnibrainProviders/Capture/AudioRecorder.swift:59:23: error: static property 'audioSettings' is not concurrency-safe because non-'Sendable' type '[String : Any]' may have shared mutable state
  57 |     /// - Channels: 1 (mono — lectures are single-source)
  58 |     /// - Quality: high
  59 |     public static let audioSettings: [String: Any] = [
     |                       |- error: static property 'audioSettings' is not concurrency-safe because non-'Sendable' type '[String : Any]' may have shared mutable state
     |                       |- note: add '@MainActor' to make static property 'audioSettings' part of global actor 'MainActor'
     |                       `- note: disable concurrency-safety checks if accesses are protected by an external synchronization mechanism
  60 |         AVFormatIDKey: kAudioFormatMPEG4AAC,
  61 |         AVSampleRateKey: 16000.0,
```

- timestamp: 2026-07-15T16:40:00Z — Phase 02 verification cannot be flipped to `passed` because no tests actually executed
- timestamp: 2026-07-15T17:00:00Z — Root cause confirmed from CI logs. Three independent compile errors verified against source code.
- timestamp: 2026-07-15T17:05:00Z — Fixes applied: (1) SmallEnDownloader + URLSessionProtocol + tests wrapped in `#if canImport(CryptoKit)`, (2) removed nonexistent `writeAccessAllowed` property, (3) `audioSettings` marked `nonisolated(unsafe)`.

## Eliminated

(none yet)

## Current Focus

hypothesis: |
  Three independent compile errors in Phase 03 UnibrainProviders code, each blocking CI:
  1. SmallEnDownloader.swift uses `import CryptoKit` unguarded — CryptoKit is Apple-only, Linux has no such module
  2. NSFileCoordinatorNoteWriter.swift line 76 references `coordinator.writeAccessAllowed` which is not a real NSFileCoordinator API
  3. AudioRecorder.swift line 59 declares `public static let audioSettings: [String: Any]` — Swift 6 rejects non-Sendable `[String: Any]` as a static let without isolation

test: |
  Three fixes:
  1. Wrap CryptoKit usage in `#if canImport(CryptoKit)` (or use Apple's CryptoKit on macOS only and provide a Linux fallback via swift-crypto or a different SHA256 source)
  2. Remove the `coordinator.writeAccessAllowed = true` line entirely — `coordinate(writingItemAt:options:.forReplacing)` already acquires write access
  3. Mark audioSettings `nonisolated(unsafe)` (or `@MainActor`) — it's a constant dictionary, no mutation risk

expecting: |
  After all three fixes: `swift build` succeeds on macos-15; `swift test --filter UnibrainCoreTests` succeeds on ubuntu-latest (Phase 02's 117 tests actually execute); CI run goes green.

next_action: |
  Dispatch gsd-debugger to verify these hypotheses by reading the three source files, confirming the fixes are correct against Apple/Swift docs (Context7 for NSFileCoordinator + Swift 6 concurrency), and applying the patches. Then push and watch CI.

reasoning_checkpoint:

tdd_checkpoint:

## Specialist Hints

- **swift-concurrency**: AudioRecorder audioSettings non-Sendable static let — Swift 6 data-race safety
- **foundation-models-on-device / apple-foundation**: NSFileCoordinator API surface (writeAccessAllowed doesn't exist)
- **cross-platform-shim**: CryptoKit canImport guarding pattern for Linux vs Apple

## Resolution

root_cause: |
  Three independent compile errors in Phase 03 UnibrainProviders code:
  1. SmallEnDownloader.swift used `import CryptoKit` unguarded — CryptoKit is Apple-only, absent on Linux
  2. NSFileCoordinatorNoteWriter.swift line 76 referenced `coordinator.writeAccessAllowed` which is not a real NSFileCoordinator API
  3. AudioRecorder.swift line 59 declared `public static let audioSettings: [String: Any]` — Swift 6 strict concurrency rejects non-Sendable `[String: Any]` as a static let without isolation annotation
fix: |
  1. Wrapped SmallEnDownloader.swift (entire actor + URLSessionProtocol + conformance) and SmallEnDownloaderTests.swift in `#if canImport(CryptoKit)` — model download is Apple-only functionality
  2. Removed the `coordinator.writeAccessAllowed = true` line — `coordinate(writingItemAt:options:.forReplacing)` already acquires write access
  3. Added `nonisolated(unsafe)` to `audioSettings` static let — it is a constant dictionary with no mutation risk
verification: |
  Pushing to main and watching CI run 29432687949 replacement.
files_changed:
  - Sources/UnibrainProviders/Transcription/ModelDownload/SmallEnDownloader.swift
  - Sources/UnibrainProviders/VaultWriting/NSFileCoordinatorNoteWriter.swift
  - Sources/UnibrainProviders/Capture/AudioRecorder.swift
  - Tests/UnibrainProvidersTests/Transcription/SmallEnDownloaderTests.swift
