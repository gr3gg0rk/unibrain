# Phase 6: Gated Summarization + Cloud Providers + MVP Polish - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 completes the MVP by layering gated summarization, the four cloud providers, the consent/audit/settings infrastructure, and zero-telemetry polish on top of the Phase 1-5 macOS+iOS local-first capture loop.

This phase delivers:
1. **Ollama local summarization (SUMM-01..07)** — gated off by default; opt-in via Settings; `llama-3.2:3b` with `keep_alive: 0`; 5-8 bullet `## Summary` section appended to the note; "Regenerate Summary" replaces only the marked section; `ModelLoadGate` refuses to start Ollama while ASR is loaded.
2. **Four cloud providers (CLOUD-01..13)** — OpenAI / Anthropic / Grok (X) / Z.ai selectable per modality (LLM / ASR / Vision / TTS) in Settings; Local is always default; adding a provider requires API key in macOS Keychain / iOS Secure Enclave; per-modality consent gate the first time each provider×modality pair fires; cloud failures prompt explicit fallback; `provider_used` audit trail in frontmatter.
3. **Settings UI** — dedicated macOS `Settings` window with five tabs (General / Providers / Courses / Permissions / Audit); iOS Settings tab is read-only. Phase 4 Manage Courses sheet + Phase 5 Permissions sheet fold into Settings tabs now.
4. **MVP polish (DISC-05, DISC-06, CLOUD-12)** — local-first path works fully offline by default; zero telemetry / zero analytics / zero phone-home verified; iCloud Drive sync conflicts do not corrupt notes (Phase 2 atomic writes + `schema_version` field).

**Phase 5 dependency:** Phase 6 assumes Phase 5's iOS TabView shell (with placeholder Settings tab), `.unibrain/courses.json`, onboarding Permissions sheet, iCloud-handoff queue, and the `_inbox/` pipeline all exist.

**Phase 1 dependency:** Phase 6 wires concrete conformances to the four Phase 1 provider protocols (`LLMSummarizer`, `AudioTranscriber`, `VisionDescriber`, `AudioSynthesizer`) and reuses `ProviderError`, `ModelLoadGate`, and `HeavyModelKind` unchanged (D-12 cloud bypasses the gate; D-15..17 protocol shapes are fixed).

</domain>

<decisions>
## Implementation Decisions

### Settings UI Architecture (SET-01..04)

- **SET-01: Dedicated macOS Settings window.** SwiftUI `Settings` scene opens via popover "Settings…" button + standard ⌘, shortcut + menu bar item. Separate from menu-bar popover (popover stays ~280pt, recording-focused). Apple's expected macOS pattern. iOS Settings tab is a separate navigation stack inside Phase 5's existing `TabView`.
- **SET-02: By-function tab layout.** Tabs: `General | Providers | Courses | Permissions | Audit`. Providers tab holds all four modality selectors (LLM / ASR / Vision / TTS) as inline pickers with API-key entry alongside each. Matches macOS System Settings pattern. Angelica sees "what am I configuring?" not "which modality is this?".
- **SET-03: iOS Settings tab is read-only.** iOS Settings tab contains actionable Permissions (re-grant flow) + read-only views of Providers list, Audit trail, Courses. Provider configuration (API key entry, provider selection, consent) is macOS-first. iPhone inherits provider config + consent state via `.unibrain/` iCloud sync. Angelica can't add an API key from iPhone (accepted tradeoff — matches Phase 5 ONB-01 macOS-first onboarding pattern).
- **SET-04: Fold existing sheets into Settings tabs now.** Phase 4 M-04 Manage Courses sheet → `Courses` tab (existing SwiftUI views move into the Settings window). Phase 5 ONB-04 Permissions sheet → `Permissions` tab. The standalone popover sheet buttons are removed; popover gets a single "Settings…" entry that opens the window to the most-relevant tab (context-aware: post-recording failure opens Audit; permission warning opens Permissions).

### Consent + Audit Mechanics (CON-01..04)

