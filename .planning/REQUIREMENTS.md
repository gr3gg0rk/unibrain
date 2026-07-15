# Requirements: unibrain

**Defined:** 2026-07-13
**Core Value:** Every recording lands in the right course folder, transcribed and optionally summarized, without the student ever manually organizing it.

## v1 Requirements

Requirements for the MVP "Record-to-Obsidian" release. Each maps to a roadmap phase. Categories derived from `research/FEATURES.md` and the architecture/pitfalls research.

### Foundation

- [x] **FOUND-01**: Swift Package Manager multiplatform target (macOS + iOS) in one Xcode project, sharing non-UI logic
- [x] **FOUND-02**: Protocol-abstraction layer (Provider layer) covering all inference modalities — `LLMSummarizer`, `AudioTranscriber`, `VisionDescriber`, `AudioSynthesizer` protocols with pluggable backends. Concrete backends: local (Ollama, whisper.cpp) + cloud (OpenAI, Anthropic, X/Grok, Z.ai). Enables pure-logic unit tests on WSL2 Linux Swift toolchain without Apple frameworks.
- [x] **FOUND-03**: GitHub Actions macOS CI workflow on `macos-15` runner that builds the SPM package + runs tests on every push, with SPM cache and DerivedData cache to conserve minutes
- [x] **FOUND-04**: `ModelLoadGate` actor (Swift concurrency) that enforces one-heavy-model-at-a-time — ASR and LLM cannot be loaded simultaneously
- [x] **FOUND-05**: Yams YAML library integrated for frontmatter serialization/deserialization
- [x] **FOUND-06**: Apple Developer Program membership decision documented (research recommends $99/yr paid for TestFlight + crash logs; user to confirm)

### Capture

- [x] **CAPT-01**: One-tap start/stop recording on macOS via menu-bar (`MenuBarExtra`) and app-window record button
- [x] **CAPT-02**: Pause/resume during recording maintaining a single contiguous audio file with pause/resume timestamps
- [ ] **CAPT-03**: Background recording on iOS using `AVAudioSession` background audio mode with lock-screen recording indicator
- [x] **CAPT-04**: Live recording timer + waveform display during capture
- [x] **CAPT-05**: Mic level meter confirming the lecturer is audible
- [x] **CAPT-06**: Audio exported as `.m4a` (AAC) into the vault attachment folder alongside the note

### Classify

- [ ] **CLAS-01**: EventKit queries calendar events overlapping `recordingStart ± 30min` to identify the current course
- [ ] **CLAS-02**: Maps matched event title → course folder via a settings-driven course mapping table
- [ ] **CLAS-03**: Auto-creates a course folder for unrecognized event titles (sanitized)
- [ ] **CLAS-04**: Manual course picker fallback shown when zero or multiple events match (recent courses + search)
- [ ] **CLAS-05**: Multi-term folder structure: `{vault}/{term}/{course-code}/`
- [ ] **CLAS-06**: "Current term" setting that filters out past-term calendar events from classification
- [ ] **CLAS-07**: Manual override is remembered per course for the next recording

### Transcribe

- [x] **TRAN-01**: whisper.cpp + Metal integrated via Swift binding (`SwiftWhisper` or whisper.cpp native SPM) — the LOCAL backend of the `AudioTranscriber` provider protocol
- [x] **TRAN-02**: `small.en` model (~852MB runtime RAM) downloaded on first run with checksum verification
- [x] **TRAN-03**: Transcription runs on `Task.detached` (never on `@MainActor`) — UI stays responsive
- [x] **TRAN-04**: Transcription is post-capture only (no live transcript display in MVP — deliberate RAM tradeoff)
- [ ] **TRAN-05**: Transcript post-processed into paragraphs by time gaps between whisper segments
- [x] **TRAN-06**: Model released from memory immediately after transcription completes

### Vault Write-Out

