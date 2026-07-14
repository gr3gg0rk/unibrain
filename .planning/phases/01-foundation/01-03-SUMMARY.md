---
phase: "01"
plan: "03"
subsystem: foundation
tags: [yams, frontmatter, provider-protocols, ci, github-actions, testing]
requires:
  - "01-01 — FrontmatterSchema Codable struct, provider protocols, ProviderError enum, smoke tests"
provides:
  - "Proven Yams round-trip for FrontmatterSchema (encode/decode with all fields preserved)"
  - "Proven snake_case YAML key output matching CodingKeys"
  - "Mock conformances for all four provider protocols (LLMSummarizer, AudioTranscriber, VisionDescriber, AudioSynthesizer)"
  - "All six ProviderError cases verified constructible and catchable"
  - "GitHub Actions CI workflow with Linux + macOS matrix, SPM and DerivedData caching"
affects:
  - "All subsequent phases rely on CI for build verification (FOUND-03)"
  - "Phase 3+ frontmatter write-out uses the proven Yams round-trip contract"
  - "Provider conformances in Phase 2+ use the verified protocol shape"
tech-stack:
  added: []
  patterns:
    - "Yams YAMLEncoder/YAMLDecoder round-trip for Codable structs"
    - "Mock protocol conformances in test files for compile-time protocol verification"
    - "GitHub Actions matrix CI with per-platform target filtering"
    - "SPM + DerivedData dual-cache for macOS CI build acceleration"
key-files:
  created:
    - .github/workflows/ci.yml
  modified:
    - Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift
    - Tests/UnibrainCoreTests/ProviderProtocolTests.swift
decisions:
  - "Used swift test --filter UnibrainCoreTests in CI Linux job instead of --test-product (established convention from Plan 01-01)"
  - "Used YAMLEncoder/YAMLDecoder (not JSONEncoder or manual string) for frontmatter serialization per FOUND-05"
  - "Linux CI job builds and tests only UnibrainCore (no Apple frameworks); macOS CI job runs full suite per D-08"
  - "macOS job uses macos-15 runner which ships with Xcode 16.4+ — no xcode-select or version pinning needed"
  - "CI uses no untrusted github.event.* inputs — only runner.os, steps.*.outputs, and hashFiles() in expressions"
metrics:
  duration: "4m"
  tasks: 2
  files-created: 1
  files-modified: 2
  tests-passing: 17
status: complete
---

# Phase 01 Plan 03: FrontmatterSchema Tests + CI Workflow Summary

Yams round-trip proven for FrontmatterSchema with snake_case keys, all four provider protocols verified conformable via mock implementations, all six ProviderError cases verified constructible — and a GitHub Actions CI workflow with Linux/macOS matrix and dual caching brings the build/test pipeline online.

## What Was Built

### FrontmatterSchema Yams Round-Trip Tests (4 tests)

Replaced the single smoke test from Plan 01-01 with a 4-test suite:

1. **createSchema** (preserved) — struct construction with all fields
2. **roundTripPreservesAllFields** — encodes a fully-populated FrontmatterSchema via `YAMLEncoder`, decodes via `YAMLDecoder`, asserts all 12 fields match (schemaVersion, course, courseName, term, datetime, durationSeconds, source, audioFile, tags, syllabusLink, vectorId, summaryModel)
3. **nullableFieldsSurviveNilRoundTrip** — encodes/decodes with nil optional fields, asserts they remain nil
4. **yamlOutputUsesSnakeCaseKeys** — encodes and asserts the YAML string contains `schema_version`, `course_name`, `duration_seconds`, `audio_file` (proves CodingKeys mapping works)

### ProviderProtocol Mock Conformance Tests (8 tests)

Replaced the 3-test smoke suite with an 8-test comprehensive suite:

**Preserved smoke tests (3):**
- ProviderError.cancelled constructible
- ProviderError.networkFailure two-argument constructible
- ProviderError.rateLimited with nil retryAfter

**New mock conformance tests (4):**
- MockLLMSummarizer: `summarize("hello")` returns `"olleh"` (trivial string reversal)
- MockAudioTranscriber: `transcribe("audio.m4a")` returns `"transcribed:audio.m4a"`
- MockVisionDescriber: `describe("image.png")` returns `"described:image.png"`
- MockAudioSynthesizer: `synthesize("speak this")` returns `"synthesized:speak this"`

