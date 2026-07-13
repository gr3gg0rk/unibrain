# Stack Research

**Domain:** Local-first Apple-native lecture capture + study assistant (SwiftUI multiplatform)
**Researched:** 2026-07-13
**Confidence:** HIGH (core stack) / MEDIUM (version-specific details)

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Swift** | 6.0+ (Xcode 16+) | Primary language | Swift 6.0 brings data-race safety, structured concurrency (`async/await`, `Actor`), and the best C-interop for binding whisper.cpp. Swift 6 strict concurrency is essential for safe model load/unload gating on 8GB. | HIGH |
| **SwiftUI** | iOS 17+ / macOS 14+ | UI framework (declarative) | Apple's default for new apps. `DocumentGroup`, `NavigationSplitView`, and `@Observable` (iOS 17+) are the right primitives for a document-heavy lecture capture app. Native on all target devices. | HIGH |
| **Xcode Multiplatform Target** | Xcode 16+ | Single target for macOS + iOS | Apple's recommended path for shared SwiftUI codebase. NOT Mac Catalyst — use native multiplatform (Cocoa) targets. `#if os(macOS)` / `#if os(iOS)` for platform-specific code. | HIGH |

**Key architecture decision: Multiplatform target, NOT Mac Catalyst.**
Mac Catalyst wraps a UIKit-iOS app for macOS and introduces abstraction friction with native macOS features (NSWindow, menu bar, file system access patterns needed for Obsidian vault writes). A native multiplatform target shares SwiftUI views and business logic while giving each platform its native container.

### Audio Capture (AVFoundation)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **AVAudioRecorder** | iOS 17+ / macOS 14+ | Microphone recording to file | Standard Apple audio recording API. Supports WAV (PCM) and M4A (AAC) output. Works across both platforms with platform-specific session configuration. | HIGH |
| **AVAudioSession** | iOS 17+ / macOS 14+ | Session/category management | `.playAndRecord` category with `.default` mode for lecture capture. On iOS, requires `UIBackgroundModes: ["audio"]` for background recording. | HIGH |

**Recording configuration for whisper.cpp compatibility:**
- Sample rate: **16000 Hz** (whisper.cpp native rate — avoids resampling)
- Channels: **1** (mono — lectures are single-source)
- Format: **WAV (LinearPCM)** for best ASR accuracy, or **M4A (AAC)** for smaller files
- Bit depth: **16-bit** (PCM)

**iOS background recording constraint:** iOS will suspend recording when backgrounded unless `UIBackgroundModes` includes `audio` AND the audio session is actively recording. Even then, iOS may kill the app under memory pressure. For lecture-length recordings (60-90 min), the app must stay foregrounded on iPhone or use a background task with audio session activation. This is a platform limitation, not a library choice.

**macOS recording:** No background restriction. NSWindow-based UI can minimize while recording continues. Microphone permission via TCC (`NSMicrophoneUsageDescription`).

### Transcription (whisper.cpp + Metal)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **whisper.cpp** | v1.7.x+ (target v1.9.x) | Local ASR inference engine | Best accuracy/footprint tradeoff on 8GB. C/C++ library with Metal + CoreML acceleration. 4.4x speedup with Metal on Apple Silicon. Mature, actively maintained under ggml-org. | HIGH |
| **SwiftWhisper** (exPHAT) | Latest (SPM) | Swift wrapper for whisper.cpp | Zero-dependency SPM package wrapping whisper.cpp. Easiest integration path. Includes pre-built whisper.cpp via SPM — no manual C compilation. | MEDIUM |
| **Metal acceleration** | Built into whisper.cpp | GPU acceleration on Apple Silicon | whisper.cpp has native Metal support via `GGML_USE_METAL=1`. Encoder runs on GPU, decoder on CPU. No separate Metal framework integration needed. | HIGH |
| **CoreML encoder** (optional) | Built into whisper.cpp | ANE acceleration for encoder | whisper.cpp supports CoreML encoder models for Apple Neural Engine execution. ~3x speedup over CPU-only. Requires pre-converted CoreML model files. | MEDIUM |

