# Phase 6: Gated Summarization + Cloud Providers + MVP Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 6-Gated Summarization + Cloud Providers + MVP Polish
**Areas discussed:** Settings UI architecture, Consent + audit mechanics, Cloud failure recovery, Ollama setup UX

---

## Settings UI Architecture

### Q1: Where does Settings live on macOS?

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated macOS Settings window | Standard SwiftUI `Settings` scene (opens via ⌘, or "Settings…" menu item, or popover button). Separate window from menu-bar popover. Apple's expected macOS pattern. | ✓ |
| Sheet off menu-bar popover | Sheet slides down from popover window. Popover is ~280pt wide, too narrow for multi-tab Settings. | |
| Popover entry → dedicated window | Menu-bar popover has "Settings…" button that opens a dedicated window. Same as option A but with explicit popover entry. | |

**User's choice:** Dedicated macOS Settings window
**Notes:** Apple's expected macOS pattern; popover stays recording-focused, Settings gets full width for tab layout.

### Q2: How are Settings tabs organized?

| Option | Description | Selected |
|--------|-------------|----------|
| By function | General \| Providers \| Courses \| Permissions \| Audit. Providers tab holds all four modality selectors inline. Matches macOS System Settings pattern. | ✓ |
| By modality | LLM \| ASR \| Vision \| TTS \| Courses \| Permissions. Each modality is a tab. 6+ tabs, mixes per-modality config with global concerns. | |
| By user-facing concept | General \| Transcription \| Summarization \| Vision \| Audio \| Courses \| Permissions. Each modality is a tab named by concept. 7 tabs. | |

**User's choice:** By function
**Notes:** Standard macOS pattern; "what am I configuring?" not "which modality is this?".

### Q3: What does the iOS Settings tab contain?

| Option | Description | Selected |
|--------|-------------|----------|
| Full parity with macOS | iOS mirrors macOS structure. Angelica can configure providers, audit, courses from either device. More code (every screen needs iOS layout). | |
| Read-only on iOS | iOS Settings = Permissions actionable + read-only view of everything else. Configuration is macOS-first; iPhone inherits via iCloud sync. | ✓ |
| Permissions only (Phase 5 placeholder) | Phase 5 ONB-04 minimal placeholder stays. Provider config, audit, courses are macOS-only. | |

**User's choice:** Read-only on iOS
**Notes:** Matches Phase 5 ONB-01 macOS-first setup. Reduces Phase 6 iOS surface area significantly.

### Q4: Fold existing sheets into Settings tabs now?

| Option | Description | Selected |
|--------|-------------|----------|
| Fold both into Settings tabs now | Phase 4 Manage Courses → Courses tab; Phase 5 Permissions → Permissions tab. Standalone sheet entry points removed. | ✓ |
| Leave sheets standalone, tabs re-launch them | Existing sheets stay; new tabs re-launch them. Two ways to open same UI (redundant). | |
| Fold Courses only; Permissions stays split | Manage Courses moves to tab. Permissions sheet stays standalone (also used by onboarding). | |

**User's choice:** Fold both into Settings tabs now
**Notes:** Single coherent Settings surface; fewer entry points for Angelica to learn.

---

## Consent + Audit Mechanics

### Q1: Where does the first-use consent dialog appear?

| Option | Description | Selected |
|--------|-------------|----------|
| Sheet on menu-bar popover | Sheet slides down from popover window when a cloud call is about to fire. Stays in menu-bar surface. | ✓ |
| Inline banner in popover | Banner replaces popover status line. Less heavy than sheet but easy to miss. | |
| Modal window center-screen | Separate modal window opens. Impossible to miss but intrusive; macOS UX norm is sheets. | |

**User's choice:** Sheet on menu-bar popover
**Notes:** Consistent with Phase 3-5 macOS menu-bar surface convention.

### Q2: What does "Always allow" cover?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-provider-per-modality | "Always allow OpenAI for transcription." Strictest. Matches CLOUD-08 spec verbatim. | ✓ |
| Per-provider global | "Always allow OpenAI." Covers all modalities OpenAI supports. | |
| Per-modality global | "Always allow cloud transcription." Covers any provider for that modality. | |

**User's choice:** Per-provider-per-modality
**Notes:** Strictest scope; preserves per-modality audit trail integrity.

### Q3: Where is consent state persisted?