- [x] **WRITE-01**: Markdown note written to `{vault}/{term}/{course-code}/YYYY-MM-DD-{COURSE}-Lecture.md`
- [x] **WRITE-02**: YAML frontmatter includes: `schema_version`, `course`, `course_name`, `term`, `datetime`, `duration_seconds`, `source`, `audio_file`, `tags`, `syllabus_link` (null in v1), `vector_id` (null in v1), `summary_model` (null unless summarized)
- [x] **WRITE-03**: Audio file written alongside note and referenced via Obsidian wiki-link (`![[...]]`)
- [x] **WRITE-04**: Atomic write via `NSFileCoordinator` to avoid corruption with iCloud Drive sync
- [x] **WRITE-05**: `.icloud` placeholder files (not-yet-downloaded iCloud Drive files) are detected and skipped gracefully
- [x] **WRITE-06**: Write failures surface a clear error to the user with retry, never silently drop a recording

### Summarize

- [ ] **SUMM-01**: Ollama HTTP API integration at `localhost:11434` with health-check before use — the LOCAL backend of the `LLMSummarizer` provider protocol
- [ ] **SUMM-02**: Summary feature is **OFF by default** (gated — user opts in via Settings)
- [ ] **SUMM-03**: Uses `llama-3.2-3b` (or `qwen2.5:3b`) with `keep_alive: 0` so Ollama releases RAM immediately
- [ ] **SUMM-04**: Generates 5-8 bullet key points focused on "concepts and definitions a student needs to know"
- [ ] **SUMM-05**: Summary written under `## Summary` heading in the same note (not a separate file)
- [ ] **SUMM-06**: "Regenerate Summary" action re-runs Ollama on the (possibly edited) transcript and replaces only the Summary section
- [ ] **SUMM-07**: Summary refuses to run while ASR is loaded (ModelLoadGate serialization)

### Onboarding

- [ ] **ONBD-01**: First-run flow: welcome → vault folder picker → mic permission → calendar permission → current-term label → ready
- [ ] **ONBD-02**: Microphone permission required — hard-fail with explanation + Settings deep-link if denied
- [ ] **ONBD-03**: Calendar permission optional — degrades to manual course picker; explanation shown if denied
- [ ] **ONBD-04**: Vault folder picker suggests iCloud Drive location; any user-chosen folder works
- [ ] **ONBD-05**: Permissions screen accessible post-onboarding for re-grant or audit

### Discipline (Cross-Cutting)

