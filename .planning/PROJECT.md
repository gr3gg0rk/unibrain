# unibrain

## What This Is

unibrain is a local-first, Apple-native lecture capture and study assistant for university students. It records lectures on a MacBook Neo and iPhone, transcribes them on-device with whisper.cpp/Metal, auto-classifies each recording to the right course using the student's Apple Calendar schedule, and writes structured Markdown notes (with YAML frontmatter and a gated Ollama-generated summary) into an Obsidian vault. The MVP delivers the "Record-to-Obsidian" loop end-to-end; broader ingestion (PDFs, whiteboard photos, syllabi), embeddings/retrieval, and quiz generation are deferred.

The first user is Angelica (starting university, MacBook Neo 8GB / iPhone / iPad Pro); the same shape can later serve Isabella (master's program).

## Core Value

**Every recording lands in the right course folder, transcribed and summarized, without the student ever manually organizing it.**

If the schedule-to-folder routing fails, the app has failed. Everything else (summaries, embeddings, study modes) is layered on top of that one thing being reliable.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] **Audio capture** — record lectures on MacBook Neo (built-in mic) and iPhone, with a clear start/stop UX
- [ ] **Local transcription** — whisper.cpp + Metal on the MacBook Neo, RAM-conscious (model loaded only at inference time)
- [ ] **Course classification** — map recording timestamp → course via Apple Calendar; auto-populate `course` and `tags` frontmatter
- [ ] **Obsidian write-out** — Markdown note per lecture in the right course folder, with YAML frontmatter (`course`, `datetime`, `source`, `tags`, `syllabus_link`, `vector_id`)
- [ ] **Gated summarization** — optional post-ingest step that calls a small Ollama model OR a user-configured cloud provider (OpenAI / Anthropic / Grok / Z.ai); off by default; user picks the LLM provider in Settings
- [ ] **8GB RAM discipline** — only one heavy model (ASR or LLM) loaded at a time; idle models released immediately
- [ ] **Build/test via GitHub Actions macOS CI** — every push builds + unit-tests the Swift target on a macOS runner, since no Mac is in the dev loop
- [ ] **Provider layer (local + cloud)** — protocol-abstraction layer covering LLM, ASR, Vision, Audio modalities; local backends (Ollama, whisper.cpp) ship as default; cloud backends (OpenAI, Anthropic, X/Grok, Z.ai) selectable per modality in Settings; API keys in Keychain

### Out of Scope

- **PDF / whiteboard photo ingestion + OCR** — Phase 2 (Vision framework, local)
- **Syllabus parsing + milestone tracking** — Phase 2
- **Local embeddings index + semantic retrieval** — Phase 2 (SQLite/FAISS, single index per vault)
- **Quiz generation / study modes** — Phase 2
- **Hermes daily-ingest + weekly Study Pack Discord jobs** — Phase 2+ (Hermes already runs on RPi 5 with idle cycles)
- **Cloud-first by default** — local is always the default mode; cloud providers require explicit user configuration per modality
- **Obsidian community plugin** — deferred; MVP uses plain folder + frontmatter conventions, no plugin dependency
- **Multi-user accounts / auth** — single-user (Angelica); no auth surface in v1
- **iPad-native capture** — iPad is a sync/view surface in MVP; recording happens on MacBook or iPhone
- **Android / Windows / Web** — Apple-only by design

## Context

