---
phase: 06
plan: 03
subsystem: cloud-providers
tags: [cloud, openai, anthropic, grok, zai, reachability, retry, router]
requires:
  - 06-01-SUMMARY.md
  - 06-02-SUMMARY.md
provides:
  - TCPReachability (NWConnection wrapper for 2s TCP pre-check per CF-02)
  - ReachabilityProbe (protocol for test injection)
  - RetryComposer (3-retry exponential backoff per CF-03/CLOUD-10)
  - OpenAILLMSummarizer (gpt-4o, Bearer auth, /v1/chat/completions)
  - AnthropicLLMSummarizer (claude-sonnet-4, x-api-key + anthropic-version, /v1/messages)
  - GrokLLMSummarizer (grok-2, OpenAI-compatible, api.x.ai)
  - ZaiLLMSummarizer (glm-4.6, OpenAI-compatible, api.z.ai)
  - OpenAICompatibleClient (shared HTTP logic for Grok/Z.ai)
  - ProviderRouter (per-modality provider selection actor)
  - APIKeyStoring / ConsentStoring (test-injection protocols)
affects:
  - Sources/UnibrainCore/Protocols/LLMSummarizer.swift
tech-stack:
  added: []
  patterns:
    - Protocol abstraction for test injection (APIKeyStoring, ConsentStoring, ReachabilityProbe)
    - Shared OpenAI-compatible client factoring (DRY for Grok/Z.ai)
    - Actor-isolated provider router with refreshable settings snapshot
key-files:
  created:
    - Sources/UnibrainProviders/Reachability/TCPReachability.swift
    - Sources/UnibrainProviders/Cloud/RetryComposer.swift
    - Sources/UnibrainProviders/Cloud/CloudProviderSupport.swift
    - Sources/UnibrainProviders/Cloud/ProviderRouter.swift
    - Sources/UnibrainProviders/OpenAI/OpenAILLMSummarizer.swift
    - Sources/UnibrainProviders/Anthropic/AnthropicLLMSummarizer.swift
    - Sources/UnibrainProviders/Grok/GrokLLMSummarizer.swift
    - Sources/UnibrainProviders/Zai/ZaiLLMSummarizer.swift
    - Tests/UnibrainProvidersTests/Reachability/TCPReachabilityTests.swift
    - Tests/UnibrainProvidersTests/Cloud/RetryComposerTests.swift
    - Tests/UnibrainProvidersTests/Cloud/ProviderRouterTests.swift
    - Tests/UnibrainProvidersTests/OpenAI/OpenAILLMSummarizerTests.swift
    - Tests/UnibrainProvidersTests/Anthropic/AnthropicLLMSummarizerTests.swift
    - Tests/UnibrainProvidersTests/Grok/GrokLLMSummarizerTests.swift
    - Tests/UnibrainProvidersTests/Zai/ZaiLLMSummarizerTests.swift
  modified:
    - Sources/UnibrainCore/Protocols/LLMSummarizer.swift
decisions:
  - "LLMSummarizer protocol marked Sendable to enable actor-isolated ProviderRouter to return any LLMSummarizer across boundaries"
  - "OpenAICompatibleClient factors out shared HTTP logic for Grok and Z.ai (both OpenAI-compatible)"
  - "APIKeyStoring and ConsentStoring protocols enable test injection without depending on Keychain actor"
  - "ReachabilityProbe.check added as protocol extension default to match TCPReachability.check API"
  - "CloudStubEnv bundles all 5 stubs (APIKeyStore, ConsentStore, Reachability, Retry, HTTPSession) for each test scenario"
metrics:
  duration: 12m
  tasks: 6
  files: 16
status: complete
---

# Phase 06 Plan 03: Cloud Provider Base HTTP Client Layer Summary

**Plan:** 06-03
**Date Completed:** 2026-07-16
**Tasks:** 6/6 completed
**Status:** COMPLETE

## One-Liner Summary

Four cloud provider HTTP clients (OpenAI gpt-4o, Anthropic Claude Sonnet 4, Grok grok-2, Z.ai glm-4.6) with TCP reachability pre-checks (2s), 3-retry exponential backoff (2s/8s/30s), and a per-modality ProviderRouter — all protocol-abstracted for Linux-testable CI.

## Completed Tasks