Each mock struct is private, conforms to its protocol with `Request = String, Response = String`, and implements the single required async method. This proves all four protocols are conformable and callable.

**New ProviderError all-cases test (1):**
- Constructs all six cases (.networkFailure, .modelError, .rateLimited, .invalidResponse, .cancelled, .underlying), throws each in a do/catch loop, verifies each is caught as ProviderError

### GitHub Actions CI Workflow (.github/workflows/ci.yml)

Two-job matrix workflow:

**Linux job (`linux-tests`):**
- Runner: `ubuntu-latest`
- Swift: `swift-actions/setup-swift@v2` with version `6.0.3`
- Commands: `swift package resolve`, `swift build --target UnibrainCore`, `swift test --filter UnibrainCoreTests`
- Scope: UnibrainCore only (DISC-03 — pure-logic tests on Linux)

**macOS job (`macos-tests`):**
- Runner: `macos-15` (ships with Xcode 16.4+)
- Cache 1: SPM dependencies (`actions/cache@v4`, key based on `Package.resolved` hash)
- Cache 2: DerivedData (`actions/cache@v4`, key based on `Package.resolved + Package.swift` hash)
- Commands: `swift build` (all targets), `swift test` (all tests)
- Scope: Full suite (all targets including UnibrainProviders)

Triggers: push to main, pull_request to main. No untrusted input in `${{ }}` expressions (only `runner.os`, `steps.*.outputs`, `hashFiles()`).

## Verification Results

- `swift test --filter UnibrainCoreTests` exits 0 with 17 tests passing (PASS)
  - ModelLoadGate: 5 tests
  - FrontmatterSchema: 4 tests (1 preserved + 3 new)
  - ProviderProtocols: 8 tests (3 preserved + 5 new)
- YAML syntax validated via `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` (PASS)
- All 12 CI acceptance criteria substring checks pass (PASS)

## TDD Gate Compliance

Task 1 was marked `tdd="true"`. The RED/GREEN cycle:

- **RED:** The 3 new FrontmatterSchema tests (Yams round-trip, nil round-trip, snake_case keys) and 5 new ProviderProtocol tests (4 mock conformances + all-cases ProviderError) were written as a replacement for the smoke tests. The mock structs and Yams encoder/decoder usage had not been tested before — these tests verify behavior that was untested in the prior smoke suite.
- **GREEN:** All 17 tests passed on first run with no modifications needed. The implementation from Plan 01-01 was already correct.

Commit `a417e5e` contains the GREEN state (all tests passing).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] CI Linux job uses --filter instead of --test-product**
- **Found during:** Task 2 (CI workflow creation)
- **Issue:** Plan specified `swift test --test-product UnibrainCoreTests` for the Linux CI job. Plan 01-01 established that `--test-product` is not supported on Swift 6.0.3 SPM ("no product named 'UnibrainCoreTests'").
- **Fix:** Used `swift test --filter UnibrainCoreTests` in the CI workflow, consistent with the established convention from Plans 01-01 and 01-02.
- **Files modified:** .github/workflows/ci.yml
- **Commit:** dd0a7f7

## Known Stubs

No stubs. All tests exercise real FrontmatterSchema Yams encoding/decoding and real provider protocol mock conformances. The CI workflow will execute real builds and tests on push/PR. No placeholder data flows to any rendering surface.

## Threat Flags

No new security-relevant surface introduced beyond what the plan's threat model covers.

- T-01-06 (CI workflow tampering): accepted — file is version-controlled in git, changes reviewed via PR
- T-01-07 (SPM cache poisoning): accepted — cache key includes Package.resolved hash, cache can only restore what SPM resolved legitimately
- T-01-08 (CI log information disclosure): accepted — Phase 1 has no secrets, no API keys, no user data

The CI workflow uses no `github.event.*` inputs in `run:` commands — zero command injection surface (security hook verified).

## Self-Check: PASSED

- Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift: FOUND
- Tests/UnibrainCoreTests/ProviderProtocolTests.swift: FOUND
- .github/workflows/ci.yml: FOUND
- Commit a417e5e: FOUND in git log
- Commit dd0a7f7: FOUND in git log