- **CON-01: First-use consent dialog = sheet on menu-bar popover.** When a cloud call is about to fire and no consent record exists for `{provider}×{modality}`, a sheet slides down from the popover window: *"Allow {Provider} to {modality-verb} this recording?"* with three buttons: `[Only this once]` / `[Always allow {Provider} for {modality}]` / `[Cancel]`. Blocks the cloud call until Angelica picks. Cancel returns to the previous pipeline state without losing the recording. Matches Phase 3-5 macOS menu-bar surface convention.
- **CON-02: "Always allow" scope = per-provider-per-modality.** Matches CLOUD-08 spec verbatim ("Always allow OpenAI for ASR"). Each `{provider}×{modality}` pair gets independent consent. Angelica consents to `openai×asr`, then later consents to `openai×llm` separately. Strictest scope; preserves the per-modality audit trail integrity.
- **CON-03: Consent state persisted in `.unibrain/consent.json` inside the vault.** Sits alongside Phase 4 M-01 `courses.json`. iCloud Drive syncs the file between MacBook and iPhone — one consent decision applies to both devices. Format: `{provider: {modality: {always_allow: bool, first_consented_at: ISO8601}}}`. JSON is human-debuggable. Consent revocation UX lives in Settings → Audit tab (per-provider-per-modality rows with revoke toggle).
- **CON-04: Audit trail shape = per-modality frontmatter fields.** FrontmatterSchema extends with three optional `String?` fields: `asr_provider`, `llm_provider`, `vision_provider` (each null when the modality wasn't invoked for that note). `schema_version` bumps `1 → 2`. Plays nicely with existing `summary_model` (specific model name like `llama-3.2:3b`) — the provider field records the company (`ollama`, `openai`, `anthropic`, `grok`, `zai`, `whisper-cpp`), the model field records the version. Phase 2's frontmatter schema test gets extended to cover the new fields. Existing Phase 1-5 notes (schema_version 1) remain readable (additive change; missing fields default to nil).

### Cloud Failure Recovery (CF-01..04)

- **CF-01: Prompted retry + explicit fallback.** On cloud provider error after provider-level retries (CF-03): a sheet appears on the menu-bar popover with `[Retry {Provider}]` / `[Fall back to local]` / `[Cancel recording]`. The error message is short and human-readable ("OpenAI rate-limited — too many requests. Try again in a minute, or fall back to whisper.cpp."). Recording audio is preserved regardless of choice. Angelica explicitly chooses fallback — no silent cloud-to-local swap.
- **CF-02: Network reachability check before every cloud call.** Quick TCP connect to `{provider-host}:443` with 2s timeout. If unreachable: skip provider-level retries (CF-03), go straight to CF-01 fallback sheet with message *"{Provider} unreachable — network down. [Fall back to local] [Cancel]"*. Avoids the 30-60s `URLRequest` timeout UX. Overhead is negligible at Angelica's call volume.
- **CF-03: Retry layer composition = provider inner, queue outer.** Provider client (CLOUD-10) retries internally: 3 attempts with exponential backoff (2s / 8s / 30s). If all 3 fail, throws `ProviderError` to the orchestrator. Queue (Phase 5 TRIG-04) catches at the pipeline boundary and retries the whole pipeline (30s / 2min / 10min) for iCloud-handoff `_inbox/` files. Net worst-case for one file: ~30 min (3 queue × 3 provider attempts). Live-recording files (not from queue) don't get queue-level retry — they surface CF-01 immediately after provider retries exhaust.
- **CF-04: Failure surfaces in two places.** (a) Menu-bar popover banner for active recording state with inline action buttons (matches Phase 3 P-11 transcribing-state pattern). (b) Audit tab in Settings shows per-note failure history with error details and timestamps (queryable by date, provider, modality, course). No macOS notification (notifications can be dismissed/missed); no separate dead-letter file for cloud failures (existing Phase 5 `_inbox/_failed/` policy applies only to queue-level exhaustion, not transient cloud errors).

### Ollama Setup UX (OLL-01..04)

- **OLL-01: Detect-and-link to ollama.com.** When Angelica toggles "Enable Summarization" (or picks Ollama in Providers tab) and `localhost:11434` health check fails, the Settings UI shows a callout: *"Ollama not detected. [Download Ollama] (opens ollama.com in default browser) [Re-check] [Cancel]"*. No in-app installer, no auto-launch of `/Applications/Ollama.app`. Angelica installs and launches Ollama herself, then clicks Re-check. Respects her control of the machine; avoids Gatekeeper / notarization complexity.
- **OLL-02: Discovery via Settings toggle.** The "Enable Summarization" toggle lives in Settings → General tab as a three-way picker: `Off | Local (Ollama) | Cloud`. Default is `Off` (SUMM-02). When Angelica flips to "Local (Ollama)" and health check fails, she sees the OLL-01 callout. No post-onboarding tip banner; no setup wizard; she finds the feature when she's curious. Matches SUMM-02 "off by default" intent.
- **OLL-03: Explicit "Pull model" button in Settings.** When Angelica has Ollama running AND `ollama list` doesn't include `llama-3.2:3b`, Settings shows: *"Model not pulled yet — [Pull llama-3.2:3b (~2GB)]"*. Button fires `ollama pull llama-3.2:3b` via `Process` shell-out, streaming progress (parsed from Ollama's stdout) into a progress bar inside Settings. After pull completes: health check passes, summarization is ready. Angelica sees the 2GB commitment before it starts (no silent background download — important for tethered-hotspot scenarios).
- **OLL-04: Summary section format + Regenerate (SUMM-04..06).** Summary appends AFTER the transcript at the bottom of the note. Heading: `## Summary` (H2). Body: 5-8 bullet points (`- concept or definition`). Frontmatter `summary_model: llama-3.2:3b` + `llm_provider: ollama` populated. The `## Summary` section is wrapped in HTML comment markers `<!-- unibrain:summary-start -->` / `<!-- unibrain:summary-end -->` so Regenerate replaces only the content between markers — preserves any edits Angelica made to the transcript above. "Regenerate Summary" action lives in Settings → Audit tab (per-note row with [Regenerate] button). SUMM-04 prompt focuses on "concepts and definitions a student needs to know" — locked prompt template in `UnibrainCore/Prompts/summary-default.md` (planner refines exact wording).