| Option | Description | Selected |
|--------|-------------|----------|
| Vault-synced `.unibrain/consent.json` | Lives inside vault alongside Phase 4 M-01 courses.json. iCloud syncs between devices. JSON is debuggable. | ✓ |
| Per-device Keychain entry | Generic password per provider+modality. Secure, standard. Per-device. | |
| UserDefaults | Trivially simple. Unencrypted; not iCloud-synced by default. | |

**User's choice:** Vault-synced `.unibrain/consent.json`
**Notes:** One decision applies to both devices; sits with other dotfolder state.

### Q4: Audit trail shape in frontmatter (CLOUD-13)?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-modality fields | `asr_provider`, `llm_provider`, `vision_provider` (each `string?`, null when not used). schema_version 1→2 bump. | ✓ |
| Single `provider_used` field | Matches CLOUD-13 spec verbatim. Simple but ambiguous when multiple providers touch one note. | |
| Array of `{modality, provider, timestamp}` entries | Full call log per note. Verbose; overkill for single-user MVP. | |

**User's choice:** Per-modality fields
**Notes:** Plays nicely with existing `summary_model` (specific model name) — provider is the company, model is the version.

---

## Cloud Failure Recovery

### Q1: When a cloud call fails, what's the recovery flow?

| Option | Description | Selected |
|--------|-------------|----------|
| Prompted retry + explicit fallback | 3 provider retries with backoff, then sheet with [Retry] / [Fall back to local] / [Cancel]. Angelica explicitly chooses fallback. | ✓ |
| Auto-fallback to local, banner only | On error after retries: automatic fallback. Non-blocking banner. Surprises Angelica. | |
| Error only, no fallback | Surface error. Angelica must retry or change provider in Settings. Most friction. | |

**User's choice:** Prompted retry + explicit fallback
**Notes:** Angelica stays in control; fallback is explicit; recording audio preserved regardless of choice.

### Q2: When does the network reachability check fire?

| Option | Description | Selected |
|--------|-------------|----------|
| Every cloud call | Quick TCP connect to provider host:443 with 2s timeout. Fails fast, saves 30s+ URLRequest timeout UX. | ✓ |
| Once per session / cached | Cache result. Stale state if WiFi returns mid-session. | |
| No pre-check (let URLRequest fail) | Simplest. Very slow failure (30-60s system timeout). Bad UX mid-lecture. | |

**User's choice:** Every cloud call
**Notes:** 2s pre-check trades negligible overhead for fast-failure UX.

### Q3: How do the two retry layers compose?

| Option | Description | Selected |
|--------|-------------|----------|
| Compose: provider inner, queue outer | Provider retries 3× (2s/8s/30s). Queue retries whole pipeline 3× (30s/2min/10min). Up to 9 total attempts for one file. | ✓ |
| Queue-level only (provider client no-retry) | Single retry layer. Queue catches all failures. Wasteful: re-runs ASR even if only LLM failed. | |
| Provider only (queue skips cloud failures) | Provider retries 3×. Queue does NOT retry cloud failures; they're terminal. One shot at cloud per file. | |

**User's choice:** Compose: provider inner, queue outer
**Notes:** Maximum recovery with clean separation. Two layers don't know about each other.

### Q4: Where do cloud failures show up?

| Option | Description | Selected |
|--------|-------------|----------|
| Popover banner + Audit tab | Banner for active recording state with action buttons; Audit tab for retroactive review. | ✓ |
| Popover banner only | Simpler Audit tab. Banner dismissible loses error context. | |
| macOS notification + Audit tab | Works even when popover hidden. Notifications can be missed. | |

**User's choice:** Popover banner + Audit tab
**Notes:** Active feedback + retroactive audit. Matches SET-02 Settings tab design.

---

## Ollama Setup UX

### Q1: How to handle "Ollama not installed"?

| Option | Description | Selected |
|--------|-------------|----------|
| Detect-and-link to ollama.com | Settings callout with [Download Ollama] button (opens browser). No in-app installer, no auto-launch. | ✓ |
| Detect + auto-launch if installed + link if not | Same as above + attempt `NSWorkspace.open` for `/Applications/Ollama.app` if installed. One-click launch. | |
| Setup Wizard (full automation) | Wizard downloads installer, runs it (admin password), pulls model. Bundling complexity. | |

**User's choice:** Detect-and-link to ollama.com
**Notes:** Respects Angelica's control of the machine; avoids Gatekeeper / notarization complexity.

### Q2: How does Angelica discover Ollama is needed?