| Task | Name | Commit | Files Created/Modified | Tests Added |
|------|------|--------|------------------------|-------------|
| 1 | TCPReachability for network pre-checks | `e67630d` | 2 files, +225 lines | 5 TCPReachabilityTests |
| 2 | RetryComposer with exponential backoff | `2a8f121` | 2 files, +204 lines | 5 RetryComposerTests |
| 3 | OpenAILLMSummarizer | `1d522c6` | 4 files, +497 lines | 7 OpenAILLMSummarizerTests |
| 4 | AnthropicLLMSummarizer | `fbbd36b` | 2 files, +332 lines | 7 AnthropicLLMSummarizerTests |
| 5 | GrokLLMSummarizer + ZaiLLMSummarizer | `2f64fb7` | 4 files, +420 lines | 12 tests (6 per provider) |
| 6 | ProviderRouter for provider selection | `6cc4352` | 3 files, +198 lines | 7 ProviderRouterTests |

## Files Created/Modified

### New Files Created

**Sources (UnibrainProviders/Reachability)**
- `Sources/UnibrainProviders/Reachability/TCPReachability.swift` (ReachabilityProbe protocol + NWConnection wrapper)

**Sources (UnibrainProviders/Cloud)**
- `Sources/UnibrainProviders/Cloud/RetryComposer.swift` (3-retry exponential backoff actor)
- `Sources/UnibrainProviders/Cloud/CloudProviderSupport.swift` (APIKeyStoring + ConsentStoring protocols)
- `Sources/UnibrainProviders/Cloud/ProviderRouter.swift` (per-modality LLM provider selection actor)

**Sources (UnibrainProviders — 4 cloud providers)**
- `Sources/UnibrainProviders/OpenAI/OpenAILLMSummarizer.swift` (gpt-4o, Bearer auth)
- `Sources/UnibrainProviders/Anthropic/AnthropicLLMSummarizer.swift` (Claude Sonnet 4, x-api-key)
- `Sources/UnibrainProviders/Grok/GrokLLMSummarizer.swift` (grok-2, OpenAI-compatible + shared client)
- `Sources/UnibrainProviders/Zai/ZaiLLMSummarizer.swift` (glm-4.6, OpenAI-compatible + shared client)

**Tests**
- `Tests/UnibrainProvidersTests/Reachability/TCPReachabilityTests.swift` (5 tests)
- `Tests/UnibrainProvidersTests/Cloud/RetryComposerTests.swift` (5 tests)
- `Tests/UnibrainProvidersTests/Cloud/ProviderRouterTests.swift` (7 tests)
- `Tests/UnibrainProvidersTests/OpenAI/OpenAILLMSummarizerTests.swift` (7 tests + shared CloudStubEnv)
- `Tests/UnibrainProvidersTests/Anthropic/AnthropicLLMSummarizerTests.swift` (7 tests)
- `Tests/UnibrainProvidersTests/Grok/GrokLLMSummarizerTests.swift` (6 tests)
- `Tests/UnibrainProvidersTests/Zai/ZaiLLMSummarizerTests.swift` (6 tests)

### Files Modified
- `Sources/UnibrainCore/Protocols/LLMSummarizer.swift` (marked `: Sendable` for actor boundary crossing)

## Test Results

**Overall:** 306/308 tests passing (99.4% — 2 pre-existing test isolation failures from 06-01)

**New tests added:** 43 across 7 test suites
- TCPReachabilityTests: 5/5 passing (success, refused, timeout, DNS failure, Sendable)
- RetryComposerTests: 5/5 passing (success-first, rateLimited retry, backoff, retryAfter, exhaustion)
- OpenAILLMSummarizerTests: 7/7 passing (success, Bearer, model/params, missing-key, no-consent, unreachable, retry-3x)
- AnthropicLLMSummarizerTests: 7/7 passing (success, x-api-key, version header, model/format, missing-key, no-consent, retry-3x)
- GrokLLMSummarizerTests: 6/6 passing (success, endpoint/model, Bearer, missing-key, no-consent, retry-3x)
- ZaiLLMSummarizerTests: 6/6 passing (success, endpoint/model, Bearer, missing-key, no-consent, retry-3x)
- ProviderRouterTests: 7/7 passing (ollama, openai, anthropic, grok, zai, off, updateSettings)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] LLMSummarizer protocol marked Sendable**
- **Found during:** Task 6
- **Issue:** `any LLMSummarizer` returned from `ProviderRouter` (an actor) cannot cross actor boundary because `LLMSummarizer` was not `Sendable`.
- **Fix:** Added `: Sendable` to the `LLMSummarizer` protocol declaration. All concrete conformances (`OllamaLLMSummarizer`, `OpenAILLMSummarizer`, `AnthropicLLMSummarizer`, `GrokLLMSummarizer`, `ZaiLLMSummarizer`) are already `Sendable` structs.
- **Files modified:** `Sources/UnibrainCore/Protocols/LLMSummarizer.swift`
- **Commit:** `6cc4352`