### Claude's Discretion

- **ProviderError extension for cloud-specific cases** — existing `.networkFailure`, `.rateLimited(retryAfter:)`, `.modelError(String)`, `.invalidResponse`, `.cancelled`, `.underlying` cover most cases. Planner decides whether to add `.apiKeyMissing`, `.providerUnreachable` (distinct from network failure), `.consentDenied` (CF-01 Cancel) cases. Swift 6 typed throws pattern (`throws(CloudProviderError)`) optional — planner picks.
- **TCP reachability check implementation** — `NWConnection` from `Network` framework is the modern path; raw `socket()` is the fallback. Planner picks; 2s timeout is fixed.
- **`Process` shell-out to `ollama pull`** — exact Process setup, stderr parsing for progress percentage, cancellation handling. Planner verifies `ollama pull` output format and whether to stream via `Pipe` or `FileHandle`.
- **Audit tab query UI** — exact filters (date range, provider, modality, course, success/failure), table columns, sort order. Planner picks; SQLite is NOT in MVP (v2 EMBD-01 territory) — a simple in-memory scan of frontmatter across the vault is fine for Angelica's scale.
- **`.unibrain/consent.json` schema versioning** — add `schema_version: 1` field for forward-compat. Planner picks field nesting shape.
- **General tab contents** — beyond the Summarization toggle, what else lives in General? Likely: vault path display + change button, current term display + change button (links to Courses tab), app version, link to docs. Planner refines.
- **`schema_version: 2` migration logic** — Phase 1-5 notes have `schema_version: 1` and missing `*_provider` fields. Decoder treats missing fields as `nil` (additive change). Encoder always writes current schema_version. No on-disk migration needed.
- **Cloud client HTTP stack** — `URLSession` with ATS on (no exceptions). JSON request/response via `Codable`. Planner picks whether to share a single `URLSession.Configuration` across providers or instantiate per-provider.
- **API key entry UI** — `SecureField` for entry, masked display in Settings list. Planner verifies whether iCloud Keychain sync (syncs across devices via `kSecAttrSynchronizable`) is desirable or whether keys should stay device-local. Default: device-local (more conservative; matches PROJECT.md "API keys stored in macOS Keychain / iOS Secure Enclave" without specifying sync).
- **`{provider}×{modality}` consent record key shape** — string concatenation (`"openai.asr"`) vs nested dict. Planner picks.
- **Regenerate Summary discovery outside Settings** — long-press context menu in Obsidian? Phase 6 ships Settings-only entry; future phases can extend. Out of scope for Phase 6.
- **Prompt template file location** — `UnibrainCore/Prompts/summary-default.md` is the recommended path. Planner can pick alternative (e.g., inline string constant in `LLMSummarizer` conformance).
- **Cloud client target placement** — cloud provider conformances ship in `UnibrainProviders` (alongside Phase 3 `SpeechAnalyzerTranscriber` / `WhisperCppTranscriber` and Phase 4 EventKit adapter). They use `URLSession` only (Foundation) — could live in `UnibrainCore` behind `#if canImport(FoundationNetworking)`. Planner picks; cloud clients should be Linux-buildable so unit tests with mock `URLSession` run on WSL2 CI.
- **Zero-telemetry verification approach (CLOUD-12)** — no programmatic enforcement in v1. Approach: (a) code review check that no analytics SDKs are added to `Package.swift`, (b) manual mitmproxy/Proxyman audit before each release, (c) `MAINTAINERS.md` checklist item. Planner documents in a verification section of the plan; not a runtime check.