**Model selection for 8GB MacBook Air:**

| Model | Disk Size | Runtime RAM | Accuracy (WER) | Inference Speed (Metal) | Recommendation |
|-------|-----------|-------------|----------------|------------------------|----------------|
| tiny.en | 75 MiB | ~273 MB | ~8-12% | Very fast (~10x realtime) | Fallback only |
| base.en | 142 MiB | ~388 MB | ~6-8% | Fast (~5x realtime) | Acceptable for clear audio |
| **small.en** | **466 MiB** | **~852 MB** | **~4-5%** | **~3x realtime** | **Recommended sweet spot** |
| medium.en | 1.5 GiB | ~2.1 GB | ~3-4% | ~1.5x realtime | Too slow/heavy for 8GB |

**Recommendation: `small.en` model.** At ~852 MB runtime RAM, it leaves 7+ GB for OS + app + Ollama. Accuracy is significantly better than base.en for technical/academic vocabulary. Enable Metal acceleration for ~3x realtime (a 60-min lecture transcribes in ~20 min).

**8GB RAM budget math (whisper.cpp + OS + app):**
- macOS base: ~3-4 GB
- App + SwiftUI: ~200-400 MB
- whisper.cpp small.en: ~852 MB
- **Total: ~5.3 GB** → 2.7 GB headroom. Safe.

**Binding pattern:** Use SwiftWhisper SPM package as the primary integration path. If SwiftWhisper's whisper.cpp version lags, fork or use the official whisper.cpp SPM package from the main repo (ggml-org/whisper.cpp supports SPM natively for iOS). Access via C interop — the Swift wrapper handles bridging.

### LLM Summarization (Ollama)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Ollama** | 0.3+ (current) | Local LLM runtime | Manages model lifecycle, quantization, and exposes HTTP API at `localhost:11434`. Handles model loading/unloading natively. Angelica installs Ollama as a separate app; unibrain calls its HTTP API. | HIGH |
| **Ollama HTTP API** | Stable | Integration interface | `POST /api/generate` for single-turn summarization. `POST /api/chat` for multi-turn. `keep_alive` parameter controls RAM: set to `0` to unload immediately after inference, `-1` to keep in memory. | HIGH |

**Model selection for 8GB (loaded alongside or after ASR):**

| Model | Params | Quantized RAM | Quality | Download Size | Recommendation |
|-------|--------|---------------|---------|---------------|----------------|
| **llama-3.2-3b** | 3B | ~4-5 GB (Q4) | Best all-rounder | ~2 GB | **Recommended** — best quality/size ratio |
| phi-3.5-mini | 3.8B | ~4-6 GB (Q4) | Good reasoning | ~2.2 GB | Alternative — stronger on structured tasks |
| gemma-2-2b | 2B | ~3-4 GB (Q4) | Lightest viable | ~1.6 GB | Fallback — weaker summarization quality |

**Recommendation: `llama-3.2-3b` (4-bit quantized).** Best quality-to-footprint ratio. At ~4-5 GB, it fits 8GB when whisper.cpp is already unloaded.

**Critical gating pattern — never run ASR + LLM simultaneously on 8GB:**
```
1. Record audio
2. Unload Ollama model (keep_alive: 0) if loaded
3. Load whisper.cpp small.en (~852 MB)
4. Transcribe
5. Unload whisper.cpp model
6. [User opts in to summarization]
7. Ollama loads llama-3.2-3b (~4-5 GB)
8. Generate summary
9. Unload Ollama model (keep_alive: 0)
10. Write Markdown note to vault
```

**8GB RAM budget math (Ollama alone):**
- macOS base: ~3-4 GB
- App + SwiftUI: ~200-400 MB
- llama-3.2-3b Q4: ~4-5 GB
- **Total: ~8.4 GB** → Tight. Will use swap. Acceptable for short inference bursts (summary generation ~30-60 seconds). NOT acceptable for continuous operation.