**2. [Rule 2 - Missing functionality] APIKeyStoring and ConsentStoring protocols**
- **Found during:** Task 3
- **Issue:** Cloud provider clients needed test-injectable alternatives to `APIKeyStore` (actor) and `ConsentStore` (actor) for Linux CI. The plan specified MockAPIKeyStore/MockConsentStore but no shared protocols existed.
- **Fix:** Created `APIKeyStoring` and `ConsentStoring` protocols with extensions on the real actors. All cloud provider clients depend on the protocols, not the concrete actors.
- **Files modified:** `Sources/UnibrainProviders/Cloud/CloudProviderSupport.swift`
- **Commit:** `1d522c6`

**3. [Rule 2 - Missing functionality] ReachabilityProbe.check added to protocol**
- **Found during:** Task 3
- **Issue:** Cloud provider clients call `reachability.check(host:port:timeout:)` but `check` was only on `TCPReachability`, not on the `ReachabilityProbe` protocol.
- **Fix:** Added `check` as a protocol extension default that delegates to `probe`.
- **Files modified:** `Sources/UnibrainProviders/Reachability/TCPReachability.swift`
- **Commit:** `1d522c6`

**4. [Rule 2 - Missing functionality] Shared SummarizerRequest/Response types**
- **Found during:** Task 3
- **Issue:** The plan specified each provider defines its own Request/Response, but all four cloud providers share identical request shape (transcript + courseContext) and response shape (summaryText). Duplicate types would add noise.
- **Fix:** Created shared `SummarizerRequest` and `SummarizerResponse` types in the OpenAI module, reused by all four providers.
- **Files modified:** `Sources/UnibrainProviders/OpenAI/OpenAILLMSummarizer.swift`
- **Commit:** `1d522c6`

## Threat Mitigation Compliance

| Threat ID | Component | Status | Verification |
|-----------|-----------|--------|--------------|
| T-06-12 | Cloud HTTPS endpoints | Accept | ATS enforced; HTTPS-only URLs hardcoded |
| T-06-13 | API keys in HTTP headers | Accept | Keys in Authorization/x-api-key headers (TLS-encrypted in transit); never logged |
| T-06-14 | Consent check bypass | Mitigated | Every provider checks ConsentStore before HTTP (unit tested) |
| T-06-15 | Retry loop without backoff | Mitigated | RetryComposer enforces [2s, 8s, 30s] exponential backoff (unit tested) |
| T-06-16 | TCPReachability false positive | Accept | Pre-flight check only; false positive = fallback option |
| T-06-17 | ProviderRouter returns wrong provider | Mitigated | All 6 enum cases unit tested (Task 6) |

## Key Decisions Made

### Decision 1: OpenAICompatibleClient for Grok + Z.ai
**Choice:** Shared internal struct factoring out common OpenAI-compatible HTTP logic.
**Rationale:** Grok (api.x.ai) and Z.ai (api.z.ai) both use OpenAI-compatible Chat Completions format with Bearer auth. Only the endpoint URL, model name, and CloudProvider enum case differ. DRY principle — avoids 200+ lines of duplicated HTTP code.

### Decision 2: CloudStubEnv test fixture pattern
**Choice:** Single `CloudStubEnv` struct bundles all 5 stubs (APIKeyStore, ConsentStore, Reachability, Retry, HTTPSession) with factory methods for each test scenario (httpSuccess, httpStatus, noAPIKey, noConsent, unreachable).
**Rationale:** Eliminates 20+ lines of boilerplate per test. Shared across all 4 provider test suites. Factory methods encode the exact stub configuration for each scenario.

### Decision 3: Anthropic x-api-key header (NOT Bearer)
**Choice:** Use `x-api-key` header + `anthropic-version: 2023-06-01` for Anthropic, NOT Authorization Bearer.
**Rationale:** Per Anthropic API docs (06-RESEARCH.md). Missing `anthropic-version` causes 400 errors. CRITICAL difference from OpenAI/Grok/Z.ai format. Unit tested explicitly (Task 4 test 2).

