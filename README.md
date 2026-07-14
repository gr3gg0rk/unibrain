# unibrain

A local-first, Apple-native lecture capture and study assistant for university students. Records lectures on MacBook and iPhone, transcribes them on-device, auto-classifies each recording to the right course using the student's Apple Calendar schedule, and writes structured Markdown notes into an Obsidian vault.

**Core value:** Every recording lands in the right course folder, transcribed and summarized, without the student ever manually organizing it.

## Status

**Phase 1 — Foundation: complete.** Walking skeleton proven end-to-end:

- Swift 6.0.3 SPM package builds green on Linux + macOS
- 17 tests passing across ModelLoadGate, FrontmatterSchema, and ProviderProtocol suites
- GitHub Actions CI runs Linux + macOS matrix on every push with SPM dependency caching
- Architectural decisions locked in [SKELETON.md](.planning/phases/01-foundation/SKELETON.md)

Phases 2-6 (transcription pipeline, macOS record-write loop, calendar routing, iOS capture, gated summaries) are tracked in [`.planning/ROADMAP.md`](.planning/ROADMAP.md).

## Design principles

- **Local-first by default, cloud by choice.** Local (Ollama, whisper.cpp) is the always-available default. Cloud providers (OpenAI, Anthropic, X/Grok, Z.ai) are explicit opt-in per modality. No cloud call happens without user configuration.
- **Apple-native.** SwiftUI + AVFoundation / Vision / Speech / Metal / EventKit. No Electron, no cross-platform abstraction.
- **Privacy by default.** Local-only mode is zero-cloud, zero-telemetry. Audio never leaves the device unless the user explicitly routes it through a cloud model.
- **8GB-friendly.** `ModelLoadGate` enforces deny-on-conflict semantics — only one heavy model (ASR ~852MB or LLM ~4-5GB) loaded at a time. Cloud calls bypass the gate.

## Tech stack

| Layer | Choice |
|-------|--------|
| Language | Swift 6.0 (strict concurrency) |
| UI | SwiftUI native multiplatform (macOS + iOS) |
| Build | Swift Package Manager |
| ASR | whisper.cpp + Metal (Phase 3); SpeechAnalyzer under evaluation |
| LLM | Ollama HTTP API (Phase 6); cloud providers opt-in |
| Calendar | EventKit (Phase 4) |
| Storage | File system + YAML frontmatter via Yams 6.2.2 |
| CI | GitHub Actions (Linux + macOS matrix) |

## Build

Requires Swift 6.0.3 or newer.

```bash
# Build the core library
swift build --target UnibrainCore

# Run the test suite (Linux or macOS)
swift test --filter UnibrainCoreTests
```

> **Note:** `swift test --filter` is used instead of `--test-product` due to a Swift 6.0.3 SPM limitation.

WSL2 Linux works for `UnibrainCore` development — the core library has zero Apple-framework imports. macOS with Xcode 16+ is required for the full app build (Phase 3+).

## Project layout

```
.
├── Package.swift                  # SPM manifest (4 targets)
├── Sources/
│   ├── UnibrainCore/              # Protocols, schemas, ModelLoadGate
│   │   ├── Protocols/             # LLMSummarizer, AudioTranscriber, VisionDescriber, AudioSynthesizer
│   │   ├── Errors/                # ProviderError (6 cases)
│   │   ├── ModelLoadGate/         # 8GB RAM deny-on-conflict actor
│   │   └── Schemas/               # FrontmatterSchema (YAML frontmatter)
│   └── UnibrainProviders/         # Provider default implementations
├── Tests/
│   ├── UnibrainCoreTests/
│   └── UnibrainProvidersTests/
├── UnibrainApp/                   # SwiftUI app shell (separate from SPM, Phase 3+)
└── .github/workflows/ci.yml       # Linux + macOS matrix CI
```

## Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Foundation (SPM, protocols, ModelLoadGate, CI) | Complete |
| 2 | Pure pipeline logic (note normalization, course matching) | Planned |
| 3 | macOS record-transcribe-write slice (the MVP loop) | Planned |
| 4 | Calendar-based routing via EventKit | Planned |
| 5 | iOS capture + onboarding | Planned |
| 6 | Gated summarization (Ollama) + cloud providers | Planned |

See [`.planning/ROADMAP.md`](.planning/ROADMAP.md) for the full breakdown.

## License

MIT — see [LICENSE](LICENSE).
