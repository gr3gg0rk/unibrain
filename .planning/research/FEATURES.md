# Feature Landscape

**Domain:** Local-first, Apple-native lecture capture + study assistant (single-user, Obsidian-primary)
**Researched:** 2026-07-13
**Overall confidence:** MEDIUM (web-sourced competitor analysis, cross-checked across multiple products)

## Competitive Landscape Surveyed

| Product | Core Value | Cloud/Local | Relevance to unibrain |
|---------|-----------|-------------|----------------------|
| **Otter.ai** | Real-time cloud transcription + summary for meetings/lectures | Cloud-first, subscription | High — feature benchmark for transcription/summary UX |
| **Apple Notes (iOS 26)** | Native audio recording + transcript + AI summary in Notes app | On-device (Apple Intelligence) | Critical — this is the native competitor that ships free on Angelica's devices |
| **Notion AI** | AI meeting notes: transcript, speaker ID, action items, summary | Cloud-first | Medium — summary/action-item patterns, but wrong storage model |
| **Notability** | Audio-synced handwritten notes, iPad-first | Cloud/iCloud sync | High — gold standard for audio+notes sync playback |
| **GoodNotes** | Note Replay audio sync, Study Sets flashcards, organization | iCloud sync | High — study aids + organization patterns |
| **Reflect** | Backlinked daily notes, AI-assisted linking | Cloud (local cache) | Low — different niche (personal knowledge, not capture) |
| **Supernotes** | Notecards with FSRS spaced repetition, collaborative | Cloud-first | Medium — study mode patterns and FSRS reference |
| **Snipd** | Headphone-tap highlight capture, AI snipping, export to Obsidian/Readwise | Cloud + local | Medium — hands-free capture UX is directly transferable |
| **Plaud NotePin** | Wearable one-press recorder, AI summary, Obsidian export workflows | Cloud transcription (Whisper API) | Medium — hardware capture + Obsidian export pipeline precedent |
| **Obsidian plugins** | Whisper ASR, Audio Recorder, AI Transcription Summary | Local (plugin-dependent) | High — shows what the Obsidian ecosystem already does ad hoc |

---

## Table Stakes

Features users expect from a lecture capture app. Missing any of these makes the app feel broken or inferior to free alternatives (especially Apple Notes iOS 26).

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **One-tap start/stop recording** | Otter, Apple Notes, Voice Memos all do this. Friction here = user abandons app. | S | Primary action. Must work from app open, no menu navigation. |
| **Pause/resume recording** | Notability, Otter, Apple Notes all support this. Single contiguous file with pause gaps is expected. | S | Maintain single audio file; mark pause/resume timestamps for playback. |
| **Background recording (iOS)** | Lectures run 50-90 min; screen can't stay on. AVAudioSession background mode is table stakes. | M | Requires background audio entitlement; must show recording indicator on lock screen (like Voice Memos). |
| **Recording timer / live waveform** | Visual confirmation that recording is active. Every competitor has this. | S | SwiftUI Canvas or UIViewRepresentable for waveform. Timer is trivial. |
| **Audio quality indicator** | Mic level meter so user knows the mic is actually picking up the lecturer. Notability and Otter show this. | S | AVAudioEngine tap on input bus, render level meter. |
| **Automatic transcription** | This is THE feature. Otter, Apple Notes iOS 26, Notion AI all auto-transcribe. Without it, unibrain is just Voice Memos. | L | whisper.cpp + Metal on-device. Core loop. |
| **Transcript is readable** | Raw ASR output is messy. Paragraph breaks, punctuation, capitalization must be handled. whisper.cpp handles punctuation; paragraph segmentation needs post-processing. | M | Post-process whisper segments into logical paragraphs by time gaps. |
| **Transcript editing** | ASR is imperfect on technical terms, names, accents. Otter, Apple Notes, Notability all allow post-edit. | M | In-place edit of transcript text in the note. Keep original audio for reference. |
| **Summary / key points** | Apple Notes iOS 26 does this natively. Otter does this. Notion does this. If unibrain doesn't summarize, Apple Notes wins. | L | Ollama local LLM, gated (off by default for RAM). Generates key points from transcript. |
| **Note saved to the right place** | User should never have to manually file a recording. This is unibrain's core differentiator but ALSO table stakes because the alternative (manual filing) is the baseline expectation of any note app. | M | Calendar classification → folder routing. If this fails, the app has failed. |
| **Searchable transcript text** | Otter's killer feature. User needs to find "when did the prof explain X?" by searching transcript. | S | Obsidian handles this natively (full-text search of Markdown files). Just write transcript as text in the note. |
| **Audio playback synced to transcript** | Notability's signature feature. User taps a word in the transcript → audio jumps to that timestamp. Apple Notes iOS 26 does this. | L | Store word-level timestamps from whisper.cpp segments. Link transcript words to audio position. |
| **Offline operation** | Lecture halls have poor Wi-Fi. Otter (cloud) fails here. Apple Notes (local) works. unibrain MUST work fully offline. | M | All processing on-device. No network calls in the core path. |