| Option | Description | Selected |
|--------|-------------|----------|
| Settings toggle reveals install prompt | Summary toggle in Settings → General. When flipped to "Local (Ollama)" and health check fails, callout appears. | ✓ |
| Post-onboarding tip banner | One-time dismissible banner after onboarding. Surfaces feature to all users. | |
| Both: toggle + post-onboarding banner | Belt-and-suspenders. | |

**User's choice:** Settings toggle reveals install prompt
**Notes:** Zero friction for users who don't care; matches SUMM-02 off-by-default.

### Q3: First-run model download — how does `llama-3.2:3b` pull happen?

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit "Pull model" button in Settings | Button fires `ollama pull llama-3.2:3b` via Process. Progress bar in Settings. Angelica sees 2GB commitment before it starts. | ✓ |
| Auto-pull in background on first trigger | Silent background download. Bad for tethered hotspot. | |
| Manual `ollama pull` (terminal) | Requires Terminal literacy. Unacceptable for Angelica. | |

**User's choice:** Explicit "Pull model" button in Settings
**Notes:** Bandwidth-respect decision. No silent 2GB download.

### Q4: Where does `## Summary` appear in the note?

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom of note + comment markers | Appends after transcript. `## Summary` wrapped in HTML comment markers for Regenerate. Preserves transcript edits. | ✓ |
| Top of note + comment markers | First thing Angelica sees. Breaks natural chronology. | |
| Separate sidecar file | Keeps transcript pristine. Breaks SUMM-05 "same note" requirement; two files to sync. | |

**User's choice:** Bottom of note + comment markers
**Notes:** Natural chronology (raw data first, conclusion last). HTML comment markers enable simple string-replace Regenerate — no Markdown AST parsing.

---

## Claude's Discretion

The following were left to the planner / executor discretion:

- `ProviderError` extension for cloud-specific cases (`.apiKeyMissing`, `.providerUnreachable`, `.consentDenied`)
- TCP reachability check implementation (`NWConnection` vs raw `socket()`)
- `Process` shell-out to `ollama pull` — exact Process setup, stderr parsing
- Audit tab query UI — filters, table columns, sort order (in-memory scan, NOT SQLite)
- `.unibrain/consent.json` schema versioning (add `schema_version: 1` field)
- General tab contents beyond Summarization toggle (vault path, current term, app version)
- `schema_version: 2` migration logic (additive; no on-disk migration; decoder treats missing fields as nil)
- Cloud client HTTP stack (URLSession with ATS on; shared vs per-provider `URLSession.Configuration`)
- API key entry UI (`SecureField`, masked display; iCloud Keychain sync vs device-local — default device-local)
- Consent record key shape (string concat `"openai.asr"` vs nested dict)
- Regenerate Summary discovery outside Settings (long-press in Obsidian? — Phase 6 ships Settings-only)
- Prompt template file location (`UnibrainCore/Prompts/summary-default.md` vs inline string)
- Cloud client target placement (`UnibrainProviders` vs `UnibrainCore` behind `#if canImport(FoundationNetworking)` — Linux-buildable preferred)
- Zero-telemetry verification approach (code review + mitmproxy audit + MAINTAINERS.md checklist; not runtime)

## Deferred Ideas

- Local embeddings index / semantic search → v2 (EMBD-01..04)
- Live Activity / Dynamic Island recording indicator → v2 polish
- Streaming LLM responses (OpenAI streaming, Anthropic SSE) → v2 per D-17 single-shot
- Quiz generation / flashcards / spaced repetition → v2 (STUDY-01..04)
- PDF / whiteboard photo ingestion + OCR → v2 (INGST-01..03); Phase 6 Vision tab selectable but unconsumed
- Syllabus parsing + milestone tracking → v2 (SYLL-01..03)
- Hermes daily-ingest + weekly Study Pack Discord jobs → v2+ (HERM-01..04)
- Multi-user accounts / shared vault → Out of Scope per PROJECT.md
- Per-calendar toggle in classification (Phase 4 P-04) → v2 polish
- "Regenerate with whisper.cpp" user action → Phase 6 ships LLM-only Regenerate; transcript regen is separate feature
- Cloud audio storage → Out of Scope per PROJECT.md
- iPad-optimized Settings layout → v2
- Cloud-based speaker identification / diarization → v2
- Confidence score in transcript or summary → v2
- Consent expiry / re-consent after N days → v2 polish
- Cloud TTS playback feature → v2 (AudioSynthesizer tab selectable but no feature consumes TTS yet)
- Cloud Vision feature consumption (image description) → v2 INGST-02 (whiteboard OCR)