**Origin.** Conceived 2026-06-25 (Plaud recording `plaud-2026-06-25-…lecture-assistant…`). The brief that initiated this project is the polished form of that transcript. The user (Greg / `gr3gg0rk`) is building this for his daughter Angelica, who is just starting university; Isabella (master's program) is a secondary future user.

**Dev environment.** Primary development happens on WSL2 Linux (`/home/gr3gg0rk/unibrain`) using Claude Code with GLM 5.2 + the GSD harness. **No Mac is in the home lab.** The only Apple device in scope is Angelica's MacBook Neo, which is a deployment target, not a dev seat.

**Build loop.** Swift source is written on WSL2, pushed to git, and built/tested by a GitHub Actions macOS runner. Angelica's MacBook Neo handles ad-hoc local builds and TestFlight-style device testing when she is available. This is the only viable native dev loop given the lab topology.

**Transcription.** whisper.cpp with Metal acceleration, `small.en` model class. ~1GB RAM when loaded, released immediately after transcription. Chosen over Apple Speech framework (weaker on technical/lecture content) and MLX-Whisper (newer, more setup friction). Note: MacBook Neo A-series Neural Engine may favor CoreML/WhisperKit over Metal — Phase 3 ASR strategy will re-evaluate.

**Hermes agent (existing infrastructure).** A Hermes agent already runs on a Raspberry Pi 5 in the home lab, integrated with Discord. Current jobs: Aletheia Dreams (idea generation every 6h), nightly committee selection, KISS refactoring. It has idle cycles and a Discord surface — Phase 2+ work for unibrain (daily ingest QA, weekly Study Pack delivery, lightweight CI on the Pi) is a natural fit.

**Obsidian vault topology (assumption — see Assumptions below).** Greg's existing vault at `/mnt/c/Obsidian-vault/griak-home/` is unrelated. Angelica gets her own vault on her MacBook Neo, synced to her iPhone/iPad Pro via iCloud Drive. Hermes jobs (Phase 2+) observe a read-only sync copy on the home network — they do not host or own her vault.

**Apple ecosystem constraints.** Target devices: MacBook Neo (A-series chip, macOS 26 Tahoe, 8GB unified memory), iPhone, iPad Pro. Native frameworks preferred: AVFoundation (audio capture), Vision (OCR, Phase 2), Speech (fallback ASR only), Metal (whisper.cpp acceleration), EventKit (Apple Calendar access for course classification).

## Constraints

- **Hardware**: MacBook Neo (A-series chip, macOS 26 Tahoe, 8GB unified memory) — only one local heavy model loaded at a time; cloud offload relieves this when configured
- **Local-first by default, cloud by choice**: Local (Ollama, whisper.cpp) is the always-available default. Cloud AI providers (OpenAI, Anthropic, X/Grok, Z.ai, others) are explicit opt-in alternatives per modality (LLM / ASR / Vision / Audio). Local is never removed — only augmented. No cloud call ever happens without user configuration.
- **Storage stays local**: Lecture audio + transcripts + vault live on Angelica's devices. iCloud Drive acceptable for vault sync between Angelica's own devices only. Audio never sent to cloud storage — only routed through cloud models transiently when the user opts in.
- **Apple-native**: SwiftUI + native frameworks (AVFoundation / Vision / Speech / Metal / EventKit). No Electron, no web wrapper, no cross-platform abstraction in v1
- **Dev access**: No Mac in dev loop — GitHub Actions macOS CI is the build/test path from WSL2
- **Privacy**: Local-only is the default mode (zero cloud, zero telemetry). Cloud mode sends only what the user explicitly routes; per-document consent gate the first time per modality. API keys stored in macOS Keychain / iOS Secure Enclave.
- **Single-user**: v1 is Angelica only — no auth, no multi-tenant, no sharing surface
- **Schedule source**: Course schedule lives in Apple Calendar on Angelica's devices (read via EventKit)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native SwiftUI app (not Python pipeline / hybrid) | Best UX, native framework access, native memory discipline on 8GB | Decided |
| whisper.cpp + Metal for ASR | Best accuracy/footprint tradeoff on 8GB; releases RAM when idle | Decided (Phase 3 will re-evaluate vs SpeechAnalyzer / WhisperKit on MacBook Neo A-series) |
| GitHub Actions macOS CI for builds | No Mac in lab; CI is the only build/test path from WSL2 | Decided (D-02) |
| Capture on MacBook Neo **and** iPhone in MVP | User choice — wider scope, but iPhone is the realistic in-class recording device | Decided |
| **Local-default + cloud-opt-in provider layer** | Local (Ollama, whisper.cpp) is always available as default. Cloud providers (OpenAI, Anthropic, X/Grok, Z.ai, others) are explicit opt-in alternatives per modality (LLM / ASR / Vision / Audio). User picks per modality in Settings. Preserves privacy-by-default + offline capability while unlocking subscription quality. | Decided |
| Obsidian vault as primary store (Markdown + YAML frontmatter) | Local-first storage mandate; no plugin dependency in MVP | Decided |
| Hermes integration deferred to Phase 2+ | MVP is capture → classify → write; Hermes jobs (ingest QA, Study Pack, CI) layer on after MVP ships | Decided |
| Course classification via Apple Calendar + EventKit | Already on Angelica's devices; no separate schedule DB to maintain | Decided |
| Apple Developer Program | Deferred to Phase 3 — $99/yr paid recommended for TestFlight + crash logs. Not blocking Phase 1 SPM/CI work. | Deferred (D-01, FOUND-06) |
| Public repository | Unlimited free macOS CI minutes on GitHub Actions. No proprietary logic, no secrets, single-user. | Decided (D-02) |
| MacBook Neo hardware | macOS 26 (Tahoe), A-series chip, 8GB unified memory. Affects ASR strategy (CoreML/ANE may favor WhisperKit over Metal). | Confirmed (D-03, D-06) |
| Deployment targets | macOS 26 (Tahoe) / iOS 17. Unlocks SpeechAnalyzer on macOS; keeps EventKit iOS 17+ API. | Decided (D-05) |
| iPhone/iPad OS versions | Unknown — verify with Angelica before Phase 5 iOS capture work. iPad is view/sync surface only in MVP. | Informational (D-04) |
| Bundle ID | app.unibrain (subject to change when Apple Dev account is activated in Phase 3) | Provisional |
| Swift 6 strict concurrency | swiftLanguageMode(.v6) on all targets. Greenfield project — start in Swift 6 from day one. | Decided |

## Assumptions (confirm during PROJECT.md review)

These were not explicitly confirmed in questioning and are documented here so they can be corrected before they propagate into the roadmap:

1. **Angelica's vault is separate** — a new vault on her MacBook Neo, not a folder inside Greg's `griak-home` vault.
2. **iCloud Drive syncs** her vault to her iPhone/iPad Pro.
3. **Hermes Phase-2 jobs** observe a read-only sync copy on Greg's home network — they never host or write to Angelica's vault directly.
4. **Greg is sole developer**; Angelica is end-user + feedback source (not a co-developer).
5. **Course schedule source** is Apple Calendar on Angelica's devices (EventKit-readable).
6. **iPad is a view/sync surface only in MVP** — recording happens on MacBook or iPhone.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

## Current State

**Phase 6 source-complete (2026-07-17).** All 6 phases implemented at source level: foundation (01), pure pipeline logic (02), macOS capture+transcribe scaffolding (03), course classification smart routing (04), iOS capture + iCloud handoff + onboarding (05), gated summarization + cloud providers + MVP polish (06). Phase 6 gap closure (plan 06-07) wired frontmatter v2 audit fields into the summarization path and fixed the AuditTrailStore status derivation bug; full `swift test` runs 345/345 with zero regressions.

**Device verification deferred** to 06-UAT.md (15 scenarios) + 03/04/05 device-deferred items — requires Apple Developer Program membership + Angelica's MacBook Neo + iPhone. Requirements remain in **Active** until device UAT confirms ship-quality behavior.

---
*Last updated: 2026-07-17 — Phase 6 source-complete (gated summarization + cloud providers + MVP polish, 345/345 tests passing); device UAT pending Apple Dev Program*