---

## Differentiators

Features that give unibrain a competitive advantage specifically because it is **local-first, Apple-native, and Obsidian-primary**. These are things cloud competitors cannot or will not do.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Schedule-aware course classification** | No competitor does this. Otter dumps everything in one list. Notability needs manual notebook selection. Apple Notes has no concept of "courses." unibrain reads the calendar and auto-routes. | M | EventKit query: find calendar event overlapping recording start time → extract title/location → map to course folder. This is THE moat. |
| **Unknown course UX with manual override** | When classification fails (no calendar event, schedule conflict), app surfaces a quick picker: "Which course?" with recent courses + search. Graceful degradation. | M | Fallback modal after transcription. Remember manual override for next time. |
| **Multi-term support** | Courses change each semester. Folder structure reflects this: `01-Fall-2026/BIO-101/`. Calendar events tagged by term. | S | Folder naming convention. Settings for "current term" label. |
| **Vault-native storage (no cloud)** | Audio + transcript + summary all live in the Obsidian vault as Markdown + attachments. Angelica owns her data. No subscription, no account, no server. iCloud syncs between her devices only. | S | Write `.md` note + `.m4a` audio attachment to vault folder. Obsidian reads it natively. |
| **Privacy by architecture** | Lecture content never leaves Angelica's devices. No telemetry, no cloud LLM, no analytics. This matters for FERPA compliance, classroom recording ethics, and personal dignity. | S | Architectural property, not a feature to build. But it IS a feature to communicate. |
| **YAML frontmatter metadata** | Every note has structured frontmatter (`course`, `datetime`, `source`, `tags`, `syllabus_link`, `vector_id`) that Obsidian plugins, Dataview, and future Phase 2 tools can consume. | S | Template-based frontmatter generation at note creation. |
| **macOS menu-bar app** | Quick-access recording from the menu bar without opening the full app. One click to start/stop. MenuBarExtra in SwiftUI. Notability doesn't do this; Otter doesn't do this. | M | MenuBarExtra + AVAudioRecorder. Ideal for "open laptop, click menu bar, recording starts." |
| **iOS Action Button / Lock Screen shortcut** | iPhone 15 Pro+ Action Button → start recording without unlocking. Lock Screen widget for older devices. Hands-free-ish start. | M | Shortcuts integration + App Intent. Action Button maps to app intent. |
| **Hands-free bookmark during recording** | Snipd pattern: tap AirPods or shake phone to drop a timestamp bookmark during recording. "Prof just said something important." | M | AVAudioSession tap detection or motion sensor. Bookmark = timestamp + marker in transcript. |
| **RAM-conscious model management** | Only one heavy model (ASR or LLM) loaded at a time. Idle models released immediately. 8GB MacBook Air doesn't OOM. No competitor needs this because they run in the cloud. | M | Process-level model lifecycle: load → use → release. Mutex on heavy-model slot. |
| **Local LLM summarization (gated)** | Summary generated by Ollama running locally. Off by default (RAM). User opts in per-session or per-note. No cloud API call. | L | Ollama integration (small model like qwen2.5:3b or llama3.2:3b). Prompt template for key points extraction. |
| **Regenerate summary** | User edits transcript, wants fresh summary. One-click regenerate from updated transcript. | S | Re-run LLM on updated transcript text. Replace summary section in note. |
| **Tag taxonomy auto-population** | Tags generated from course name + lecture topic keywords. `#bio-101`, `#cell-division`, `#fall-2026`. Obsidian tag system. | M | Course → base tags. Optional LLM keyword extraction for topic tags (Phase 2). |
| **Backlink generation** | "Related lectures" section auto-populated by matching course tag + date proximity. Week 3 lecture links to Week 2 and Week 4. | M | Dataview-compatible frontmatter. Or generate explicit backlinks in note body. |
| **iCloud Drive vault sync (Angelica's devices only)** | Vault syncs between her MacBook, iPhone, iPad Pro via iCloud Drive. No third-party cloud. Obsidian mobile reads the synced vault. | S | File system writes to iCloud Drive container. Obsidian iOS app handles the sync read. |

---

## Anti-Features

Things to deliberately NOT build. These are features competitors have that unibrain explicitly avoids because they conflict with the local-first, single-user, Obsidian-primary mandate.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Cloud audio storage** | Violates local-first mandate. Lecture audio is sensitive. Cloud storage = subscription, account, attack surface, privacy risk. | Store audio as `.m4a` attachment in Obsidian vault. iCloud syncs between Angelica's own devices only. |
| **Cloud transcription API** | Sending lecture audio to OpenAI/Google/Anthropic = privacy violation + cost + latency + dependency. | whisper.cpp + Metal on-device. Always. No exceptions in MVP. |
| **Cloud LLM as primary summary path** | Same privacy concerns. Also unreliable in lecture halls with poor Wi-Fi. | Ollama local LLM, gated off by default. Cloud is a Phase 2+ opt-in escape hatch with explicit per-document consent only. |
| **Real-time collaboration** | Single-user app. Angelica doesn't need to co-edit lecture notes in real time. Collaboration = accounts, websockets, conflict resolution, server. | Notes are plain Markdown files in the vault. If Angelica wants to share, she can share the Obsidian note or export PDF. |
| **Account system / authentication** | Single-user. No login, no password, no session management, no auth tokens. | App is identity-free. Vault path is the only configuration. |
| **In-app purchase / subscription** | Not a product to monetize. Building payment infrastructure adds complexity, Apple review overhead, and zero value for a single user. | Free, open, local. No paywall. |
| **Social sharing / community** | Lectures are private. Sharing features = social graph, permissions, moderation. Anti-privacy. | Export is via Obsidian's native share (PDF, Markdown file). No in-app social surface. |
| **Browser extension** | Wrong platform. Lectures are captured via microphone, not browser tab. Extension = different codebase, different deployment, different permissions. | Native macOS + iOS app only. |
| **Web app** | Apple-native mandate. Web app = server, hosting, auth, browser compatibility. Defeats the purpose. | SwiftUI native on macOS + iOS. |
| **Android / Windows support** | Apple-only by design. Cross-platform = abstraction layers, compromise on native frameworks, doubled maintenance. | Apple ecosystem only (AVFoundation, EventKit, Metal, SpeechAnalyzer). |
| **Cloud-based speaker identification** | Otter does speaker ID via cloud processing. For a lecture, there's typically one speaker (the prof). Speaker ID adds complexity for minimal value. | Single-speaker assumption in MVP. Transcript is one speaker's words. Phase 2 could add simple diarization if needed. |
| **Real-time live transcript display** | Tempting but wrong for MVP. whisper.cpp streaming on 8GB RAM competes with the recording itself for resources. Live display adds UI complexity. Otter does this in the cloud. Apple Notes does this on-device with dedicated hardware. unibrain transcribes post-capture. | Transcribe after recording stops. Transcript appears in note within minutes. This is a deliberate tradeoff for RAM discipline. |
| **Video / slide capture** | Scope creep. Audio is the primary signal. Video = massive storage, Vision framework OCR (Phase 2), camera permissions, battery drain. | Audio-only in MVP. Slide OCR is explicitly Phase 2. |
| **Custom note editor** | Obsidian IS the editor. Building a note editor inside unibrain = competing with Obsidian, which is the wrong fight. | unibrain writes Markdown files. Obsidian renders and edits them. Clear boundary. |

---

## Feature Dependencies

```
Recording (start/stop) → Audio file saved
    ↓
Course classification (calendar lookup) → Folder path determined
    ↓
Transcription (whisper.cpp) → Transcript text generated
    ↓
Note creation (Markdown + frontmatter) → Note written to vault
    ↓
[OPTIONAL] Summary (Ollama LLM, gated) → Summary section appended to note
    ↓
[OPTIONAL] Sync (iCloud Drive) → Note appears on iPhone/iPad

Onboarding flow:
    Permissions:
    ├── Microphone permission → required for recording
    ├── Calendar permission (EventKit) → required for course classification
    └── Folder access (vault path) → required for note writing
    First-run:
    └── Vault folder picker → sets default write location
```

**Critical dependency:** Course classification depends on Calendar permission. If denied, fall back to manual course picker (table stakes "unknown course UX").

---

## MVP Cut Line: "Record-to-Obsidian" Loop

The MVP delivers one thing end-to-end: **press record → get a structured note in the right course folder with transcript.**

### MVP Must Include (Phase 1)

| Feature | Complexity | Rationale |
|---------|------------|-----------|
| One-tap start/stop recording (macOS + iOS) | S | Primary action, no app without it |
| Pause/resume | S | Expected behavior |
| Background recording | M | Lectures are long; screen can't stay on |
| Recording timer + mic level indicator | S | Visual confirmation |
| Course classification via EventKit | M | THE differentiator; core value prop |
| Manual course picker fallback | M | Graceful degradation when calendar fails |
| whisper.cpp transcription (post-capture) | L | Core loop |
| Transcript written to Obsidian note | S | Output of the loop |
| YAML frontmatter (course, datetime, source, tags) | S | Vault-native metadata |
| Audio attachment saved alongside note | S | Playback reference |
| Vault folder picker (onboarding) | S | Where do notes go? |
| Microphone + Calendar permissions (onboarding) | S | Required for core loop |
| RAM-conscious model lifecycle | M | 8GB MacBook Air constraint |

### MVP Should Include (Phase 1, if time permits)

| Feature | Complexity | Rationale |
|---------|------------|-----------|
| Gated LLM summary (off by default) | L | Apple Notes iOS 26 has this; unibrain needs parity |
| Summary regenerate | S | Natural follow-on |
| macOS menu-bar quick record | M | Best UX for the MacBook use case |
| Settings: vault path, calendar source, model selection | S | User agency |

### MVP Explicitly Defers (Phase 2+)

| Feature | Phase | Rationale |
|---------|-------|-----------|
| Audio-transcript playback sync | Phase 2 | Complex (word-level timestamps); valuable but not launch-blocking |
| Hands-free bookmark during recording | Phase 2 | Snipd pattern; nice-to-have |
| iOS Action Button / Lock Screen shortcut | Phase 2 | Requires App Intent engineering; menu-bar first |
| Tag taxonomy auto-population (LLM) | Phase 2 | Depends on LLM running smoothly |
| Backlink generation | Phase 2 | Depends on accumulated lecture history |
| PDF / whiteboard photo OCR | Phase 2 | Vision framework; explicitly scoped out |
| Local embeddings + semantic search | Phase 2 | SQLite/FAISS index |
| Quiz generation / flashcards (FSRS) | Phase 2 | Study aids layer |
| Spaced repetition study mode | Phase 2 | FSRS algorithm integration |
| Syllabus parsing + milestone tracking | Phase 2 | Structured data extraction |
| Hermes daily-ingest QA + Study Pack | Phase 2+ | Infrastructure layer |

---

## Capture UX Detail

### Start/Stop Patterns (by platform)

| Platform | Primary Trigger | Secondary Trigger | Tertiary |
|----------|----------------|-------------------|----------|
| **macOS** | Menu bar icon click → dropdown → Record button | Keyboard shortcut (Cmd+Shift+R) | Dock icon click → app window → big Record button |
| **iOS** | App open → big Record button | Action Button (iPhone 15 Pro+) → App Intent | Lock Screen widget (Phase 2) |

### Recording State Indicators

- **macOS menu bar**: Icon changes (dot = idle, pulsing red = recording, spinner = transcribing)
- **iOS**: Standard iOS recording indicator (orange dot in status bar + Dynamic Island if available)
- **Both**: In-app timer + live waveform during recording

### Post-Capture Flow

```
User taps Stop
    ↓
"Saving..." indicator (classification + transcription running)
    ↓
Classification result shown: "Saved to BIO 101 > Lecture 3"
    ↓
[If uncertain] "Which course?" picker modal
    ↓
"Transcribing..." progress (estimated time based on audio length)
    ↓
"Done. Note in vault." → tap to open in Obsidian
    ↓
[If summary enabled] "Summarizing..." → summary appended
```

---

## Course Classification Detail

### Auto-Classification Logic

1. On recording start, query EventKit for events overlapping `recordingStart ± 30min`
2. If exactly one event found → extract event title as course name
3. Map course name to folder via settings (course → folder mapping table)
4. If no mapping exists → create new folder using sanitized course name
5. Auto-populate frontmatter: `course`, `datetime`, `tags` (from course name)

### Conflict Handling

| Scenario | Resolution |
|----------|-----------|
| No calendar event found | Manual course picker (recent courses + search) |
| Multiple overlapping events | Picker showing both options |
| Event found but no folder mapping | Auto-create folder from event title |
| Recording starts 15+ min before/after event | Still matches (buffer window) |
| Recording spans two events (back-to-back classes) | Picker: "Which class was this?" |

### Multi-Term Support

- Folder convention: `{term}/{course-code}/` (e.g., `Fall-2026/BIO-101/`)
- Settings: "Current term" label, updated manually each semester
- Old term folders remain; new term gets clean slate
- Calendar events from past terms are ignored for classification

---

## Transcript UX Detail

### What the User Sees

- Transcript appears in the note body as plain text paragraphs
- No live display during recording (deliberate tradeoff for RAM)
- After transcription completes, transcript is visible in Obsidian
- User can edit transcript text directly in Obsidian (it's just Markdown)

### Confidence Indicators

- whisper.cpp provides per-segment confidence; low-confidence segments could be visually marked
- MVP: no confidence indicators (keep it simple)
- Phase 2: highlight low-confidence segments in a subtle color

### Speaker Labels

- MVP: single-speaker assumption (the lecturer). No diarization.
- Transcript is one continuous block from one speaker.
- Phase 2: simple diarization if needed (professor vs. student questions)

---

## Summary UX Detail

### Where the Summary Lands

- **Same note, dedicated section** (below transcript, under `## Summary` heading)
- Rationale: keeps everything in one place; user doesn't manage two notes per lecture
- The note structure:
  ```
  ---
  (YAML frontmatter)
  ---
  
  # Lecture: {date} - {course}
  
  ## Summary
  (Ollama-generated key points, bullet list)
  
  ## Transcript
  (Full whisper.cpp transcript, paragraph breaks)
  ```

### Edit Override + Regenerate

- User can edit the summary directly (it's Markdown)
- "Regenerate Summary" action in the app re-runs Ollama on the (possibly edited) transcript
- Regenerate replaces the Summary section, preserving user edits to Transcript

### Summary Format

- **Bullet list of key points** (5-8 bullets max for a 60-min lecture)
- Not flashcards (Phase 2), not paragraph prose, not action items
- Prompt template emphasizes "key concepts and definitions a student needs to know"

---

## Vault Integration Detail

### Folder Structure

```
Angelica-Vault/
├── Fall-2026/
│   ├── BIO-101/
│   │   ├── 2026-09-03-BIO-101-Lecture.md
│   │   ├── 2026-09-03-BIO-101-Lecture.m4a
│   │   ├── 2026-09-05-BIO-101-Lecture.md
│   │   └── 2026-09-05-BIO-101-Lecture.m4a
│   ├── CHEM-110/
│   │   └── ...
│   └── MATH-200/
│       └── ...
└── Spring-2027/
    └── ... (next term)
```

### Naming Convention

`YYYY-MM-DD-{COURSE}-Lecture.md` — date-first for chronological sorting, course code for identification.

### Attachment Handling

- Audio file (`.m4a`) sits alongside the `.md` file in the same folder
- Referenced in the note via Obsidian wiki-link or standard Markdown: `![[2026-09-03-BIO-101-Lecture.m4a]]`
- Obsidian treats it as an attachment; playable inline

### Frontmatter Schema

```yaml
---
course: BIO-101
course_name: Introduction to Biology
term: Fall-2026
datetime: 2026-09-03T14:00:00-07:00
duration_seconds: 3120
source: lecture-recording
audio_file: 2026-09-03-BIO-101-Lecture.m4a
tags:
  - bio-101
  - fall-2026
  - lecture
syllabus_link: null  # Phase 2
vector_id: null       # Phase 2
summary_model: null   # null = no summary, or model name if summarized
---
```

---

## Settings Surface Detail

| Setting | Type | Default | Notes |
|---------|------|---------|-------|
| Vault path | Folder picker | `~/Documents/Angelica-Vault/` | Where notes are written |
| Current term label | Text | `Fall-2026` | Used in folder path |
| Whisper model | Dropdown | `small.en` | Options: `tiny.en`, `base.en`, `small.en` |
| Summary enabled | Toggle | OFF | Gated for RAM discipline |
| Summary model | Dropdown | `qwen2.5:3b` | Only visible if summary enabled |
| Calendar source | System picker | All calendars | Which calendars to query for classification |
| iCloud sync | Toggle | ON | Whether vault folder is in iCloud Drive |
| Course mapping | Table | (auto-generated) | Course name → folder name mapping, editable |

---

## Onboarding Flow Detail

### First-Run Sequence

```
1. Welcome screen: "unibrain records lectures and puts them in your Obsidian vault."
    ↓
2. "Where should notes go?" → Folder picker (suggest iCloud Drive location)
    ↓
3. "Allow microphone access?" → System permission prompt
    ↓
4. "Allow calendar access?" → System permission prompt (for course classification)
    ↓
5. "What term are you in?" → Text input (default: "Fall-2026")
    ↓
6. "Ready! Press the record button to capture your first lecture."
```

### Permission Handling

| Permission | Denied Behavior |
|-----------|----------------|
| Microphone | App cannot function. Show explanation + link to Settings. |
| Calendar | App works but requires manual course selection every time. Show explanation: "Without calendar access, you'll pick the course manually after each recording." |
| Folder access | App cannot write notes. Must pick a valid folder. |

---

## Phase 2 Study Aids (Context Only)

Deferred from MVP but researched for roadmap planning:

| Study Aid | Mechanism | Phase 2 Complexity | Notes |
|-----------|-----------|-------------------|-------|
| **Flashcard generation** | LLM extracts Q&A pairs from transcript | L | Depends on stable LLM summary path |
| **Spaced repetition (FSRS)** | FSRS algorithm schedules card review | M | FSRS is open-source; Supernotes and Anki use it. Obsidian plugins exist. |
| **Quiz generation** | LLM generates multiple-choice quiz from lecture content | L | Similar to flashcard generation |
| **Semantic search** | Embeddings index over all lecture transcripts | L | SQLite + embeddings model. "When did prof mention mitochondria?" |
| **Cross-lecture connections** | Embeddings-based similarity linking | M | "This concept was also covered in Lecture 3" |

**Key reference:** A native FSRS plugin for Obsidian with AI flashcard generation was built in 2025 ([Obsidian Forum](https://forum.obsidian.md/t/i-built-a-native-fsrs-algorithm-for-obsidian-with-ai-flashcard-generation/109962)), confirming the pattern is viable. unibrain's Phase 2 can either build this natively or generate cards that the existing Obsidian spaced repetition plugins consume.

---

## Sources

- [Otter.ai official](https://otter.ai/) — cloud transcription, real-time, speaker ID, summaries (MEDIUM confidence, web)
- [Apple Newsroom: Apple Intelligence expansion](https://www.apple.com/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/) — Apple Notes audio transcription + summary in iOS 26 (HIGH confidence, official Apple)
- [Apple Support: Apple Intelligence in Notes](https://support.apple.com/guide/iphone/use-apple-intelligence-in-notes-iph59143007d/ios) — recording + transcript + summary workflow (HIGH confidence, official Apple)
- [WWDC25 Session 277: SpeechAnalyzer API](https://developer.apple.com/videos/play/wwdc2025/277/) — new developer API for speech-to-text (HIGH confidence, official Apple)
- [WWDC25 Session 251: Audio Recording](https://developer.apple.com/videos/play/wwdc2025/251/) — audio recording improvements (HIGH confidence, official Apple)
- [Notion AI Meeting Notes](https://www.notion.com/product/ai-meeting-notes) — transcript, speaker ID, action items, summary (MEDIUM confidence, vendor)
- [Supernotes flashcards + FSRS](https://supernotes.app/features/flashcard-layout/) — spaced repetition, cram/standard/relaxed paces (MEDIUM confidence, vendor)
- [Snipd hands-free capture](https://www.snipd.com/blog/how-to-take-notes-from-podcasts-during-workouts) — triple-tap headphone highlight, AI snipping (MEDIUM confidence, vendor)
- [Plaud NotePin to Obsidian workflow](https://www.reddit.com/r/PLAUDAI/comments/1o1fg87/automation_showcase_plaud_to_obsidian/) — real-world Plaud → Obsidian automation (LOW confidence, Reddit)
- [Obsidian AI Audio Transcription plugin](https://community.obsidian.md/plugins/ai-audio-transcription-summary) — local Whisper transcription in Obsidian (MEDIUM confidence, community)
- [Obsidian FSRS plugin with AI flashcards](https://forum.obsidian.md/t/i-built-a-native-fsrs-algorithm-for-obsidian-with-ai-flashcard-generation/109962) — native FSRS in Obsidian (MEDIUM confidence, community)
- [whisper.cpp on macOS with Metal](https://dev.to/thehwang/building-a-100-local-meeting-transcription-app-for-macos-with-whispercpp-and-screencapturekit-33m7) — >15x real-time on Apple Silicon (MEDIUM confidence, dev blog)
- [WhisperKit vs whisper.cpp comparison](https://cactuscompute.com/compare/argmax-vs-whisper-cpp) — Metal, CoreML, GGML quantization (MEDIUM confidence, comparison site)
- [MenuBarExtra documentation](https://developer.apple.com/documentation/swiftui/menubarextra) — macOS menu bar pattern (HIGH confidence, official Apple)
- [EventKit documentation](https://developer.apple.com/documentation/eventkit) — calendar access framework (HIGH confidence, official Apple)
- [Notability vs GoodNotes comparison](https://paperlike.com/blogs/paperlikers-insights/app-review-goodnotes-vs-notability) — audio sync, Note Replay (MEDIUM confidence, review site)
- [Local-first lecture recording advantages](https://aidictation.com/blog/lecture-recording-app) — privacy, offline, data sovereignty (MEDIUM confidence, vendor blog)
- [iOS Action Button recording](https://www.idownloadblog.com/2026/01/07/start-voice-recording-quickly-iphone/) — lock-screen recording via Action Button (MEDIUM confidence, tech blog)
- [Lock Screen Shortcut widget](https://recorderplus.com/?ht_kb=start-recording) — lock screen widget for recording (LOW confidence, vendor)
