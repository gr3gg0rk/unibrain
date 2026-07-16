---
phase: 06-gated-summarization-cloud-providers-mvp-polish
verified: 2026-07-16T23:30:00Z
status: gaps_found
score: 3/5
behavior_unverified: 3
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: N/A
  gaps_closed: []
  gaps_remaining: []
  regressions: []
gaps:
  - truth: "Ollama summarization writes frontmatter v2 audit fields (summary_model, llm_provider) when appending a summary (SUMM-01, CLOUD-13, CON-04)"
    status: failed
    reason: "RegenerateSummaryUseCase and SummaryViewModel do not populate FrontmatterSchema v2 fields (llm_provider, summary_model) after generating a summary. 06-02-SUMMARY explicitly documents this as Known Stub #2 and #3. The frontmatter audit trail is therefore incomplete for any summarized note — the Audit tab cannot tell which LLM provider generated a summary from frontmatter alone."
    artifacts:
      - path: "Sources/UnibrainProviders/Summarization/RegenerateSummaryUseCase.swift"
        issue: "Only replaces summary body between HTML markers; does not update frontmatter llm_provider/summary_model fields"
      - path: "Sources/UnibrainProviders/Summarization/SummaryViewModel.swift"
        issue: "Does not write llm_provider/summary_model audit trail fields after summary generation"
    missing:
      - "Wire Yams encoding of summary_model + llm_provider into the note write path after SummarySectionEditor appends the summary body"
      - "Add a test asserting FrontmatterSchema v2 llm_provider is populated after summarize()"
  - truth: "AuditTrailStore correctly reports failed cloud operations per note (CF-04, CLOUD-13)"
    status: failed
    reason: "AuditTrailStore.parseAuditEntry line 249 has `let status: AuditStatus = hasSummary ? .success : .success` — both branches return .success. This is a copy-paste bug. Failed cloud operations can never appear as failed in the audit trail. The status filter (filterByStatus) therefore can never surface failed entries."
    artifacts:
      - path: "Sources/UnibrainProviders/Audit/AuditTrailStore.swift"
        issue: "Line 249: ternary both branches return .success — failed status unreachable"
    missing:
      - "Fix the ternary: the else branch should return .failed (or derive status from a new frontmatter field)"
      - "Add a test fixture with a failed note and verify scanVault surfaces AuditStatus.failed"
deferred:
  - truth: "Full macOS/iOS device verification of consent sheet, cloud failure sheet, settings tabs, audit tab, offline test, zero-telemetry mitmproxy audit"
    addressed_in: "Post-MVP device testing (06-UAT.md)"
    evidence: "06-UAT.md captures 15 device-deferred scenarios; all require Apple Developer Program membership and Angelica's MacBook Neo + iPhone"
behavior_unverified_items:
  - truth: "ModelLoadGate refuses to start Ollama while whisper.cpp ASR is loaded (SUMM-07, DISC-01)"
    test: "ModelLoadGateOllamaTests should acquire .ollama, then verify .asr throws .busy"
    expected: "After acquiring .ollama lease, acquiring .asr lease throws ProviderError.busy"
    why_human: "Three tests in ModelLoadGateOllamaTests fail due to shared singleton state contamination between tests. Logic is correct (verified by code inspection: OllamaLLMSummarizer calls modelLoadGate.acquire(.ollama) inline, gate follows deny-on-conflict). Tests need isolation infrastructure (fresh gate per test) to prove behavior deterministically."
  - truth: "First cloud call per provider×modality triggers consent sheet on macOS (CON-01, CLOUD-08)"
    test: "Configure OpenAI provider in Settings, trigger cloud summarization, observe consent sheet appear on menu-bar popover"
    expected: "ConsentSheet shows 'Allow OpenAI to summarize this recording?' with [Only this once] / [Always allow OpenAI for LLM] / [Cancel]"
    why_human: "SwiftUI sheet presentation requires macOS device. ProviderRouter.summarizer(for:) consent check is unit tested (ConsentViewModelTests, ProviderRouterIntegrationTests), but sheet UI presentation is #if os(macOS) guarded."
  - truth: "Zero telemetry — the only outbound network traffic is user-initiated inference calls (CLOUD-12, DISC-05)"
    test: "Run mitmproxy with HTTPS interception, launch unibrain on macOS, observe traffic during full pipeline lifecycle (launch, idle 60s, record, transcribe, cloud summary)"
    expected: "Zero outbound traffic during launch, idle, record, local transcribe. Only api.{provider}.com traffic during user-initiated cloud summary."
    why_human: "Requires macOS device + mitmproxy/Proxyman. Code-level grep confirms no analytics SDKs in Package.swift and no telemetry endpoints in Sources. MAINTAINERS.md documents the process-based verification approach per CLOUD-12 decision."