**Why HTTP API, not swift-llm or llama.cpp Swift bindings:**
- **Ollama HTTP API:** Angelica manages Ollama as a user-installed app. unibrain is a thin client. Model lifecycle, quantization, GPU acceleration — all handled by Ollama. Clean separation of concerns. MEDIUM complexity.
- **swift-llm / llama.cpp Swift bindings:** Would embed the LLM engine inside unibrain. More control but significantly more complexity (model loading, memory management, quantization). Justified only if Ollama's overhead is unacceptable. HIGH complexity.
- **Decision:** HTTP API for MVP. If latency or overhead becomes a problem, evaluate direct bindings in Phase 2.

### Calendar Integration (EventKit)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **EventKit** | iOS 17+ / macOS 14+ | Read-only calendar access | Apple's standard framework for calendar data. `EKEventStore` with `requestFullAccessToEvents(completion:)` (iOS 17+ API). Read course schedule → map recording timestamp to course. | HIGH |

**Permission flow (iOS 17+ / macOS 14+):**
1. Add `NSCalendarsUsageDescription` to Info.plist (required)
2. Add `NSCalendarsFullAccessUsageDescription` for iOS 17+ specifically
3. Call `eventStore.requestFullAccessToEvents { granted, error in }`
4. Permission states: `.notDetermined`, `.fullAccess`, `.writeOnly`, `.denied`
5. OS shows prompt only once; subsequent calls return cached status
6. For read-only course resolution, request `.fullAccess` (no `.readOnly` tier exists for events — write-only is a separate lower tier)

**Note:** The deprecated `requestAccess(to:completion:)` was replaced in iOS 17/macOS 14. Always use `requestFullAccessToEvents`.

### Obsidian Vault Write-Out

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **FileManager** (Foundation) | Built-in | File system writes to vault | Standard Swift file I/O. Write Markdown + YAML frontmatter directly to the vault folder. No Obsidian plugin API needed — plain files. | HIGH |
| **Yams** | 6.2.2 | YAML frontmatter serialization | Mature, stable YAML encoder/decoder for Swift. Built on LibYAML. SPM: `.package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")`. Required Xcode 14.0+/Swift 5.7+. | HIGH |

**Vault folder structure convention (for unibrain-generated notes):**
```
Vault/
├── Courses/
│   ├── BIO-101/
│   │   ├── 2026-09-15-bio-101-lecture-03.md
│   │   ├── 2026-09-17-bio-101-lecture-04.md
│   │   └── attachments/
│   │       └── audio/
│   │           └── 2026-09-15-bio-101-lecture-03.m4a
│   ├── CHEM-201/
│   │   └── ...
├── Templates/
│   └── lecture-template.md
├── Attachments/  (Obsidian default)
└── .obsidian/    (Obsidian config — do NOT write here)
```

**YAML frontmatter schema (per note):**
```yaml
---
course: "BIO-101"
course_name: "Introductory Biology"
datetime: 2026-09-15T14:00:00-07:00
source: lecture
audio_file: "attachments/audio/2026-09-15-bio-101-lecture-03.m4a"
duration_seconds: 5400
tags:
  - lecture
  - bio-101
syllabus_link: ""
vector_id: ""  # Phase 2
summary_generated: false  # set true after Ollama runs
---
```

### CI/CD (GitHub Actions macOS)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **GitHub Actions** | macos-15 runner | Build + test Swift from WSL2 | No Mac in dev loop. macOS runners provide the only native build/test path. `macos-15` is current `macos-latest` (migrated Aug 2025). | HIGH |
| **Xcode** | 16+ (on macos-15) | Swift compilation | macos-15 runners ship with Xcode 16.x. Required for Swift 6.0 concurrency features. | HIGH |

**Runner economics (hobby project):**
- **Public repo:** macOS runners are FREE (no minute consumption)
- **Private repo:** 10x minute multiplier. 3,000 included minutes = ~300 actual macOS build minutes/month
- **Recommendation:** Use a **public repo** for unibrain (hobby project, no secrets, no proprietary code). This gives unlimited free macOS CI.