### Decision 4: Anthropic system prompt at top-level
**Choice:** System prompt lives in the `system` field of MessagesRequest, NOT in the `messages` array.
**Rationale:** Per Anthropic Messages API format. Different from OpenAI where system prompt is the first message in the array. Unit tested (Task 4 test 4 verifies `!decoded.system.isEmpty`).

## Acceptance Criteria Verification

From plan `<success_criteria>`:

- [x] TCPReachability checks host:443 with 2s timeout (Task 1)
- [x] RetryComposer enforces exponential backoff (2s, 8s, 30s) (Task 2)
- [x] OpenAILLMSummarizer uses gpt-4o with Bearer auth (Task 3)
- [x] AnthropicLLMSummarizer uses Claude Sonnet 4 with x-api-key + anthropic-version (Task 4)
- [x] GrokLLMSummarizer uses grok-2 (OpenAI-compatible) (Task 5)
- [x] ZaiLLMSummarizer uses glm-4.6 (OpenAI-compatible) (Task 5)
- [x] All providers throw .apiKeyMissing when no key in Keychain (Tasks 3-5)
- [x] All providers throw .consentDenied when no consent record (Tasks 3-5)
- [x] All providers throw .providerUnreachable when TCP check fails (Task 3 — pattern shared)
- [x] All providers retry 3x on transient failures (Tasks 3-5)
- [x] ProviderRouter returns correct LLMSummarizer per LLMProvider enum (Task 6)

## Known Stubs

None — no stubs or placeholder values. All HTTP clients are fully functional with mock URLSession for testing. Production use requires real API keys in Keychain and consent records in `.unibrain/consent.json`.

## Threat Flags

None — no security-relevant surface introduced beyond the plan's threat model. All 6 threats (T-06-12 through T-06-17) are mitigated or accepted as documented.

## Dependencies Added

Zero new external dependencies. All additions use:
- System frameworks: Foundation, FoundationNetworking (Linux), Network (Darwin)
- Existing protocols: LLMSummarizer, HTTPSession (from 06-02)
- Existing types: ProviderError, CloudProvider, Modality, CourseContext (from 06-01/02)

## Self-Check: PASSED

**Verification:**
- [x] swift build succeeds on WSL2 Linux
- [x] swift test passes 306/308 (99.4% — 2 pre-existing isolation failures from 06-01)
- [x] 6/6 tasks committed with conventional format
- [x] Each task follows TDD: RED -> GREEN
- [x] SUMMARY.md written before final commit
- [x] Deviations documented (4 auto-fixed issues)

**Files verified to exist:**
- Sources/UnibrainProviders/Reachability/TCPReachability.swift
- Sources/UnibrainProviders/Cloud/RetryComposer.swift
- Sources/UnibrainProviders/Cloud/CloudProviderSupport.swift
- Sources/UnibrainProviders/Cloud/ProviderRouter.swift
- Sources/UnibrainProviders/OpenAI/OpenAILLMSummarizer.swift
- Sources/UnibrainProviders/Anthropic/AnthropicLLMSummarizer.swift
- Sources/UnibrainProviders/Grok/GrokLLMSummarizer.swift
- Sources/UnibrainProviders/Zai/ZaiLLMSummarizer.swift

**Commit hashes verified:**
- e67630d (Task 1: TCPReachability)
- 2a8f121 (Task 2: RetryComposer)
- 1d522c6 (Task 3: OpenAILLMSummarizer)
- fbbd36b (Task 4: AnthropicLLMSummarizer)
- 2f64fb7 (Task 5: Grok + Zai)
- 6cc4352 (Task 6: ProviderRouter)

**Requirements Status:**
- CLOUD-01 (per-modality Settings selectors) — ProviderRouter delivers routing
- CLOUD-03 (OpenAI integration) — OpenAILLMSummarizer complete
- CLOUD-04 (Anthropic integration) — AnthropicLLMSummarizer complete
- CLOUD-05 (Grok integration) — GrokLLMSummarizer complete
- CLOUD-06 (Z.ai integration) — ZaiLLMSummarizer complete
- CLOUD-09 (cloud as alternative) — ProviderRouter selects based on Settings
- CLOUD-10 (cloud failure surfaces error) — RetryComposer + ProviderError cases
- CLOUD-11 (network reachability check) — TCPReachability per CF-02
- CF-02 (2s TCP timeout) — TCPReachability with 2s default
- CF-03 (3-retry exponential backoff) — RetryComposer with [2s, 8s, 30s]

**Phase Status:** COMPLETE
**Next Action:** Continue to 06-04-PLAN.md (or next plan in Phase 06)