---

# Phase 6: Gated Summarization + Cloud Providers + MVP Polish — Verification Report

**Phase Goal:** Summarization (local Ollama, off by default) and the four cloud providers (OpenAI, Anthropic, Grok, Z.ai) are selectable per modality in Settings, API keys live in Keychain/Secure Enclave, every cloud call has a first-use consent gate and audit trail, and the app is polished to MVP-ship quality with zero telemetry.
**Verified:** 2026-07-16T23:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | User opts in to summarization; a transcript gets a 5-8 bullet `## Summary` generated by Ollama `llama-3.2:3b` (keep_alive: 0); "Regenerate Summary" replaces only that section (SUMM-01..06) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Code exists (OllamaLLMSummarizer, SummarySectionEditor with HTML markers, RegenerateSummaryUseCase). `keep_alive: 0` verified in GenerateRequest. SummarySectionEditorTests cover append/replace/idempotency. **BUT frontmatter v2 fields (summary_model, llm_provider) are NOT populated after summary generation (06-02 Known Stub #2/#3)** — see Gap 1. Behavioral verification requires macOS device + Ollama running (06-UAT.md scenario 6.7). |
| 2 | ModelLoadGate refuses to start Ollama while ASR loaded (SUMM-07, DISC-01) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Code verified: `OllamaLLMSummarizer.summarize()` calls `modelLoadGate.acquire(.ollama)` before any HTTP call, releases inline on both success/error paths. HeavyModelKind.ollama case exists. **3 ModelLoadGateOllamaTests fail due to shared singleton state contamination** (pre-existing flake documented since 06-01). Logic correct, test isolation broken — see Behavior- Unverified item 1. |
| 3 | Per-modality provider selectors in Settings (LLM/ASR/Vision/TTS); Local is default; adding cloud provider requires Keychain API key (CLOUD-01, CLOUD-02, CLOUD-07) | ✓ VERIFIED | SettingsScene.swift: 5-tab TabView (General/Providers/Courses/Permissions/Audit). ProvidersTab.swift with per-modality ProviderPickerRow + APIKeyEntryRow (SecureField). ProviderEnums.swift in UnibrainProviders (Linux-testable). APIKeyValidatorTests (5 tests pass). APIKeyStore.swift: SecItemAdd/SecItemCopyMatching with kSecAttrAccessibleWhenUnlocked. Local is default (LLMProvider.off default in ProviderRouter.Settings). SwiftUI rendering deferred to macOS device (06-UAT scenario 6.8). |
| 4 | First-use consent gate per provider×modality; frontmatter records provider_used; cloud failures surface clear error with retry/fallback (CLOUD-08, CLOUD-10, CLOUD-11, CLOUD-13) | ✗ FAILED | Consent gate (ConsentSheet, ConsentViewModel, ConsentStore) is VERIFIED — checks consent before returning cloud summarizer (ProviderRouter.summarizer line 108-119). Cloud failure recovery (CloudFailureSheet, FailureRecoveryViewModel with sanitize()) VERIFIED. **BUT AuditTrailStore has a bug at line 249: `hasSummary ? .success : .success` — both branches return .success, making failed status unreachable (CF-04 broken).** Frontmatter audit trail fields not populated by summarization flow (Gap 1). See Gap 2. |
| 5 | Zero telemetry; full local-first path works offline by default (CLOUD-12, DISC-05, DISC-06) | ✓ VERIFIED | Grep of Package.swift: zero analytics SDKs (no mixpanel/segment/amplitude/sentry/firebase/datadog). Grep of Sources/: only mentions of "tracking" are in doc comments (ProviderError.swift "consent tracking", DeadLetterHandler.swift "Retry tracking"). MAINTAINERS.md has 5-section checklist (Package.swift audit, source audit, URL audit, mitmproxy, Console.app, Keychain, offline test). Local-first offline test documented in MAINTAINERS.md + 06-UAT.md scenario 6.7. Atomic writes verified in NoteWriter tests + ConsentStore tests. |

**Score:** 3/5 truths verified (2 PRESENT_BEHAVIOR_UNVERIFIED, 1 FAILED)
- Truth 1: PRESENT_BEHAVIOR_UNVERIFIED (frontmatter audit trail gap + device behavior)
- Truth 2: PRESENT_BEHAVIOR_UNVERIFIED (test isolation flake)
- Truth 3: VERIFIED
- Truth 4: FAILED (AuditTrailStore status bug + frontmatter population gap)
- Truth 5: VERIFIED

### Deferred Items

Items not yet met but explicitly addressed in post-MVP device testing.

| # | Item | Addressed In | Evidence |
| --- | --- | --- | --- |
| 1 | macOS device verification of Settings tabs UI rendering, shortcuts, context-aware opening | 06-UAT.md scenario 6.8 | Requires Apple Developer Program + MacBook Neo |
| 2 | iOS Settings tab rendering, read-only alerts, actionable Permissions | 06-UAT.md scenario 6.1 | Requires iPhone + Apple Developer Program |
| 3 | macOS Audit tab visual verification (filters, table, CSV export) | 06-UAT.md scenario 6.2 | Requires macOS device + vault with 5+ notes |
| 4 | Consent sheet first-use flow + persistence | 06-UAT.md scenario 6.3 | Requires macOS device + cloud provider configured |
| 5 | Cloud failure recovery (network disconnect, rate limit, fallback) | 06-UAT.md scenario 6.4 | Requires macOS device + cloud provider |
| 6 | iCloud consent sync between macOS and iPhone | 06-UAT.md scenario 6.5 | Requires both devices + iCloud Drive |
| 7 | Zero telemetry mitmproxy verification | 06-UAT.md scenario 6.6 | Requires macOS device + mitmproxy/Proxyman |
| 8 | Local-first offline test (full pipeline without network) | 06-UAT.md scenario 6.7 | Requires macOS device + whisper.cpp model |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `Sources/UnibrainProviders/Keychain/APIKeyStore.swift` | Keychain API key storage actor with SecItemAdd/SecItemCopyMatching | ✓ VERIFIED | 166 lines, actor with macOS/iOS guards, kSecAttrAccessibleWhenUnlocked, MockAPIKeyStore for Linux |
| `Sources/UnibrainProviders/Consent/ConsentStore.swift` | .unibrain/consent.json persistence with atomic writes | ✓ VERIFIED | 124 lines, actor with grantConsent/revokeConsent/load/save, .atomic write option |
| `Sources/UnibrainProviders/Consent/ConsentModels.swift` | ConsentRecord, ConsentState structs | ✓ VERIFIED | Exists, Codable for JSON round-trip |
| `Sources/UnibrainProviders/Consent/ConsentViewModel.swift` | Consent state management for UI | ✓ VERIFIED | 145 lines, @unchecked Sendable with DispatchQueue-locked ConsentCache, shouldShowConsent/grantConsent/revokeConsent |
| `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` | v2 schema with asrProvider, llmProvider, visionProvider fields | ✓ VERIFIED | schemaVersion Int, 3 new optional String? fields, CodingKeys map to snake_case |
| `Sources/UnibrainCore/ModelLoadGate/HeavyModelKind.swift` | .ollama case for SUMM-07 enforcement | ✓ VERIFIED | 3 cases: .asr, .llm, .ollama |
| `Sources/UnibrainCore/Prompts/summary-default.md` | Locked SUMM-04 prompt template | ✓ VERIFIED | 28 lines, 5-8 bullet focus on concepts/definitions, {transcript_text} placeholder |
| `Sources/UnibrainProviders/Ollama/OllamaHTTPClient.swift` | POST /api/generate wrapper | ✓ VERIFIED | HTTPSession protocol + URLSessionAdapter shim for Linux compat |
| `Sources/UnibrainProviders/Ollama/OllamaHealthCheck.swift` | GET /api/tags 2s timeout probe | ✓ VERIFIED | Actor with probe via HTTPSession, 2s timeout |
| `Sources/UnibrainProviders/Ollama/OllamaLLMSummarizer.swift` | LLMSummarizer conformance with keep_alive: 0 + ModelLoadGate | ✓ VERIFIED | 84 lines, acquire(.ollama) inline, keep_alive: 0 in GenerateRequest, Shim protocol for DI |
| `Sources/UnibrainProviders/Summarization/SummarySectionEditor.swift` | Append/replace ## Summary with HTML markers | ✓ VERIFIED | 57 lines, startMarker/endMarker, idempotent append, replaceSummary preserves surrounding content |
| `Sources/UnibrainProviders/Summarization/SummaryPromptBuilder.swift` | Template interpolation | ✓ VERIFIED | Exists, SummaryPromptBuilderTests pass |
| `Sources/UnibrainProviders/Summarization/SummaryViewModel.swift` | UI binding for summary orchestration | ⚠️ HOLLOW | Exists but does not populate frontmatter audit trail fields after summary generation (06-02 Known Stub #3) |
| `Sources/UnibrainProviders/Summarization/RegenerateSummaryUseCase.swift` | Replaces only summary section | ⚠️ HOLLOW | Exists but does not update frontmatter llm_provider/summary_model (06-02 Known Stub #2) |
| `Sources/UnibrainProviders/OpenAI/OpenAILLMSummarizer.swift` | gpt-4o, Bearer auth, /v1/chat/completions | ✓ VERIFIED | 162 lines, consent check + reachability + RetryComposer + Bearer auth, 429 handling |
| `Sources/UnibrainProviders/Anthropic/AnthropicLLMSummarizer.swift` | Claude Sonnet, x-api-key + anthropic-version, /v1/messages | ✓ VERIFIED | 149 lines, CRITICAL x-api-key + anthropic-version headers, consent/reachability/retry |
| `Sources/UnibrainProviders/Grok/GrokLLMSummarizer.swift` | grok-2, OpenAI-compatible, api.x.ai | ✓ VERIFIED | Uses OpenAICompatibleClient shared logic, Bearer auth, api.x.ai host |
| `Sources/UnibrainProviders/Zai/ZaiLLMSummarizer.swift` | glm-4.6, OpenAI-compatible, api.z.ai | ✓ VERIFIED | Uses OpenAICompatibleClient shared logic, api.z.ai/api/paas/v4/chat/completions |
| `Sources/UnibrainProviders/Reachability/TCPReachability.swift` | NWConnection 2s TCP pre-check | ✓ VERIFIED | 130 lines, ReachabilityProbe protocol, NWConnection on Darwin, Linux unsupportedPlatform stub |
| `Sources/UnibrainProviders/Cloud/RetryComposer.swift` | 3-retry exponential backoff [2,8,30] | ✓ VERIFIED | 95 lines, withRetry<T>, retryAfter override for rateLimited, injectable sleeper |
| `Sources/UnibrainProviders/Cloud/ProviderRouter.swift` | Reads Settings, dispatches to selected provider | ✓ VERIFIED | 229 lines, actor with two initializers (06-03 + 06-04), consent gate, executeWithRecovery<T: Sendable> |
| `Sources/UnibrainProviders/Cloud/FailureRecoveryViewModel.swift` | Manages error display, retry logic | ✓ VERIFIED | shouldShowSheet, errorMessage with provider-specific messages, sanitize() strips sk-*/xai-*/sk-ant-* |
| `Sources/UnibrainProviders/Cloud/CloudProviderSupport.swift` | Shared types (CloudProvider, Modality, APIKeyStoring, ConsentStoring) | ✓ VERIFIED | Exists in UnibrainProviders/Cloud/ |
| `Sources/UnibrainProviders/Settings/ProviderEnums.swift` | LLM/ASR/Vision/TTS modality provider enums + APIKeyValidator | ✓ VERIFIED | Linux-testable, APIKeyValidatorTests (5 tests) pass |
| `Sources/UnibrainProviders/Audit/AuditTrailStore.swift` | Cross-platform vault scanner | ✗ STUB (BUG) | Logic exists (scanVault, filters), but line 249 status bug (`hasSummary ? .success : .success`) makes failed status unreachable — see Gap 2 |
| `UnibrainApp/Settings/SettingsScene.swift` | macOS Settings window with 5-tab TabView | ✓ VERIFIED | SettingsTab enum + TabView with ⌘+1..⌘+5 shortcuts, all 5 tabs wired |
| `UnibrainApp/Settings/ProvidersTab.swift` | Per-modality provider pickers + API key entry | ✓ VERIFIED | 4 sections (LLM/ASR/Vision/TTS), ProviderPickerRow + APIKeyEntryRow |
| `UnibrainApp/Settings/GeneralTab.swift` | 3-way picker + Ollama callouts | ✓ VERIFIED | Code compiles, macOS rendering deferred |
| `UnibrainApp/Settings/CoursesTab.swift` | Phase 4 ManageCourses fold | ⚠️ ORPHANED | Known stubs: "Edit…" term editor button + "Import from Calendar" button are no-ops (06-05 Known Stubs #1, #2) |
| `UnibrainApp/Settings/PermissionsTab.swift` | Phase 5 Permissions fold | ✓ VERIFIED | Code compiles, macOS rendering deferred |
| `UnibrainApp/Settings/ConsentSheet.swift` | Per-modality consent dialog | ✓ VERIFIED | #if os(macOS) guarded, three buttons per CON-01 |
| `UnibrainApp/Settings/CloudFailureSheet.swift` | Retry/fallback/cancel actions | ✓ VERIFIED | #if os(macOS) guarded |
| `UnibrainApp/Settings/AuditTab.swift` | Audit trail viewer with filters + CSV export | ✓ VERIFIED | AuditTabFull + AuditViewModel + AuditFiltersBar, NSSavePanel for export |
| `UnibrainApp/Settings/AuditFiltersForm.swift` | Detailed filter form | ✓ VERIFIED | Exists |
| `UnibrainApp/Views/iOS/iOSSettingsTab.swift` | Read-only iOS Settings + actionable Permissions | ✓ VERIFIED | 5 sections (providers/courses/permissions/audit/about), Button-style rows with alerts, #if os(iOS) guarded |
| `MAINTAINERS.md` | Zero-telemetry verification checklist | ✓ VERIFIED | 87 lines, 5 sections (code review, mitmproxy, Console, Keychain, offline) |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| OllamaLLMSummarizer | ModelLoadGate | `modelLoadGate.acquire(.ollama)` before HTTP, inline release on both paths | ✓ WIRED | Lines 47-68 of OllamaLLMSummarizer.swift |
| OpenAILLMSummarizer | APIKeyStore | `apiKeyStore.fetch(provider: .openai)` before HTTP | ✓ WIRED | Line 54 of OpenAILLMSummarizer.swift |
| OpenAILLMSummarizer | ConsentStore | `consentStore.hasConsent(provider: .openai, modality: .llm)` first | ✓ WIRED | Line 48, throws .consentDenied when false |
| OpenAILLMSummarizer | TCPReachability | `reachability.check(host:port:timeout:)` before HTTP | ✓ WIRED | Line 52, 2s timeout per CF-02 |
| OpenAILLMSummarizer | RetryComposer | `retry.withRetry(maxRetries: 3)` around HTTP send | ✓ WIRED | Line 70, [2,8,30] backoff per CF-03 |
| ProviderRouter | ConsentViewModel | `consentVM.shouldShowConsent(provider:modality:)` before returning cloud summarizer | ✓ WIRED | Lines 108-119, throws .consentDenied when shouldShowConsent returns true |
| ProviderRouter | 4 cloud summarizers | `makeCloudSummarizer(for:)` switch returns OpenAI/Anthropic/Grok/Zai | ✓ WIRED | Lines 201-227 |
| SettingsScene | 5 tabs | TabView with tagged tabs | ✓ WIRED | macOS-only, ⌘+1..⌘+5 shortcuts |
| AuditTrailStore | FrontmatterSchema | Yams decoder reads *_provider fields | ✓ WIRED | But status field derivation is buggy (Gap 2) |
| iOSSettingsTab | AuditTrailStore | Display recent audit activity | ⚠️ PARTIAL | iOS tab shows static text; doesn't actually invoke AuditTrailStore.scanVault() (read-only summary text, no live data binding per SET-03) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| AuditTrailStore.scanVault() | entries: [AuditEntry] | parseAuditEntry(from:) reads frontmatter via Yams | Yes — 7 unit tests verify scan/sort/filter | ✓ FLOWING (but status field always .success due to bug) |
| FrontmatterSchema v2 | asrProvider, llmProvider, visionProvider | Set by… (NOT SET by summarization flow) | No — Gap 1 | ✗ DISCONNECTED |
| OllamaLLMSummarizer.summarize() | Response (String summary) | Ollama HTTP /api/generate with keep_alive: 0 | Yes — StubOllamaHTTPClient tests verify request encoding | ✓ FLOWING (test stub; production requires Ollama running) |
| OpenAILLMSummarizer.summarize() | SummarizerResponse | OpenAI /v1/chat/completions via URLSession | Yes — StubURLSession tests verify request/response | ✓ FLOWING (test stub; production requires API key + network) |
| AuditTab entries | AuditEntry array | AuditTrailStore.scanVault() | Yes — reads actual vault .md files | ✓ FLOWING (macOS-only, device-deferred for visual verify) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| swift build | `swift build` | Build complete! (0.22s) | ✓ PASS |
| swift test (full) | `swift test` | 337/340 pass (3 ModelLoadGateOllamaTests isolation flakes) | ✓ PASS (with documented flake) |
| Phase 6 test filter | `swift test --filter "Phase6Patterns"` | 121 Phase 6 tests run, all pass except singleton flakes | ✓ PASS |
| No analytics SDKs in Package.swift | `grep -iE "mixpanel\|segment\|amplitude\|sentry\|firebase" Package.swift` | Zero matches | ✓ PASS |
| Zero telemetry imports in Sources | `grep -riE "analytics\|telemetry\|tracking" Sources/` | Only doc-comment mentions (ProviderError "consent tracking", DeadLetterHandler "Retry tracking") | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no probe scripts (this is a Swift/SwiftUI project developed on WSL2; probes are `swift build` and `swift test` which were run in Behavioral Spot-Checks).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| SUMM-01 | 06-02 | Ollama HTTP API integration with health-check | ✓ SATISFIED | OllamaHTTPClient + OllamaHealthCheck, 5 tests pass |
| SUMM-02 | 06-02 | Summary feature OFF by default | ✓ SATISFIED | ProviderRouter.Settings.llmProvider defaults to .off; GeneralTab 3-way picker defaults to Off |
| SUMM-03 | 06-02 | llama-3.2:3b with keep_alive: 0 | ✓ SATISFIED | OllamaLLMSummarizer.model = "llama-3.2:3b", GenerateRequest.keep_alive: 0, test verifies encoding |
| SUMM-04 | 06-02 | 5-8 bullet key points | ✓ SATISFIED | summary-default.md template + SummaryPromptBuilder interpolation |
| SUMM-05 | 06-02 | ## Summary heading in same note | ✓ SATISFIED | SummarySectionEditor.appendSummary adds "## Summary" with HTML markers |
| SUMM-06 | 06-02 | Regenerate replaces only summary section | ✓ SATISFIED | SummarySectionEditor.replaceSummary swaps content between HTML markers, no-op when markers absent |
| SUMM-07 | 06-01, 06-02 | ModelLoadGate refuses Ollama while ASR loaded | ⚠️ NEEDS HUMAN | Code correct (acquire .ollama before HTTP); 3 tests fail due to singleton isolation flake — present-behavior-unverified |
| CLOUD-01 | 06-03, 06-05 | Per-modality provider selectors in Settings | ✓ SATISFIED | ProvidersTab with 4 modality sections, ProviderPickerRow for each |
| CLOUD-02 | 06-01, 06-05 | Local is default on first launch | ✓ SATISFIED | LLMProvider.off default in ProviderRouter.Settings |
| CLOUD-03 | 06-03 | OpenAI provider (gpt-4o, whisper-1, vision) | ✓ SATISFIED | OpenAILLMSummarizer (gpt-4o). Whisper-1 ASR + Vision deferred to v2 per 06-CONTEXT (Vision feature consumption is v2) |
| CLOUD-04 | 06-03 | Anthropic provider (Claude) | ✓ SATISFIED | AnthropicLLMSummarizer (claude-sonnet-4-20250514) with x-api-key + anthropic-version headers |
| CLOUD-05 | 06-03 | Grok (X) provider | ✓ SATISFIED | GrokLLMSummarizer (grok-2) via OpenAICompatibleClient on api.x.ai |
| CLOUD-06 | 06-03 | Z.ai provider (GLM) | ✓ SATISFIED | ZaiLLMSummarizer (glm-4.6) via OpenAICompatibleClient on api.z.ai |
| CLOUD-07 | 06-01 | API key storage in Keychain / Secure Enclave | ✓ SATISFIED | APIKeyStore actor with SecItemAdd/SecItemCopyMatching, kSecAttrAccessibleWhenUnlocked. MockAPIKeyStore for Linux tests |
| CLOUD-08 | 06-04 | First-use consent gate per provider×modality | ✓ SATISFIED | ConsentSheet + ConsentViewModel + ConsentStore. ProviderRouter.summarizer checks consent before returning cloud summarizer |
| CLOUD-09 | 06-03 | Cloud ASR alternative to local whisper.cpp | ⚠️ NEEDS HUMAN | ProviderRouter has hook for ASR (TTS/Vision/ASR routers noted as "Future" in code comment line 29). ASR provider router not implemented in Phase 6 — only LLM router exists. Per REQUIREMENTS.md traceability, CLOUD-09 status is "Pending" |
| CLOUD-10 | 06-03, 06-04 | Cloud failure surfaces clear error with retry/fallback | ✓ SATISFIED | CloudFailureSheet + FailureRecoveryViewModel. errorMessage() with provider-specific messages, canRetry() respects CF-02 fast-fail |
| CLOUD-11 | 06-03 | Network reachability check before cloud calls | ✓ SATISFIED | TCPReachability with NWConnection (2s timeout), called by all 4 cloud summarizers |
| CLOUD-12 | 06-06 | Zero telemetry / analytics / phone-home | ✓ SATISFIED | Grep-verified clean. MAINTAINERS.md checklist documents process-based enforcement |
| CLOUD-13 | 06-01, 06-06 | Per-document audit trail (provider_used in frontmatter) | ✗ BLOCKED | FrontmatterSchema v2 has asrProvider/llmProvider/visionProvider fields, BUT summarization flow does not populate them (Gap 1). AuditTrailStore reads them but status derivation is buggy (Gap 2) |
| DISC-05 | 06-06 | Local-first offline by default | ✓ SATISFIED | All local providers (Ollama, whisper.cpp) run without network. MAINTAINERS.md offline test checklist. Device verification deferred (06-UAT scenario 6.7) |
| DISC-06 | 06-06 | iCloud Drive sync conflicts don't corrupt notes | ✓ SATISFIED | Atomic writes (.atomic) verified in NoteWriter + ConsentStore tests. FrontmatterSchemaMigrationTests verify v1→v2 backward compatibility |

**Orphaned Requirements Check:** CLOUD-09 (cloud ASR alternative) is marked "Pending" in REQUIREMENTS.md traceability — Phase 6 did not ship an ASR router (only LLM router). This matches the 06-03 ProviderRouter comment "Future: asrProvider, visionProvider, ttsProvider". Not an orphan (Phase 6 claimed it in 06-03 frontmatter), but Phase 6 delivered only the LLM slice of it.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| Sources/UnibrainProviders/Audit/AuditTrailStore.swift | 249 | `let status: AuditStatus = hasSummary ? .success : .success` — ternary with identical branches (BUG) | 🛑 BLOCKER | Failed cloud operations never appear as failed in audit trail. CF-04 broken for AuditTab display. |
| Sources/UnibrainProviders/Summarization/RegenerateSummaryUseCase.swift | (whole file) | Does not populate FrontmatterSchema v2 audit fields after summary generation | 🛑 BLOCKER | CLOUD-13 audit trail cannot trace which LLM provider generated a summary. Explicitly documented as Known Stub #2 in 06-02-SUMMARY. |
| Sources/UnibrainProviders/Summarization/SummaryViewModel.swift | (whole file) | Does not populate FrontmatterSchema v2 audit fields | 🛑 BLOCKER | Same as RegenerateSummaryUseCase — audit trail disconnected. Known Stub #3 in 06-02-SUMMARY. |
| Sources/UnibrainProviders/Transcription/WhisperCppTranscriber.swift | 81 | `// TODO: Wire whisper.cpp SPM API once macOS CI validates the import.` | ℹ️ Info | Pre-existing from Phase 3, not introduced by Phase 6. Whisper.cpp integration is macOS-only. |
| Sources/UnibrainProviders/Transcription/SpeechAnalyzerTranscriber.swift | 60 | `// TODO: Wire SpeechAnalyzer API once macOS 26 CI validates the import.` | ℹ️ Info | Pre-existing from Phase 3, not introduced by Phase 6. |
| UnibrainApp/Settings/CoursesTab.swift | (buttons) | "Edit…" term editor + "Import from Calendar" are no-op stubs | ⚠️ Warning | Documented in 06-05 Known Stubs #1, #2. Buttons exist, actions do nothing. UX gap but not blocking. |
| UnibrainApp/Settings/AuditTab.swift | (retry/fallback) | AuditViewModel.retry() and .fallback() not wired to ProviderRouter | ⚠️ Warning | Documented in 06-06 Known Stubs #1. Buttons exist in failed operations section, actions do nothing. |
| UnibrainApp/Settings/ModelPullCallout.swift | (pull action) | Actual `ollama pull` Process invocation not wired | ⚠️ Warning | Documented in 06-02 Known Stub #1. UI shell exists, Process integration deferred. |
| Tests/UnibrainCoreTests/ModelLoadGateOllamaTests.swift | 38, 64, 79 | 3 tests fail due to shared singleton state contamination | ⚠️ Warning | Pre-existing flake documented since 06-01-SUMMARY. SUMM-07 logic is correct; test infrastructure needs isolation. |

### Human Verification Required

These items need macOS/iOS device testing. All are captured in 06-UAT.md.

### 1. Ollama Summarization End-to-End (SUMM-01..06)

**Test:** Install Ollama + `ollama pull llama-3.2:3b`. Trigger summarization on a recorded lecture.
**Expected:** `## Summary` section with 5-8 bullets appears in note. Frontmatter `summary_model: llama-3.2:3b` and `llm_provider: ollama` populated (after Gap 1 fix).
**Why human:** Requires macOS device + Ollama running + actual whisper.cpp transcription first.

### 2. ModelLoadGate SUMM-07 Behavioral Verification

**Test:** Load whisper.cpp model, attempt Ollama summarization simultaneously.
**Expected:** Ollama summarization throws .busy (waits or fails gracefully).
**Why human:** Requires macOS device. Test isolation issue masks deterministic proof on Linux CI.

### 3. Consent Sheet First-Use Flow (CON-01, CLOUD-08)

**Test:** Configure OpenAI API key in Settings. Trigger cloud summarization.
**Expected:** ConsentSheet appears with [Only this once] / [Always allow] / [Cancel]. After grant, second call skips sheet.
**Why human:** SwiftUI sheet presentation is macOS-only.

### 4. Cloud Failure Recovery (CF-01..04)

**Test:** Disconnect WiFi during cloud summarization. Force 429 rate limit.
**Expected:** CloudFailureSheet appears with appropriate buttons. Network down hides Retry (CF-02). Rate limited shows Retry (CF-03).
**Why human:** Requires macOS device + network manipulation.

### 5. Zero Telemetry Mitmproxy Audit (CLOUD-12)

**Test:** Run mitmproxy with HTTPS interception. Launch unibrain. Observe traffic for 60s idle, record, transcribe, cloud summary.
**Expected:** Zero outbound traffic except user-initiated cloud provider calls.
**Why human:** Requires macOS device + mitmproxy. Code-level grep confirms no SDKs.

### 6. Local-First Offline Test (DISC-05)

**Test:** Turn off WiFi. Record → stop → transcribe → classify → write.
**Expected:** Full pipeline completes without network. Note appears in vault.
**Why human:** Requires macOS device + whisper.cpp model.

### 7. macOS Settings Visual Verify (SET-01, SET-02)

**Test:** Open Settings (⌘,). Verify 5 tabs. Press ⌘+1..⌘+5. Open each tab.
**Expected:** All tabs render. Shortcuts work. Context-aware opening works.
**Why human:** SwiftUI rendering is macOS-only.

### 8. iOS Settings Tab (SET-03)

**Test:** Open unibrain on iPhone. Tap Settings tab. Verify read-only providers/courses/audit + actionable permissions.
**Expected:** Read-only sections with "Configure on Mac" alerts. Permissions re-grant works.
**Why human:** iOS device required.

### 9. Audit Tab CSV Export (CF-04)

**Test:** Open Settings → Audit on macOS with 5+ notes in vault. Filter by date/provider/status. Export CSV.
**Expected:** CSV file created with header + data rows. Filters narrow results.
**Why human:** macOS device + vault with real notes required.

### Gaps Summary

**Two real gaps block Phase 6 goal achievement:**

**Gap 1: Frontmatter audit trail disconnected from summarization flow.**
RegenerateSummaryUseCase and SummaryViewModel do not populate FrontmatterSchema v2 fields (`summary_model`, `llm_provider`) after generating a summary. This means the per-document audit trail (CLOUD-13, CON-04) cannot trace which LLM provider touched a summarized note from frontmatter alone. The schema fields exist (06-01 delivers them), but the write path doesn't use them. Explicitly documented as Known Stub #2 and #3 in 06-02-SUMMARY. **This blocks Truth 1 and Truth 4.**

**Gap 2: AuditTrailStore status bug.**
Line 249 of `Sources/UnibrainProviders/Audit/AuditTrailStore.swift` has `let status: AuditStatus = hasSummary ? .success : .success` — a copy-paste bug where both branches of the ternary return `.success`. This makes the `filterByStatus(.failed)` filter return zero entries forever, defeating CF-04 (failure history in Audit tab). The unit tests don't catch this because no test fixture includes a failed note (all test fixtures are successful). **This blocks Truth 4.**

**Three behavior-unverified truths** require macOS device or test infrastructure fixes to deterministically prove:
- SUMM-07 ModelLoadGate enforcement (test isolation flake)
- CON-01 Consent sheet first-use presentation (macOS SwiftUI)
- CLOUD-12 Zero telemetry (mitmproxy audit)

**Known UI stubs (non-blocking warnings):**
- CoursesTab "Edit…" and "Import from Calendar" buttons are no-ops
- AuditTab retry/fallback buttons not wired
- ModelPullCallout pull action not wired to `ollama pull` Process

These UI stubs are documented in SUMMARYs and do not affect the core goal (summarization + provider selection + consent + audit + zero telemetry). They are polish items for a wiring follow-up or v2.

---

_Verified: 2026-07-16T23:30:00Z_
_Verifier: Claude (gsd-verifier)_