**macos-26 is available** as of Feb 2026 GA, with `macos-latest` migrating around June 15, 2026. For July 2026, pin to `macos-15` explicitly to avoid surprise migration. Transition to `macos-26` when Angelica's devices are confirmed on macOS 26 / iOS 26.

**Workflow pattern:**
```yaml
# .github/workflows/ci.yml
runs-on: macos-15
steps:
  - uses: actions/checkout@v4
  - name: Select Xcode
    run: sudo xcode-select -switch /Applications/Xcode_16.0.app
  - name: Build
    run: xcodebuild build -scheme unibrain -destination 'platform=macOS'
  - name: Test
    run: xcodebuild test -scheme unibrain -destination 'platform=macOS'
```

### Supporting Libraries

| Library | Version | Purpose | When to Use | Confidence |
|---------|---------|---------|-------------|------------|
| **Yams** | 6.2.2 | YAML frontmatter serialization | Every note write. Encodes the frontmatter dict to YAML string. | HIGH |
| **SwiftWhisper** | Latest (SPM) | whisper.cpp Swift wrapper | Transcription. Alternative: use whisper.cpp SPM package directly from ggml-org/whisper.cpp. | MEDIUM |
| **zip** (Foundation) | Built-in | Compress model files for transport | Bundling whisper.cpp models if needed. ZIPFoundation SPM package if more control needed. | LOW |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **Xcode 16+** (on GitHub Actions) | Build, test, archive | Only available on macOS runners. No Mac in home lab. |
| **Swift Package Manager** | Dependency management | Primary mechanism. Add Yams, SwiftWhisper, etc. via SPM. |
| **GitHub Actions** | CI/CD | macos-15 runner. Free in public repos. |
| **Obsidian** | Vault verification | Install on WSL2 (cross-platform build) for frontmatter rendering testing. Not for app testing. |
| **Ollama** | LLM runtime (dev testing) | Install on WSL2 for API endpoint testing. Not a build dependency. |

---

## Installation

```swift
// Package.swift dependencies (or via Xcode > Add Package Dependencies)
.package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),

// For whisper.cpp integration, two options:
// Option A: SwiftWhisper wrapper (simpler)
.package(url: "https://github.com/exPHAT/SwiftWhisper.git", from: "latest"),

// Option B: whisper.cpp official SPM (more control)
// .package(url: "https://github.com/ggml-org/whisper.cpp.git", from: "v1.7.0"),
```