- [x] **DISC-01**: At most one heavy LOCAL model (ASR or LLM) loaded into RAM at any time, enforced by `ModelLoadGate`. (Cloud providers don't count toward local RAM budget.)
- [x] **DISC-02**: All Apple-framework dependencies (AVFoundation, EventKit, FileManager, Ollama client) sit behind protocols so pure-logic tests run without Apple frameworks
- [x] **DISC-03**: Pure-logic unit tests (Normalizer, FrontmatterSchema, CourseClassifier, Orchestrator with mocks) run on WSL2 Linux Swift toolchain without Xcode
- [ ] **DISC-04**: App survives iOS backgrounding during an active recording
- [ ] **DISC-05**: Local-first core path: capture → classify → transcribe (local) → write works fully offline by default. Cloud provider calls are explicit user opt-in per modality, never silently injected.
- [ ] **DISC-06**: iCloud Drive sync conflicts do not corrupt notes (atomic writes + schema_version field for migration)

### Cloud Providers (Provider Layer — opt-in per modality)

- [ ] **CLOUD-01**: Settings UI exposes per-modality provider selection: each of LLM / ASR / Vision / TTS can be set to `Local` / `Off` / a configured cloud provider (e.g., `OpenAI`, `Anthropic`, `Grok`, `Z.ai`)
- [ ] **CLOUD-02**: Local is always the default for every modality on first launch — user must explicitly add and select cloud providers
- [ ] **CLOUD-03**: OpenAI provider integration: `gpt-4o` / `gpt-4o-mini` for LLM summary, `whisper-1` API for ASR alternative, `gpt-4o` vision for image description
- [ ] **CLOUD-04**: Anthropic provider integration: Claude (current Sonnet/Opus) for LLM summary + vision
- [ ] **CLOUD-05**: X / Grok provider integration: Grok for LLM summary
- [ ] **CLOUD-06**: Z.ai provider integration: GLM family for LLM summary
- [ ] **CLOUD-07**: API key storage in macOS Keychain (macOS) / iOS Secure Enclave (iOS); never written to plaintext config or vault
- [ ] **CLOUD-08**: First-use consent gate per modality per provider: "Allow OpenAI to transcribe this recording?" with "Always allow OpenAI for ASR" toggle
- [ ] **CLOUD-09**: Cloud transcription is an ALTERNATIVE to local whisper.cpp — only one ASR backend runs per recording (whichever the user selected in Settings at recording time)
- [ ] **CLOUD-10**: Cloud provider failure surfaces a clear error and offers "retry" or "fall back to local" — never silent
- [ ] **CLOUD-11**: Network reachability check before cloud calls; if offline, automatically fall back to local (if configured) or queue for retry
- [ ] **CLOUD-12**: Zero telemetry, zero analytics, zero "phone home" — the only outbound network traffic is user-initiated inference calls to configured providers
- [ ] **CLOUD-13**: Per-document audit trail in frontmatter: `provider_used: openai | anthropic | grok | zai | ollama | whisper-cpp` so the user knows which model touched each note

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Ingest (Phase 2)

- **INGST-01**: PDF parsing + text extraction into per-document Markdown notes
- **INGST-02**: Whiteboard photo OCR via Vision framework with optional local image captioning
- **INGST-03**: Slide deck PDF → per-slide image + OCR text

### Syllabus

- **SYLL-01**: Syllabus parser extracts course schema (instructor, meeting pattern, textbook, grading weights)
- **SYLL-02**: Milestone timeline (exams, assignments, holidays) written to course folder index note
- **SYLL-03**: Frontmatter `syllabus_link` field populated

### Embeddings + Retrieval

- **EMBD-01**: Local embeddings index (SQLite-VSS or FAISS-CPU) over all transcript text
- **EMBD-02**: Small footprint embedding model (`nomic-embed-text` or `all-minilm`)
- **EMBD-03**: Semantic search UI ("when did prof mention X?")
- **EMBD-04**: Frontmatter `vector_id` populated for every note

### Study Aids

- **STUDY-01**: Flashcard generation (Q&A pairs) from transcripts via Ollama
- **STUDY-02**: FSRS spaced repetition scheduling
- **STUDY-03**: Multiple-choice quiz generation per course from recent notes
- **STUDY-04**: Cross-lecture similarity ("this concept was also covered in Lecture 3")

### Capture Enhancements

- **CAPT-07**: iOS Action Button / Lock Screen widget one-tap trigger
- **CAPT-08**: Hands-free bookmark during recording (Snipd-style AirPods tap / phone shake)
- **CAPT-09**: Audio-transcript playback sync (tap word → audio seeks to timestamp)
- **CAPT-10**: iPad-native capture (iPad is view/sync surface in v1)

### Hermes Integration

- **HERM-01**: Daily ingest QA job: scan new vault notes, flag missing metadata / misclassified courses, post to Discord
- **HERM-02**: Weekly "Study Pack" generator: compile summaries + 10-question quiz per course, deliver in Discord
- **HERM-03**: Lightweight CI on Raspberry Pi 5 running unit tests after each commit, posting results to Discord
- **HERM-04**: Read-only sync copy of Angelica's vault on Greg's home network (Hermes never writes to her vault)

## Out of Scope

Explicit exclusions documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cloud audio storage | Violates local-first mandate; lecture audio is sensitive; iCloud sync between Angelica's devices only |
| Cloud-first by default | Local (Ollama, whisper.cpp) is always the default; cloud providers require explicit user configuration per modality |
| Cloud audio storage | Audio lives in the Obsidian vault; iCloud sync between Angelica's devices only; never sent to cloud storage (only routed through cloud models transiently when user opts in) |
| Real-time collaboration | Single-user app; collaboration = accounts + websockets + conflict resolution |
| Account system / authentication | Single-user; vault path is the only configuration |
| In-app purchase / subscription | Not monetized; payment infra adds complexity with zero user value |
| Social sharing / community | Lectures are private; export via Obsidian's native share is sufficient |
| Browser extension | Wrong platform; lectures are captured via microphone |
| Web app | Apple-native mandate; web app = server + hosting + auth |
| Android / Windows support | Apple ecosystem only by design |
| Cloud-based speaker identification | Single-lecturer assumption in v1; diarization is v2 |
| Real-time live transcript display | Deliberate RAM tradeoff; live ASR competes with recording for resources on 8GB |
| Video / slide capture | Audio is the primary signal; Vision OCR is v2 |
| Custom note editor | Obsidian IS the editor; unibrain writes Markdown, Obsidian renders |
| Multi-user / shared vault | Single-user app; Angelica's vault is hers |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| FOUND-05 | Phase 1 | Complete |
| FOUND-06 | Phase 1 | Complete |
| DISC-01 | Phase 1 | Complete |
| DISC-02 | Phase 1 | Complete |
| DISC-03 | Phase 1 | Complete |
| WRITE-01 | Phase 2 | Complete |
| WRITE-02 | Phase 2 | Complete |
| WRITE-03 | Phase 2 | Complete |
| WRITE-04 | Phase 2 | Complete |
| WRITE-05 | Phase 2 | Complete |
| WRITE-06 | Phase 2 | Complete |
| CAPT-01 | Phase 3 | Complete |
| CAPT-02 | Phase 3 | Complete |
| CAPT-04 | Phase 3 | Complete |
| CAPT-05 | Phase 3 | Complete |
| CAPT-06 | Phase 3 | Complete |
| TRAN-01 | Phase 3 | Complete |
| TRAN-02 | Phase 3 | Complete |
| TRAN-03 | Phase 3 | Complete |
| TRAN-04 | Phase 3 | Complete |
| TRAN-05 | Phase 3 | Pending |
| TRAN-06 | Phase 3 | Complete |
| CLAS-01 | Phase 4 | Pending |
| CLAS-02 | Phase 4 | Pending |
| CLAS-03 | Phase 4 | Pending |
| CLAS-04 | Phase 4 | Pending |
| CLAS-05 | Phase 4 | Pending |
| CLAS-06 | Phase 4 | Pending |
| CLAS-07 | Phase 4 | Pending |
| ONBD-02 | Phase 4 | Pending |
| ONBD-03 | Phase 4 | Pending |
| CAPT-03 | Phase 5 | Pending |
| ONBD-01 | Phase 5 | Pending |
| ONBD-04 | Phase 5 | Pending |
| ONBD-05 | Phase 5 | Pending |
| DISC-04 | Phase 5 | Pending |
| SUMM-01 | Phase 6 | Pending |
| SUMM-02 | Phase 6 | Pending |
| SUMM-03 | Phase 6 | Pending |
| SUMM-04 | Phase 6 | Pending |
| SUMM-05 | Phase 6 | Pending |
| SUMM-06 | Phase 6 | Pending |
| SUMM-07 | Phase 6 | Pending |
| CLOUD-01 | Phase 6 | Pending |
| CLOUD-02 | Phase 6 | Pending |
| CLOUD-03 | Phase 6 | Pending |
| CLOUD-04 | Phase 6 | Pending |
| CLOUD-05 | Phase 6 | Pending |
| CLOUD-06 | Phase 6 | Pending |
| CLOUD-07 | Phase 6 | Pending |
| CLOUD-08 | Phase 6 | Pending |
| CLOUD-09 | Phase 6 | Pending |
| CLOUD-10 | Phase 6 | Pending |
| CLOUD-11 | Phase 6 | Pending |
| CLOUD-12 | Phase 6 | Pending |
| CLOUD-13 | Phase 6 | Pending |
| DISC-05 | Phase 6 | Pending |
| DISC-06 | Phase 6 | Pending |

**Coverage:**

- v1 requirements: 62 total (corrected from earlier "53" which predated cloud-provider additions)
- Mapped to phases: 62
- Unmapped: 0

**Phase distribution:**

- Phase 1 (Foundation): 9 requirements
- Phase 2 (Pure Pipeline Logic): 6 requirements
- Phase 3 (macOS Capture + Transcribe): 11 requirements
- Phase 4 (Course Classification + Smart Routing): 9 requirements
- Phase 5 (iOS Capture + iCloud Handoff + Onboarding): 5 requirements
- Phase 6 (Gated Summarization + Cloud Providers + MVP Polish): 22 requirements

---
*Requirements defined: 2026-07-13*
*Last updated: 2026-07-13 after roadmap creation*