### Folded Todos

None — no pending todos in `.planning/STATE.md` §"Pending Todos" matched Phase 6 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Planning (in this repo)
- `.planning/PROJECT.md` — project definition, constraints, Key Decisions table. The "Local-default + cloud-opt-in provider layer" Key Decision IS Phase 6 — this is the phase that makes it user-configurable. Privacy mandate ("zero telemetry, zero analytics, zero phone-home") shapes CLOUD-12 enforcement approach. MacBook Neo A-series / macOS 26 / iOS 17 / 8GB / Keychain constraints shape every Phase 6 decision.
- `.planning/REQUIREMENTS.md` §"Summarize" — Phase 6 requirements: SUMM-01 (Ollama HTTP API integration with health-check), SUMM-02 (off by default — OLL-02 implements), SUMM-03 (`llama-3.2:3b` + `keep_alive: 0`), SUMM-04 (5-8 bullet key points — OLL-04 implements), SUMM-05 (under `## Summary` heading in same note — OLL-04 implements), SUMM-06 (Regenerate replaces only Summary section — OLL-04 implements), SUMM-07 (refuses to run while ASR loaded — ModelLoadGate enforces).
- `.planning/REQUIREMENTS.md` §"Cloud Providers" — CLOUD-01 (per-modality Settings selectors — SET-02 implements), CLOUD-02 (Local default on first launch), CLOUD-03..06 (OpenAI / Anthropic / Grok / Z.ai integrations), CLOUD-07 (Keychain / Secure Enclave), CLOUD-08 (first-use consent gate — CON-01 implements), CLOUD-09 (cloud ASR is ALTERNATIVE to local — only one runs per recording), CLOUD-10 (cloud failure surfaces clear error — CF-01 implements), CLOUD-11 (network reachability check — CF-02 implements), CLOUD-12 (zero telemetry — Claude's discretion), CLOUD-13 (per-document audit trail — CON-04 implements).
- `.planning/REQUIREMENTS.md` §"Discipline" — DISC-05 (local-first core path works offline — CF-01 honors), DISC-06 (iCloud Drive sync conflicts — atomic writes + schema_version field).
- `.planning/ROADMAP.md` §"Phase 6: Gated Summarization + Cloud Providers + MVP Polish" — phase goal, mode (mvp), depends-on (Phase 5), requirements, five success criteria.

### Phase 1 CONTEXT (decisions carried forward)
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-05 (macOS 26 / iOS 17 deployment targets), D-07 (three SPM targets: `UnibrainCore` Foundation-only, `UnibrainProviders` macOS/iOS-only, `UnibrainApp` Xcode app), D-08 (test target split), D-11..14 (`ModelLoadGate` acquire/release lease, deny-on-conflict), D-12 (cloud providers bypass the gate), D-15..17 (four standalone provider protocols, `ProviderError`, single-shot async/throws).

### Phase 2 CONTEXT (contracts Phase 6 wires)
- `.planning/phases/02-pure-pipeline-logic/02-CONTEXT.md` — N-01 (Obsidian wiki-link audio reference), N-03/N-04 (segments-in contract + 3-second paragraph break), A-04 (`NoteWriterError` enum — Phase 6 may extend with cloud-failure cases if `ProviderError` doesn't suffice), O-01..05 (8-state `PipelineState`, `PipelineOrchestrator` actor, `PipelineInputs`).

### Phase 3 CONTEXT (macOS surface that hosts Phase 6 additions)
- `.planning/phases/03-macos-capture-transcribe/03-CONTEXT.md` — P-05 (`TranscriberRouter` facade pattern — Phase 6 extends to LLM/Vision/TTS routers), P-08 (menu-bar popover is primary recording surface — Phase 6 consent sheet attaches here per CON-01), P-09 (popover ~280pt wide — Phase 6 Settings opens a separate window per SET-01), P-11 (transcribing-state popover pattern — Phase 6 cloud-failure banner reuses per CF-04), P-13 (`~/Documents/Unibrain/` default vault root).

### Phase 4 CONTEXT (Settings tabs source)
- `.planning/phases/04-course-classification-smart-routing/04-CONTEXT.md` — M-01 (`.unibrain/courses.json` inside vault — Phase 6's `.unibrain/consent.json` follows same pattern), M-04 (Manage Courses sheet — Phase 6 folds into Courses tab per SET-04), CT-01 (currentTerm schema), P-05 (verify `.full Access` explicitly).

### Phase 5 CONTEXT (iOS Settings + queue retry)
- `.planning/phases/05-ios-capture-icloud-handoff-onboarding/05-CONTEXT.md` — IOS-01 (iOS TabView with placeholder Settings tab — Phase 6 fills it read-only per SET-03), ONB-01 (macOS-first onboarding pattern — Phase 6 inherits for cloud config), ONB-04 (Permissions sheet — Phase 6 folds into Permissions tab per SET-04), TRIG-04 (queue-level retry — Phase 6's CF-03 composes provider-inner + queue-outer).

### Existing Code (the assets Phase 6 extends)
- `Sources/UnibrainCore/Protocols/LLMSummarizer.swift` — Phase 6 ships concrete `OllamaLLMSummarizer`, `OpenAILLMSummarizer`, `AnthropicLLMSummarizer`, `GrokLLMSummarizer`, `ZaiLLMSummarizer` conformances. Each defines its own `Request`/`Response` associated types.
- `Sources/UnibrainCore/Protocols/AudioTranscriber.swift` — Phase 6 ships cloud ASR conformances (`OpenAITranscriber` for Whisper-1 API) that the existing Phase 3 `TranscriberRouter` (P-05) wraps.
- `Sources/UnibrainCore/Protocols/VisionDescriber.swift` — Phase 6 ships `OpenAIVisionDescriber`, `AnthropicVisionDescriber` conformances (CLOUD-03, CLOUD-04).
- `Sources/UnibrainCore/Protocols/AudioSynthesizer.swift` — Phase 6 ships cloud TTS conformances (`OpenAITranscriber`-style for `tts-1`). v1 minimal scope per CLOUD-01 (TTS tab present, providers selectable, but TTS feature itself is a stub — TTS playback is v2).
- `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` — Phase 6 extends with `asrProvider`, `llmProvider`, `visionProvider` optional String fields (CON-04). `schemaVersion` bumps 1 → 2. CodingKeys map camelCase to snake_case (`asr_provider`, `llm_provider`, `vision_provider`).
- `Sources/UnibrainCore/Errors/ProviderError.swift` — existing `.networkFailure`, `.rateLimited(retryAfter:)`, `.modelError`, `.invalidResponse`, `.cancelled`, `.underlying` cases cover cloud failures. Planner may extend (Claude's discretion).
- `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` — unchanged in Phase 6. Ollama path calls `acquire(.llm)` before load; `keep_alive: 0` ensures release on completion. Cloud providers bypass the gate (D-12).
- `Sources/UnibrainCore/ModelLoadGate/HeavyModelKind.swift` — `.asr` + `.llm` cases already cover Ollama. No `.vision` needed in Phase 6 (Phase 2 vision ingestion is v2).
- `Sources/UnibrainProviders/ProtocolDefaults/ProviderDefaults.swift` — Phase 6 ships cloud conformances here (or in `UnibrainCore` if Linux-buildable per Claude's discretion).
- `UnibrainApp/UnibrainApp.swift` — Phase 1 app shell with `MenuBarExtra`. Phase 6 adds `Settings` scene (macOS) + fills iOS `TabView` Settings tab content.
- `Package.swift` — Phase 6 likely adds no new SPM dependencies (cloud clients use built-in `URLSession`; Keychain via `Security` framework). Planner verifies no `KeychainAccess`-style wrapper is worth adding for ergonomics.

### External Documentation (consult during planning)
- [Ollama HTTP API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md) — `POST /api/generate`, `POST /api/chat`, `keep_alive` parameter (SUMM-01, SUMM-03).
- [Ollama Model Library](https://ollama.com/library) — `llama-3.2:3b` model details.
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference) — Chat Completions (`gpt-4o` / `gpt-4o-mini`), Whisper (`whisper-1`), Vision, TTS endpoints (CLOUD-03).
- [Anthropic API Reference](https://docs.anthropic.com/en/api) — Claude messages API, current Sonnet/Opus model IDs, vision support (CLOUD-04).
- [X AI (Grok) API Documentation](https://docs.x.ai) — Grok chat completions API (CLOUD-05).
- [Z.ai API Documentation](https://docs.z.ai) — GLM family API (CLOUD-06).
- [SwiftUI Settings scene (Apple Developer)](https://developer.apple.com/documentation/swiftui/settings) — macOS Settings window scene (SET-01).
- [Keychain Services (Apple Developer)](https://developer.apple.com/documentation/security/keychain_services) — API key storage on macOS (CLOUD-07).
- [Secure Enclave on iOS (Apple Developer)](https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/storing_keys_in_the_secure_enclave) — API key storage on iOS (CLOUD-07). NOTE: Secure Enclave has key-type restrictions (ECDSA, P-256); generic API-key strings typically go to iOS Keychain instead. Planner verifies which iOS storage is appropriate for arbitrary-length API key strings.
- [NWConnection (Apple Developer)](https://developer.apple.com/documentation/network/nwconnection) — TCP reachability check (CF-02).
- [URL.startDownloadingUbiquitousItem() (Apple Developer)](https://developer.apple.com/documentation/foundation/url/startdownloadingubiquitousitem()) — referenced via Phase 5 IC-04 for iCloud sync of `.unibrain/consent.json`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Four Phase 1 provider protocols** (`Sources/UnibrainCore/Protocols/*.swift`) — Phase 6 ships concrete conformances for each. The `associatedtype Request`/`Response` pattern lets each provider define its own I/O without protocol-level generics bloat.
- **`ProviderError`** (`Sources/UnibrainCore/Errors/ProviderError.swift`) — already cloud-ready: `.networkFailure(URLRequest, URLError)`, `.rateLimited(retryAfter:)`, `.modelError(String)`, `.invalidResponse`, `.cancelled`, `.underlying`. Cloud clients throw these directly. Planner may extend for cloud-specific cases.
- **`ModelLoadGate`** (`Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift`) — only governs LOCAL heavy models (`.asr` / `.llm`). Cloud providers bypass the gate (D-12). Ollama path: `acquire(.llm)` → `keep_alive: 0` → release. `deny-on-conflict` enforces SUMM-07.
- **Phase 3 `TranscriberRouter`** — wraps multiple ASR engines behind `any AudioTranscriber`. Phase 6 extends this pattern to LLM (`LLMRouter`), Vision (`VisionRouter`), TTS (`AudioSynthRouter`). Each router's selected backend reads from Settings (per-modality).
- **Phase 4 `.unibrain/courses.json`** — Phase 6's `.unibrain/consent.json` follows the same pattern (vault-internal, iCloud-synced, JSON, human-editable, `schema_version: 1`).
- **Phase 4 Manage Courses sheet** — SwiftUI views relocate to Settings → Courses tab (SET-04).
- **Phase 5 ONB-04 Permissions sheet** — SwiftUI views relocate to Settings → Permissions tab (SET-04).
- **Phase 5 iOS TabView Settings tab placeholder** — Phase 6 fills with read-only provider/audit/courses + actionable permissions (SET-03).

### Established Patterns
- **Swift 6 strict concurrency** (`actor`, `Sendable`, `async/await`) — Phase 6 cloud clients, Keychain wrapper, Ollama client, and `.unibrain/consent.json` reader/writer all use these idioms.
- **Protocol-abstraction layer** — cloud provider clients conform to Phase 1 protocols. Each cloud call is a single-shot `async throws` function (D-17). Streaming responses (OpenAI streaming, Anthropic SSE) are NOT in v1 (D-17 single-shot only) — planner picks whether to use non-streaming endpoints.
- **`#if os(macOS)` / `#if os(iOS)` guards** — Settings window is macOS-only (`Settings` scene is unavailable on iOS); iOS uses `TabView` Settings tab. Keychain APIs differ slightly between platforms — planner uses `Security` framework directly or a thin wrapper.
- **`if #available(macOS 26, *)`** — `Settings` scene is macOS 13+; no availability check needed at Phase 1 D-05 deployment targets.
- **swift-testing framework** — `@Test`, `#expect`. Phase 6's tests in `UnibrainProvidersTests` cover cloud clients (mock `URLSession`), Keychain wrapper (mock keychain on Linux), `FrontmatterSchema` round-trip with new `*_provider` fields, Ollama client (mock HTTP server).
- **FrontmatterSchema round-trip test** — Phase 1 verified Yams encode/decode with snake_case CodingKeys. Phase 6 extends the test for `asr_provider` / `llm_provider` / `vision_provider` + `schema_version: 2`.
- **macOS CI** — `macos-15` runner (Xcode 16.x). Cloud-client unit tests with mock `URLSession` run on Linux CI too (FoundationNetworking). Keychain tests are macOS-only.

### Integration Points
- **`UnibrainApp`** is the consumer-facing entry point. Phase 6 adds: macOS `Settings` scene with five tabs, iOS Settings tab content, consent sheet on menu-bar popover (CON-01), cloud-failure banner on menu-bar popover (CF-04).
- **`PipelineOrchestrator.run(inputs:)`** — Phase 6's per-modality routers (LLM/Vision/TTS) inject into the orchestrator at the right pipeline stages. The orchestrator doesn't know whether a cloud or local backend ran (CON-04 audit fields are populated by the routers, not the orchestrator).
- **`{vault}/.unibrain/consent.json`** — new file. Read before every cloud call (cache in memory for the session; re-read on `NSMetadataQuery` iCloud change notification). Written on every consent grant / revocation.
- **`{vault}/.unibrain/courses.json`** — Phase 4 file unchanged in Phase 6; Settings → Courses tab reads/writes via existing Phase 4 logic.
- **`Sources/UnibrainCore/Prompts/summary-default.md`** (new) — the locked SUMM-04 prompt template ("5-8 bullets focused on concepts and definitions a student needs to know"). Planner refines exact wording.
- **`.github/workflows/ci.yml`** — Phase 6 extends both Linux (`swift test`) and macOS jobs with: cloud-client unit tests (mock URLSession), Keychain tests (macOS-only), FrontmatterSchema v2 round-trip test, Ollama client tests (mock HTTP).
- **`Info.plist` (iOS)** — Phase 6 may need `NSAppTransportSecurity` adjustments if any provider requires non-HTTPS (none expected — all four providers use HTTPS). Planner verifies.
- **Entitlements (macOS)** — Keychain access requires `com.apple.security.keychain-access-groups` or default keychain. Sandboxed app uses its own keychain group by default. Planner verifies.

</code_context>

<specifics>
## Specific Ideas

- **The schema_version 1 → 2 bump (CON-04) is the most consequential Phase 6 architectural change.** Phase 1-5 notes have `schema_version: 1` and no `*_provider` fields. The decoder treats missing fields as `nil` (additive, backward-compatible). The encoder always writes `schema_version: 2`. NO on-disk migration is needed — but the planner MUST verify the Yams decoder handles the absence gracefully and that FrontmatterSchema round-trip tests cover both schemas.
- **Per-modality routers extend Phase 3 P-05's `TranscriberRouter` pattern.** Each router (`LLMRouter`, `VisionRouter`, `AudioSynthRouter`) reads its selected backend from Settings at call time and dispatches. Each router itself conforms to its Phase 1 protocol (`any LLMSummarizer`). The orchestrator stays router-agnostic. CLOUD-09 ("only one ASR backend runs per recording") is enforced by the `TranscriberRouter` reading Settings at recording-start, not mid-recording.
- **Settings tab fold (SET-04) is a deliberate scope consolidation.** Phase 4's Manage Courses sheet and Phase 5's Permissions sheet are ~50-100 lines each of SwiftUI. Moving them into Settings tabs now (vs. leaving standalone) is more code churn in Phase 6 but produces a single coherent Settings surface — fewer entry points for Angelica to learn.
- **`.unibrain/consent.json` lives inside the vault (CON-03) so iCloud sync keeps consent state consistent across MacBook and iPhone.** This is the same reasoning as Phase 4 M-01's `courses.json`. Angelica consents to `openai×asr` on her MacBook; her iPhone respects the same consent without re-prompting. (Note: iPhone is read-only for cloud config per SET-03, so iPhone-initiated cloud calls are unlikely — but if Phase 6 polish or future phases add iPhone cloud calls, the consent state is already synced.)
- **TCP reachability check (CF-02) is a deliberate UX optimization.** Apple's `URLRequest` default timeout is 60s. For a cloud failure mid-lecture, that's unacceptable. The 2s TCP pre-check trades negligible overhead for fast-failure UX. The check uses `NWConnection` (Network framework) — modern, Swift-friendly.
- **Detect-and-link (OLL-01) over bundled installer is a deliberate scope minimization.** Bundling the Ollama installer would require: admin elevation, Gatekeeper handling, notarization constraints, signature verification, ~500MB+ app size increase. Detect-and-link is one button + one URL — Angelica installs Ollama herself from the official site. The tradeoff: she leaves the app to install. Accepted for MVP.
- **Explicit "Pull model" button (OLL-03) over silent background download** is a deliberate bandwidth-respect decision. A 2GB silent download on a tethered hotspot would be catastrophic. The button surfaces the size before it starts. Angelica explicitly consents to the bandwidth commitment.
- **HTML comment markers for Regenerate (OLL-04)** is the simplest reliable approach. Wrapping `## Summary` in `<!-- unibrain:summary-start -->` / `<!-- unibrain:summary-end -->` lets Regenerate replace only the marked section via string replacement — no Markdown AST parsing needed. Obsidian renders HTML comments as invisible; they don't pollute the reading view. The markers are versioned (can evolve to `<!-- unibrain:summary-start v=1 -->` if format changes).
- **Provider-inner + queue-outer retry composition (CF-03) gives maximum recovery with clean separation.** Provider client handles transient API errors (429, 5xx, momentary network blips). Queue handles pipeline-level errors (filesystem, iCloud, SpeechAnalyzer). The two layers don't know about each other — they compose via throw/catch.
- **iOS Settings read-only (SET-03) matches Phase 5 ONB-01 macOS-first setup.** Angelica configures cloud providers, consents, pulls the Ollama model, etc. on her MacBook. Her iPhone inherits state via iCloud Drive sync. If she ever needs to tweak from iPhone, she can use Settings → Permissions (re-grant mic/calendar) — but cloud config is MacBook-only. Accepted tradeoff; reduces Phase 6 iOS surface area significantly.
- **Zero-telemetry is verified by process, not by code (CLOUD-12).** No programmatic enforcement ships in v1. The verification approach (code review of `Package.swift` + mitmproxy audit + `MAINTAINERS.md` checklist) is documented for the planner. Phase 6 introduces zero analytics SDKs by convention. If telemetry ever becomes a requirement in a future phase, it would be a deliberate scope change with explicit user consent — not silent addition.
- **Summary at bottom of note (OLL-04) preserves natural chronology.** Transcript (raw data) first; summary (conclusion) last. Matches Obsidian's typical reading pattern: scroll top-to-bottom, encounter the raw transcript, end with the synthesized summary. Frontmatter already records `summary_model` and `llm_provider` for searchability — top-of-note visibility isn't needed.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The following items were considered but explicitly belong in other phases or versions:

- **Local embeddings index / semantic search** → v2 (EMBD-01..04 per REQUIREMENTS.md). Phase 6's audit trail is exact-match frontmatter scan only.
- **Live Activity / Dynamic Island recording indicator** → Phase 5 deferred to "Phase 6 polish"; in Phase 6 discussion this was not raised. Stays deferred — Phase 5 IOS-02 ships Now Playing + remote commands; Live Activity is v2 polish.
- **Streaming LLM responses (OpenAI streaming, Anthropic SSE)** → v2 per Phase 1 D-17 (single-shot only in v1). Phase 6 uses non-streaming endpoints.
- **Quiz generation / flashcards / spaced repetition** → v2 (STUDY-01..04). Phase 6 ships summary only.
- **PDF / whiteboard photo ingestion + OCR** → v2 (INGST-01..03). Phase 6 Vision provider tab is selectable but no Vision feature consumes it yet — Vision ingestion is v2.
- **Syllabus parsing + milestone tracking** → v2 (SYLL-01..03).
- **Hermes daily-ingest + weekly Study Pack Discord jobs** → v2+ (HERM-01..04). Phase 6 is single-user local.
- **Multi-user accounts / shared vault** → Out of Scope per PROJECT.md. Phase 6 is single-user Angelica.
- **Per-calendar toggle in classification (Phase 4 P-04 deferred this)** → Phase 6 Settings could add it under General tab, but discussion stayed within scope; flagged for v2 polish.
- **"Regenerate with whisper.cpp" user action (Phase 3 deferred item)** → Phase 6 does not ship this. Phase 6's Regenerate Summary (OLL-04) is LLM-only. Transcript regeneration would be a separate feature.
- **Cloud audio storage** → Out of Scope per PROJECT.md. Phase 6 cloud providers route audio through cloud models transiently for ASR; audio never lands in cloud storage.
- **iPad-optimized Settings layout** → v2. Phase 6 iPad uses iPhone Settings tab as-is.
- **Cloud-based speaker identification / diarization** → v2 (PROJECT.md Out of Scope). Phase 6 single-lecturer assumption inherited.
- **Confidence score in transcript or summary** → v2. Angelica doesn't need a confidence bar in MVP.
- **Consent expiry / re-consent after N days** → v2 polish if regulatory or trust concerns emerge. Phase 6 consent is permanent until explicitly revoked in Settings → Audit.
- **Cloud TTS playback feature** → v2. Phase 6 AudioSynthesizer tab is selectable in Settings (per CLOUD-01) but TTS playback is not wired to any feature.
- **Cloud Vision feature consumption (image description)** → v2 INGST-02 (whiteboard photo OCR). Phase 6 Vision provider tab is selectable but no Vision feature consumes it yet.

### Reviewed Todos (not folded)

None — no todos existed in `.planning/STATE.md` §"Pending Todos" at discussion time.

</deferred>

---

*Phase: 6-Gated Summarization + Cloud Providers + MVP Polish*
*Context gathered: 2026-07-14*