**Note:** There is no npm/pip install step. This is a Swift project managed entirely through SPM and built via Xcode on GitHub Actions macOS runners.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not (or When to Use Alternative) |
|----------|-------------|-------------|--------------------------------------|
| **ASR Engine** | whisper.cpp + Metal | Apple SpeechAnalyzer (iOS 26+) | SpeechAnalyzer (WWDC 2025) is faster on Apple Silicon but requires iOS 26/macOS 26 Tahoe. If Angelica's devices are on iOS 26, SpeechAnalyzer becomes a viable primary path with whisper.cpp as fallback for older devices. Defer until device OS is confirmed. |
| **ASR Engine** | whisper.cpp + Metal | WhisperKit (argmaxinc) | WhisperKit compiles full encoder+decoder to CoreML for deeper ANE integration. Faster on Apple Silicon but more setup friction (pre-converted CoreML models). whisper.cpp is simpler to integrate and more battle-tested. Consider WhisperKit in Phase 2 if speed is a bottleneck. |
| **ASR Engine** | whisper.cpp + Metal | MLX-Whisper | ~3x faster than whisper.cpp on M1 Max, but it's Python-based (requires Python runtime embedded in Swift app — non-trivial). Not suitable for a native SwiftUI app. |
| **ASR Engine** | whisper.cpp + Metal | Apple SFSpeechRecognizer (legacy) | Weaker accuracy on lecture content (long-form, accented, technical speech). Deprecated in favor of SpeechAnalyzer. Only viable as a quick fallback. |
| **LLM** | Ollama HTTP API | swift-llm (embedded) | More control but significantly more complexity (model lifecycle, quantization, memory management). Defer to Phase 2 if Ollama overhead is unacceptable. |
| **LLM** | Ollama HTTP API | llama.cpp Swift bindings | Same tradeoff as swift-llm. Ollama wraps llama.cpp and handles all the hard parts. |
| **YAML** | Yams | Codable + manual YAML string | Manual YAML generation is error-prone (escaping, indentation). Yams is the standard. |
| **UI Architecture** | Native multiplatform target | Mac Catalyst | Catalyst wraps iOS app for macOS — friction with native macOS features (NSWindow, file system, menu bar). Native multiplatform is Apple's recommended path. |
| **CI Runner** | macos-15 (GitHub Actions) | Depot.dev macos-26 | Depot offers M4 hardware at $0.08/min. Only justified if GitHub Actions macOS queue times are excessive or if macos-26 is needed before GitHub's GA. |
| **CI Runner** | macos-15 (GitHub Actions) | Self-hosted Mac runner | No Mac in home lab. Not viable for MVP. |
| **Document Model** | Manual file writes | SwiftUI DocumentGroup | DocumentGroup is for user-facing document editing apps (like TextEdit). unibrain writes generated files to a vault folder — not a document-based app in the SwiftUI sense. Use FileManager directly. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Mac Catalyst** | Wraps iOS app for macOS with abstraction friction. Poor native macOS integration (file system, menu bar, windows). | Native multiplatform target (`#if os(macOS)` / `#if os(iOS)`) |
| **MLX-Whisper** | Python-based. Embedding Python runtime in a SwiftUI app is non-trivial and breaks the "Apple-native" mandate. | whisper.cpp + Metal (C/C++ via SPM) |
| **Apple SFSpeechRecognizer** (legacy) | Weaker accuracy on lecture content. Deprecated in iOS 26. | whisper.cpp for now; SpeechAnalyzer if on iOS 26+ |
| **Electron / web wrapper** | Violates Apple-native mandate. High memory overhead (unacceptable on 8GB). | SwiftUI native |
| **Cross-platform frameworks** (Flutter, React Native) | Violates Apple-native mandate. Add abstraction layers over AVFoundation, EventKit, Metal. | SwiftUI native |
| **Cloud LLM as primary path** | Violates local-first/privacy mandate. | Ollama local (cloud only as opt-in escape hatch with explicit consent) |
| **Obsidian plugin API** (community plugin) | Adds dependency on Obsidian's plugin runtime. MVP writes plain files. | Plain file writes (Markdown + YAML frontmatter) |
| **Core Data / Realm** for MVP | Overkill for single-user, file-based data. Lectures are Markdown files, not database records. | File system + YAML frontmatter |
| **Firebase / cloud backend** | Violates local-first mandate. No multi-user requirement. | Local files + iCloud Drive for sync |
| **CocoaPods** | Deprecated dependency manager. SPM is Apple's standard. | Swift Package Manager |
| **Running ASR + LLM simultaneously** | 8GB unified memory cannot handle both (~852 MB ASR + ~4-5 GB LLM + 3-4 GB OS = OOM). | Sequential gating: unload one before loading the other |

---

## Stack Patterns by Variant

**If Angelica's MacBook Air is on macOS 26 / iOS 26:**
- Evaluate Apple SpeechAnalyzer as primary ASR (faster, native, Apple Intelligence-powered)
- Keep whisper.cpp as fallback for accuracy-critical transcription
- SpeechAnalyzer eliminates whisper.cpp dependency and its ~852 MB RAM footprint
- **Decision deferred until OS versions confirmed**

**If GitHub Actions macOS queue times exceed 10 minutes:**
- Switch to Depot.dev (`depot-macos-26`) at $0.08/min
- Or use macos-26 runners if available on GitHub Actions
- Cache SPM dependencies and DerivedData to reduce build time

