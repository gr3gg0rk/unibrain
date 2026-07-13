# unibrain

## What This Is

unibrain is a local-first, Apple-native lecture capture and study assistant for university students. It records lectures on a MacBook Air and iPhone, transcribes them on-device with whisper.cpp/Metal, auto-classifies each recording to the right course using the student's Apple Calendar schedule, and writes structured Markdown notes (with YAML frontmatter and a gated Ollama-generated summary) into an Obsidian vault. The MVP delivers the "Record-to-Obsidian" loop end-to-end; broader ingestion (PDFs, whiteboard photos, syllabi), embeddings/retrieval, and quiz generation are deferred.

The first user is Angelica (starting university, MacBook Air 8GB / iPhone / iPad Pro); the same shape can later serve Isabella (master's program).

## Core Value

**Every recording lands in the right course folder, transcribed and summarized, without the student ever manually organizing it.**

If the schedule-to-folder routing fails, the app has failed. Everything else (summaries, embeddings, study modes) is layered on top of that one thing being reliable.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] **Audio capture** — record lectures on MacBook Air (built-in mic) and iPhone, with a clear start/stop UX
- [ ] **Local transcription** — whisper.cpp + Metal on the MacBook Air, RAM-conscious (model loaded only at inference time)
- [ ] **Course classification** — map recording timestamp → course via Apple Calendar; auto-populate `course` and `tags` frontmatter
- [ ] **Obsidian write-out** — Markdown note per lecture in the right course folder, with YAML frontmatter (`course`, `datetime`, `source`, `tags`, `syllabus_link`, `vector_id`)
- [ ] **Gated summarization** — optional post-ingest step that calls a small Ollama model and writes key points into the same note; off by default to conserve RAM
- [ ] **8GB RAM discipline** — only one heavy model (ASR or LLM) loaded at a time; idle models released immediately
- [ ] **Build/test via GitHub Actions macOS CI** — every push builds + unit-tests the Swift target on a macOS runner, since no Mac is in the dev loop

### Out of Scope

- **PDF / whiteboard photo ingestion + OCR** — Phase 2 (Vision framework, local)
- **Syllabus parsing + milestone tracking** — Phase 2
- **Local embeddings index + semantic retrieval** — Phase 2 (SQLite/FAISS, single index per vault)
- **Quiz generation / study modes** — Phase 2
- **Hermes daily-ingest + weekly Study Pack Discord jobs** — Phase 2+ (Hermes already runs on RPi 5 with idle cycles)
- **Cloud LLM as primary path** — local-only by mandate; narrow opt-in "escape hatch" per-document with explicit consent only
- **Obsidian community plugin** — deferred; MVP uses plain folder + frontmatter conventions, no plugin dependency
- **Multi-user accounts / auth** — single-user (Angelica); no auth surface in v1
- **iPad-native capture** — iPad is a sync/view surface in MVP; recording happens on MacBook or iPhone
- **Android / Windows / Web** — Apple-only by design

## Context

**Origin.** Conceived 2026-06-25 (Plaud recording `plaud-2026-06-25-…lecture-assistant…`). The brief that initiated this project is the polished form of that transcript. The user (Greg / `gr3gg0rk`) is building this for his daughter Angelica, who is just starting university; Isabella (master's program) is a secondary future user.

**Dev environment.** Primary development happens on WSL2 Linux (`/home/gr3gg0rk/unibrain`) using Claude Code with GLM 5.2 + the GSD harness. **No Mac is in the home lab.** The only Apple device in scope is Angelica's MacBook Air, which is a deployment target, not a dev seat.

**Build loop.** Swift source is written on WSL2, pushed to git, and built/tested by a GitHub Actions macOS runner. Angelica's MacBook Air handles ad-hoc local builds and TestFlight-style device testing when she is available. This is the only viable native dev loop given the lab topology.

**Transcription.** whisper.cpp with Metal acceleration, `small.en` model class. ~1GB RAM when loaded, released immediately after transcription. Chosen over Apple Speech framework (weaker on technical/lecture content) and MLX-Whisper (newer, more setup friction).

**Hermes agent (existing infrastructure).** A Hermes agent already runs on a Raspberry Pi 5 in the home lab, integrated with Discord. Current jobs: Aletheia Dreams (idea generation every 6h), nightly committee selection, KISS refactoring. It has idle cycles and a Discord surface — Phase 2+ work for unibrain (daily ingest QA, weekly Study Pack delivery, lightweight CI on the Pi) is a natural fit.

**Obsidian vault topology (assumption — see Assumptions below).** Greg's existing vault at `/mnt/c/Obsidian-vault/griak-home/` is unrelated. Angelica gets her own vault on her MacBook Air, synced to her iPhone/iPad Pro via iCloud Drive. Hermes jobs (Phase 2+) observe a read-only sync copy on the home network — they do not host or own her vault.

**Apple ecosystem constraints.** Target devices: MacBook Air (Apple Silicon, 8GB unified memory), iPhone, iPad Pro. Native frameworks preferred: AVFoundation (audio capture), Vision (OCR, Phase 2), Speech (fallback ASR only), Metal (whisper.cpp acceleration), EventKit (Apple Calendar access for course classification).

## Constraints

- **Hardware**: MacBook Air 8GB unified memory — only one heavy model loaded at a time; cap context windows; batch operations
- **Local-first**: No third-party cloud for primary storage; iCloud Drive acceptable for vault sync between Angelica's own devices only
- **Apple-native**: SwiftUI + native frameworks (AVFoundation / Vision / Speech / Metal / EventKit). No Electron, no web wrapper, no cross-platform abstraction in v1
- **Dev access**: No Mac in dev loop — GitHub Actions macOS CI is the build/test path from WSL2
- **Privacy**: Lecture content stays on Angelica's devices + her vault. No telemetry, no cloud LLM as primary path
- **Single-user**: v1 is Angelica only — no auth, no multi-tenant, no sharing surface
- **Schedule source**: Course schedule lives in Apple Calendar on Angelica's devices (read via EventKit)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native SwiftUI app (not Python pipeline / hybrid) | Best UX, native framework access, native memory discipline on 8GB | — Pending |
| whisper.cpp + Metal for ASR | Best accuracy/footprint tradeoff on 8GB; releases RAM when idle | — Pending |
| GitHub Actions macOS CI for builds | No Mac in lab; CI is the only build/test path from WSL2 | — Pending |
| Capture on MacBook Air **and** iPhone in MVP | User choice — wider scope, but iPhone is the realistic in-class recording device | — Pending |
| Local LLM via Ollama, escape-hatch only | Privacy + offline by mandate; cloud only with explicit per-document consent | — Pending |
| Obsidian vault as primary store (Markdown + YAML frontmatter) | Local-first mandate; no plugin dependency in MVP | — Pending |
| Hermes integration deferred to Phase 2+ | MVP is capture → classify → write; Hermes jobs (ingest QA, Study Pack, CI) layer on after MVP ships | — Pending |
| Course classification via Apple Calendar + EventKit | Already on Angelica's devices; no separate schedule DB to maintain | — Pending |

## Assumptions (confirm during PROJECT.md review)

These were not explicitly confirmed in questioning and are documented here so they can be corrected before they propagate into the roadmap:

1. **Angelica's vault is separate** — a new vault on her MacBook Air, not a folder inside Greg's `griak-home` vault.
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

---
*Last updated: 2026-07-13 after initialization*