**If whisper.cpp small.en accuracy is insufficient for technical lectures:**
- Try medium.en (~2.1 GB RAM) — still fits 8GB with careful gating
- Or switch to WhisperKit for deeper ANE utilization and potentially better accuracy/speed
- Or use base.en + post-processing LLM correction

**If Ollama is not installed on Angelica's MacBook Air:**
- Ship a setup wizard that guides Ollama installation
- Or embed swift-llm as a fallback (Phase 2 complexity)
- Summarization feature becomes opt-in with explicit setup

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Swift 6.0+ | Xcode 16+ | Swift 6 strict concurrency requires Xcode 16+ |
| whisper.cpp v1.9.x | Swift 6.0 via SwiftWhisper | SwiftWhisper may lag behind latest whisper.cpp; pin whisper.cpp version explicitly |
| Yams 6.2.2 | Swift 5.7+ / Xcode 14+ | Broadly compatible. No known conflicts. |
| SwiftUI iOS 17+ | macOS 14+ (Sonoma) | `@Observable` macro requires iOS 17/macOS 14. Use `@StateObject`/`@ObservedObject` if targeting earlier. |
| EventKit iOS 17+ API | macOS 14+ | `requestFullAccessToEvents` is iOS 17+/macOS 14+ only. Earlier versions use deprecated `requestAccess(to:completion:)`. |
| GitHub Actions macos-15 | Xcode 16.x | macos-15 runners ship with Xcode 16.x pre-installed |

---

## Phase 2 Technology Preview (Local Embeddings)

**Not for MVP.** Documented here for roadmap planning context.

| Technology | Version | Purpose | RAM Footprint | Confidence |
|------------|---------|---------|---------------|------------|
| **swift-transformers** | 1.0+ (huggingface) | Tokenizers + model loading from HuggingFace Hub | N/A (library) | MEDIUM |
| **swift-embeddings** (jkrukowski) | Latest (SPM) | Run embedding models locally via MLTensor/CoreML | Model-dependent | MEDIUM |
| **all-MiniLM-L6-v2** | Sentence Transformers | 384-dim embeddings, ~22MB model | ~100-200 MB | MEDIUM |
| **nomic-embed-text** | Nomic AI | 768-dim embeddings, better quality | ~300-500 MB | LOW |
| **SQLite-VSS** | SQLite extension | Vector similarity search in SQLite | Minimal (index only) | LOW |

**Phase 2 recommendation:** `swift-embeddings` + `all-MiniLM-L6-v2` via CoreML. Smallest footprint (~200 MB), native Swift, runs on Apple Silicon. SQLite-VSS for the vector index. Defer all of this until MVP ship.

---

## Sources

### whisper.cpp / ASR
- [whisper.cpp GitHub (ggml-org)](https://github.com/ggml-org/whisper.cpp) — version, model sizes, Metal/CoreML support (MEDIUM confidence, web-verified)
- [whisper.cpp Releases](https://github.com/ggml-org/whisper.cpp/releases) — v1.9.1 latest, changelog (MEDIUM)
- [SwiftWhisper (exPHAT) on Swift Package Index](https://swiftpackageindex.com/exPHAT/SwiftWhisper) — SPM package details (MEDIUM)
- [Whisper Model Sizes Explained (openwhispr.com)](https://openwhispr.com/blog/whisper-model-sizes-explained) — RAM/disk metrics (MEDIUM)
- [whisper.cpp Benchmark on Mac (getspeakup.app)](https://getspeakup.app/blog/whisper-cpp-benchmark-mac/) — Metal 4.4x speedup (MEDIUM)
- [whisper.cpp GitHub Issue #2310](https://github.com/ggml-org/whisper.cpp/issues/2310) — Memory consumption on 8GB systems (MEDIUM)

### Ollama / LLM
- [Ollama API Documentation (GitHub)](https://github.com/ollama/ollama/blob/main/docs/api.md) — HTTP API spec, keep_alive parameter (HIGH)
- [Ollama Official Docs](https://docs.ollama.com) — API endpoints reference (HIGH)
- [Best Ollama Models for 8GB RAM (localaimaster.com)](https://localaimaster.com/blog/best-local-ai-models-8gb-ram) — Model benchmark on 8GB (MEDIUM)
- [Best Beginner Local LLMs (promptquorum.com)](https://www.promptquorum.com/local-llms/best-beginner-local-llm-models) — Model sizing (MEDIUM)

### SwiftUI / Multiplatform
- [Configuring a multiplatform app (Apple Developer)](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target) — Official guide (HIGH)
- [WWDC22: Use Xcode to develop a multiplatform app](https://developer.apple.com/videos/play/wwdc2022/110371/) — Apple guidance (HIGH)
- [Improving multiplatform SwiftUI code (Jesse Squires)](https://www.jessesquires.com/blog/2023/03/23/improve-multiplatform-swiftui-code/) — Best practices (MEDIUM)
- [Building Cross-Platform SwiftUI Apps (Fatbobman)](https://fatbobman.com/en/posts/building-multiple-platforms-swiftui-app/) — Practical guide (MEDIUM)

### EventKit
- [EKEventStore (Apple Developer)](https://developer.apple.com/documentation/eventkit/ekeventstore) — Official API (HIGH)
- [requestFullAccessToEvents (Apple Developer)](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)) — iOS 17+ permission API (HIGH)
- [WWDC23: Discover Calendar and EventKit](https://developer.apple.com/videos/play/wwdc2023/10052/) — New permission flow (HIGH)

### AVFoundation
- [AVAudioRecorder (Apple Developer)](https://developer.apple.com/documentation/avfaudio/avaudiorecorder) — Official API (HIGH)
- [WWDC25: Enhance your app's audio recording capabilities](https://developer.apple.com/videos/play/wwdc2025/251/) — Latest 2025 guidance (HIGH)
- [Recording from the microphone (Hacking with Swift)](https://www.hackingwithswift.com/read/33/2/recording-from-the-microphone-with-avaudiorecorder) — Practical tutorial (MEDIUM)

### Apple Speech (WWDC 2025)
- [WWDC25: Bring advanced speech-to-text with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/) — New iOS 26 API (HIGH)
- [Bringing advanced speech-to-text (Apple Developer)](https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app) — Official docs (HIGH)

### WhisperKit
- [argmax-oss-swift on Swift Package Index](https://swiftpackageindex.com/argmaxinc/argmax-oss-swift) — SPM availability, platforms (MEDIUM)
- [WhisperKit vs whisper.cpp (cactuscompute.com)](https://cactuscompute.com/compare/argmax-vs-whisper-cpp) — Comparison (MEDIUM)

### Yams
- [Yams on Swift Package Index](https://swiftpackageindex.com/jpsim/Yams) — v6.2.2, SPM details (HIGH)

### GitHub Actions
- [macos-15-Readme (GitHub Actions)](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) — Runner image spec (HIGH)
- [GitHub Blog: macOS runner migration](https://github.blog/changelog/2025-07-11-upcoming-changes-to-macos-hosted-runners-macos-latest-migration-and-xcode-support-policy-updates/) — macos-latest migration (HIGH)
- [GitHub Actions Billing](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions) — Pricing, free tier (HIGH)

### Local Embeddings (Phase 2)
- [swift-embeddings (jkrukowski) on GitHub](https://github.com/jkrukowski/swift-embeddings) — MLTensor/CoreML embeddings (MEDIUM)
- [swift-transformers on Swift Package Index](https://swiftpackageindex.com/huggingface/swift-transformers) — v1.0+ (MEDIUM)
- [Embedding with MiniLM via CoreML (jano.dev)](https://jano.dev/swift/2025/09/29/minilm-coreml.html) — Practical guide (MEDIUM)

---
*Stack research for: Local-first Apple-native lecture capture + study assistant*
*Researched: 2026-07-13*
