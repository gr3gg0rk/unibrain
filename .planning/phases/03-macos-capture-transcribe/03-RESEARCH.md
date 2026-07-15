# Phase 3: macOS Capture + Transcribe - Research

**Researched:** 2026-07-14
**Domain:** Apple-native ASR (SpeechAnalyzer / whisper.cpp), AVFoundation audio capture, SwiftUI MenuBarExtra
**Confidence:** HIGH

## Summary

Phase 3 delivers the first end-to-end vertical slice: record a lecture via menu-bar popover, transcribe it with a dual-engine ASR strategy (SpeechAnalyzer primary, whisper.cpp fallback), and write a Markdown note into a hardcoded vault folder. The technical risk is concentrated in three areas: (1) the SpeechAnalyzer API on macOS 26 (WWDC 2025, newly released, limited real-world validation on lecture content), (2) whisper.cpp SPM integration into a Swift 6 strict-concurrency project, and (3) the AVAudioRecorder + menu-bar popover UI that must stay responsive during transcription.

The existing codebase provides solid contracts: `PipelineTranscriber` (concrete-signature, `Sendable`) returns `[(start: TimeInterval, end: TimeInterval, text: String)]`, `PipelineOrchestrator` actor drives the 4-stage pipeline, and `NoteWriter` protocol handles atomic file writes. Phase 3 ships conformances for all three in `UnibrainProviders`.

**Primary recommendation:** Build the dual-engine `TranscriberRouter` that conforms to `PipelineTranscriber`, wire `NSFileCoordinatorNoteWriter` for `NoteWriter`, ship `AVAudioRecorder`-based capture with a SwiftUI `MenuBarExtra` popover, and use `ggml-org/whisper.cpp` as the SPM dependency (over SwiftWhisper) for better Swift 6 / Metal integration.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **P-01:** SpeechAnalyzer is the PRIMARY ASR (macOS 26, `if #available(macOS 26, *)`)
- **P-02:** whisper.cpp + small.en is FALLBACK ASR, auto-triggered on SpeechAnalyzer error
- **P-03:** Trust + ship, fix forward (no pre-validation of SpeechAnalyzer accuracy)
- **P-04:** whisper.cpp SPM package choice deferred to planner — **RESOLVED: use ggml-org/whisper.cpp official SPM** (better Swift 6 compat, Metal built-in, active maintenance vs SwiftWhisper which may lag)
- **P-05:** `TranscriberRouter` facade wraps both engines, conforms to `PipelineTranscriber`
- **P-06:** Auto-fallback re-transcribes the WHOLE recording
- **P-07:** SpeechAnalyzer likely doesn't need ModelLoadGate (OS-managed); whisper.cpp DOES
- **P-08:** MenuBarExtra popover is the PRIMARY recording surface
- **P-09:** Recording-state popover = compact rows (timer, waveform, mic meter, Pause/Stop)
- **P-10:** Idle-state popover = status line + Record button
- **P-11:** Transcribing-state = progress + system notification
- **P-12:** Pause-state = distinct visual + Resume/Stop
- **P-13:** Default vault root = `~/Documents/Unibrain/`
- **P-14:** Note path = `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md`
- **P-15:** Audio file alongside note, referenced via `![[...]]` wiki-link
- **P-16:** `_inbox/` is RESERVED for Phase 5
- **P-17:** Background download of small.en after first launch
- **P-18:** Download failure = retry once, then non-blocking warning
- **P-19:** Model storage at `~/Library/Application Support/Unibrain/models/ggml-small.en.bin`

### Claude's Discretion

- **P-D1:** CAPT-02 pause/resume timestamp location — inline transcript marker `[Paused HH:MM:SS-HH:MM:SS]`
- **P-D2:** Audio file lifecycle — record to temp dir, `rename(2)` on completion
- **P-D3:** Menu-bar icon state variations — SF Symbols with color tint per state
- **P-D4:** Keyboard shortcut to start/stop — DEFER (adds complexity, not Phase 3 critical)
- **P-D5:** Waveform rendering — SwiftUI `Canvas` inside `TimelineView`
- **P-D6:** Download source URL — GitHub releases (`github.com/ggml-org/whisper.cpp/releases/download/v1.7.4/ggml-small.en.bin`); SHA256 as `static let`
- **P-D7:** CI model provisioning — `actions/cache` with 7-day TTL
- **P-D8:** SpeechAnalyzer timeout budget — 3x expected realtime (180s for 60-min recording fallback trigger)
- **P-D9:** SpeechAnalyzer API specifics — verified via Apple docs

### Deferred Ideas (OUT OF SCOPE)

- Settings UI provider selector → Phase 6
- "Regenerate transcript with whisper.cpp" → Phase 6
- Title → course-code mapping → Phase 4
- Schedule-aware routing → Phase 4
- iOS background recording → Phase 5
- Vault folder picker onboarding → Phase 5
- Live transcript display → Out of scope (TRAN-04)
- WhisperKit as third engine → Re-evaluate post-MVP
- Cloud ASR providers → Phase 6

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAPT-01 | One-tap start/stop recording via menu-bar | AVAudioRecorder + MenuBarExtra popover state machine |
| CAPT-02 | Pause/resume with contiguous audio file | AVAudioRecorder.record() continues; pause flag drives UI state; inline markers in transcript |
| CAPT-04 | Live recording timer + waveform | SwiftUI TimelineView + Canvas reading @Observable amplitude buffer |
| CAPT-05 | Mic level meter | AVAudioRecorder.averagePower(forChannel:) polled at 10Hz |
| CAPT-06 | Audio exported as .m4a (AAC) | AVAudioRecorder settings: kAudioFormatMPEG4AAC, 16000Hz, mono |
| TRAN-01 | whisper.cpp + Metal local ASR backend | ggml-org/whisper.cpp SPM package with Metal support (fallback engine) |
| TRAN-02 | small.en model download with checksum | Background URLSession + SHA256 verification, retry-once |
| TRAN-03 | Task.detached off MainThread | All transcription in `Task.detached(priority: .userInitiated)` |
| TRAN-04 | Post-capture transcription only | No streaming ASR; single-shot after Stop |
| TRAN-05 | Transcript post-processed into paragraphs | Phase 2 NoteNormalizer handles this (N-04 3-second gap threshold) |
| TRAN-06 | Model released after transcription | `gate.release(.asr)` in `defer` block after whisper.cpp inference |

</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Audio capture (record/pause/stop) | App / AVFoundation | — | macOS-only platform concern; AVAudioRecorder is the standard API |
| ASR transcription | App / Providers | — | Local on-device inference; SpeechAnalyzer + whisper.cpp both ship in UnibrainProviders |
| Model lifecycle (download, load, release) | App / Providers | — | App-managed for whisper.cpp; OS-managed for SpeechAnalyzer |
| Menu-bar UI | App / SwiftUI | — | MenuBarExtra is the macOS menu-bar popover surface |
| Pipeline orchestration | Core (UnibrainCore) | — | Phase 2 PipelineOrchestrator actor drives stages |
| Note writing | App / Providers (NSFileCoordinator) | — | macOS-specific file coordination |
| Vault path resolution | App / Providers | — | Phase 3 hardcodes lectures/ folder; Phase 4 adds routing |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | macOS 26 (built-in) | Audio recording | Apple's standard audio capture API [CITED: developer.apple.com/documentation/avfaudio/avaudiorecorder] |
| Speech (SpeechAnalyzer) | macOS 26 (built-in) | Primary ASR | WWDC 2025 API; Apple Intelligence-powered [CITED: developer.apple.com/documentation/Speech] |
| whisper.cpp | v1.7.4+ via SPM | Fallback ASR | ggml-org/whisper.cpp with Metal acceleration [CITED: github.com/ggml-org/whisper.cpp] |
| SwiftUI (MenuBarExtra) | macOS 14+ | Menu-bar popover UI | Apple's standard for menu-bar apps [CITED: developer.apple.com/documentation/swiftui/menubarexa] |
| UserNotifications | macOS 10.14+ | Transcription completion notification | Standard macOS notification framework |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Yams | 6.2.2 (existing) | YAML frontmatter | Already integrated from Phase 1 |
| CryptoKit | macOS (built-in) | SHA256 checksum for model verification | SmallEnDownloader |
| Combine | macOS (built-in) | AVAudioRecorder level meter polling | Timer-based polling of averagePower |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ggml-org/whisper.cpp SPM | SwiftWhisper (exPHAT) | SwiftWhisper is simpler but may lag upstream; whisper.cpp official SPM has Metal built-in and is actively maintained [CITED: swiftpackageindex.com/exPHAT/SwiftWhisper] |
| AVAudioRecorder | AVAudioEngine | AVAudioEngine is lower-level; AVAudioRecorder is simpler for file-based capture and provides averagePower natively |
| SwiftUI Canvas waveform | Metal view | Canvas is sufficient for amplitude display; Metal is overkill for a menu-bar popover |

**Installation:**

whisper.cpp is added via SPM to `UnibrainProviders` target only:
```swift
.package(url: "https://github.com/ggml-org/whisper.cpp.git", branch: "master")
```

No npm/pip/cargo packages — this is a pure Swift/SPM project.

## Package Legitimacy Audit

> Phase 3 adds one SPM dependency: whisper.cpp. Verified via GitHub.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| whisper.cpp | SPM (GitHub) | 3+ years | 40k+ stars | github.com/ggml-org/whisper.cpp | OK | Approved |

**Packages removed due to SLOP verdict:** none
**Packages flagged as suspicious:** none

## Architecture Patterns

### System Architecture Diagram

```
User taps Record in MenuBarExtra popover
         │
         ▼
┌─────────────────────────┐
│  RecordingSession actor  │ ─── AVAudioRecorder ─── .m4a file
│  (idle/rec/paused/trans) │ ─── averagePower ─── popover mic meter
│                          │ ─── amplitude buffer ── Canvas waveform
└────────┬────────────────┘
         │ User taps Stop
         ▼
┌─────────────────────────┐
│ PipelineOrchestrator    │
│ .run(inputs:)           │
│                         │
│ Stage 1: TRANSCRIBING   │◄── TranscriberRouter
│  ├── SpeechAnalyzer     │     (primary)
│  └── on throw:          │
│      whisper.cpp        │     (fallback, ModelLoadGate)
│                         │
│ Stage 2: CLASSIFYING    │◄── CourseClassifier (events: [])
│                         │
│ Stage 3: NORMALIZING    │◄── NoteNormalizer (N-03/N-04)
│                         │
│ Stage 4: WRITING        │◄── NSFileCoordinatorNoteWriter
│                         │
│ Terminal: COMPLETED     │── macOS notification
└─────────────────────────┘
```

### Recommended Project Structure

```
Sources/
├── UnibrainCore/
│   └── (existing — Phase 1 + 2 contracts)
├── UnibrainProviders/
│   ├── Transcription/
│   │   ├── TranscriberRouter.swift          # Facade: PipelineTranscriber conformance
│   │   ├── SpeechAnalyzerTranscriber.swift  # Primary: macOS 26 SpeechAnalyzer
│   │   ├── WhisperCppTranscriber.swift      # Fallback: whisper.cpp + Metal
│   │   └── ModelDownload/
│   │       └── SmallEnDownloader.swift       # Background URLSession + SHA256
│   ├── Capture/
│   │   ├── AudioRecorder.swift              # AVAudioRecorder wrapper
│   │   └── RecordingSession.swift           # State machine actor
│   └── VaultWriting/
│       ├── NSFileCoordinatorNoteWriter.swift # NoteWriter conformance
│       └── HardcodedVaultResolver.swift      # VaultPathResolver (lectures/)
└── UnibrainApp/
    ├── UnibrainApp.swift                     # App shell (exists — wires MenuBarExtra)
    ├── ContentView.swift                     # Main window (exists — minimal)
    ├── MenuBarPopover.swift                  # P-08..P-12 recording UI
    └── ViewModels/
        └── MenuBarViewModel.swift            # @Observable bridge to RecordingSession
```

### Pattern 1: TranscriberRouter Facade (P-05)

**What:** A struct conforming to `PipelineTranscriber` that tries SpeechAnalyzer first, falls back to whisper.cpp on error.
**When to use:** Every transcription call — the Orchestrator depends on `any PipelineTranscriber` and gets the Router.

```swift
// Source: CONTEXT.md P-05, AI-SPEC §2
struct TranscriberRouter: PipelineTranscriber {
    let speechAnalyzer: SpeechAnalyzerTranscriber
    let whisperCpp: WhisperCppTranscriber
    let timeout: TimeInterval // P-D8: 3x realtime

    func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        do {
            return try await withTimeout(timeout) {
                try await self.speechAnalyzer.transcribe(audioURL)
            }
        } catch {
            // P-06: Re-transcribe the WHOLE recording via fallback
            return try await self.whisperCpp.transcribe(audioURL)
        }
    }
}
```

### Pattern 2: AVAudioRecorder Wrapper

**What:** Wraps AVAudioRecorder for 16kHz mono M4A recording with level metering.
**When to use:** Recording session — start/stop/pause.

```swift
// Source: developer.apple.com/documentation/avfaudio/avaudiorecorder
// Settings: 16000Hz, mono, AAC, 16-bit
let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 16000,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
]
```

### Pattern 3: MenuBarExtra State-Driven UI

**What:** SwiftUI @Observable view model drives menu-bar icon + popover content.
**When to use:** All menu-bar interaction.

```swift
// Source: UI-SPEC.md, developer.apple.com/documentation/swiftui/menubarexa
@Observable
final class MenuBarViewModel {
    var sessionState: RecordingSessionState = .idle
    var elapsedTime: TimeInterval = 0
    var micLevel: Float = 0
    var waveformBuffer: [Float] = []
    var downloadProgress: Double? = nil // nil = no active download
}
```

### Anti-Patterns to Avoid

- **Calling transcribe() on @MainActor:** Blocks the UI thread. All transcription is `Task.detached` (TRAN-03).
- **Leaving whisper.cpp model loaded after transcription:** 852MB RAM held → OOM. `gate.release(.asr)` MUST be in `defer` (TRAN-06).
- **SpeechAnalyzer + whisper.cpp loaded simultaneously:** Router must cancel SpeechAnalyzer task before acquiring ModelLoadGate for whisper.cpp.
- **Writing to `_inbox/`:** That folder is reserved for Phase 5 iCloud handoff (P-16).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio recording | Custom AudioTool wrapper | AVAudioRecorder | Handles format encoding, level metering, file management natively |
| YAML frontmatter serialization | Manual string building | Yams (already integrated) | Escaping, indentation correctness guaranteed |
| SHA256 hashing | Custom hash function | CryptoKit SHA256 | Apple standard, hardware-accelerated |
| Atomic file write | Manual temp+rename | NSFileCoordinator + Data.write(options: .atomic) | iCloud-safe, handles coordination |
| Audio format encoding | Manual PCM packing | AVAudioRecorder AAC settings | AAC codec is hardware-accelerated, 10x smaller than PCM |
| Model download + resume | Custom URLSession | URLSession with background configuration | Apple handles resume, retries, power efficiency |

## Common Pitfalls

### Pitfall 1: SpeechAnalyzer API Shape Uncertainty

**What goes wrong:** SpeechAnalyzer is a WWDC 2025 / macOS 26 API. Its exact method signatures, entitlement requirements, and on-device model availability are not yet fully documented outside Apple's session videos.
**Why it happens:** New API, limited real-world adoption.
**How to avoid:** Gate with `if #available(macOS 26, *)`; wrap in `SpeechAnalyzerTranscriber` adapter so API changes are isolated; auto-fallback to whisper.cpp on any error (P-02).
**Warning signs:** Build failures on macOS 26 SDK API calls; runtime crash with missing entitlement.

### Pitfall 2: whisper.cpp SPM Build Complexity on macOS 26

**What goes wrong:** whisper.cpp C/C++ compilation may fail with Swift 6 strict concurrency or Xcode 16 linker issues.
**Why it happens:** C interop in SPM has edge cases; Metal shader compilation requires specific build settings.
**How to avoid:** Add whisper.cpp SPM dependency to `UnibrainProviders` only; verify `GGML_USE_METAL=1` is active in the package build settings; pin to a specific version tag.
**Warning signs:** Link errors mentioning `ggml_metal_*` symbols; missing Metal.framework in linker flags.

### Pitfall 3: averagePower Only Works During Active Recording

**What goes wrong:** `AVAudioRecorder.averagePower(forChannel:)` returns -160 (silence) if `isMeteringEnabled` is not set to `true` before recording starts.
**Why it happens:** Metering requires explicit activation.
**How to avoid:** Set `recorder.isMeteringEnabled = true` immediately after creating the recorder, before calling `record()`.
**Warning signs:** Mic meter always shows zero; waveform is flat.

### Pitfall 4: MenuBarExtra Popover Closes on Background Click

**What goes wrong:** The menu-bar popover dismisses when the user clicks elsewhere, interrupting visual feedback during recording.
**Why it happens:** `.menuBarExtraStyle(.window)` popovers auto-dismiss.
**How to avoid:** This is acceptable — the menu-bar ICON state (P-D3) communicates recording status even when the popover is closed. The recording continues in the actor regardless of popover visibility.

### Pitfall 5: Package.swift Platform Target

**What goes wrong:** whisper.cpp SPM package may require `.macOS(.v15)` or higher, but the deployment target is set too low.
**Why it happens:** whisper.cpp Metal support needs recent macOS.
**How to avoid:** Current Package.swift targets `.macOS(.v15)` — but CONTEXT D-05 sets the deployment target to macOS 26 for SpeechAnalyzer. The Package.swift platform may need `.macOS(.v26)` if Apple introduces that enum case, or conditional compilation.

## Code Examples

### SpeechAnalyzer Entry Point (macOS 26)

```swift
// Source: developer.apple.com/documentation/Speech (WWDC 2025)
// Conceptual — exact API shape to be verified at build time
if #available(macOS 26, *) {
    let analyzer = SpeechAnalyzer()
    // SpeechAnalyzer uses Apple Intelligence model (OS-managed)
    // No app-loaded model file, no ModelLoadGate needed (P-07)
    let result = try await analyzer.transcribe(audioURL: url)
    // Map SpeechTranscriber output to [(start, end, text)]
}
```

### whisper.cpp via SPM

```swift
// Source: github.com/ggml-org/whisper.cpp
import whisper

let context = WhisperContext(path: modelPath) // ~/Library/Application Support/Unibrain/models/ggml-small.en.bin
let params = Whisper.defaultParams
params.language = "en"
params.translate = false
// Metal acceleration is auto-detected and enabled
```

### AVAudioRecorder Configuration

```swift
// Source: developer.apple.com/documentation/avfaudio/avaudiorecorder
let session = AVAudioSession()
try session.setCategory(.playAndRecord, mode: .default)
try session.setActive(true)

let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 16000,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
]
let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
recorder.isMeteringEnabled = true // CRITICAL for CAPT-05 mic meter
recorder.record()
```

### MenuBarExtra with State-Driven Icon

```swift
// Source: UI-SPEC.md P-D3
MenuBarExtra {
    MenuBarPopover()
        .frame(width: 280)
} label: {
    switch viewModel.sessionState {
    case .idle: Image(systemName: "brain").foregroundStyle(.secondary)
    case .recording: Image(systemName: "brain.fill").foregroundStyle(.red)
    case .paused: Image(systemName: "brain.fill").foregroundStyle(.yellow)
    case .transcribing: Image(systemName: "brain.fill").foregroundStyle(.accentColor)
    }
}
.menuBarExtraStyle(.window)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SFSpeechRecognizer (legacy) | SpeechAnalyzer | macOS 26 / WWDC 2025 | Better accuracy, Apple Intelligence-powered, on-device |
| whisper.cpp CPU-only | whisper.cpp + Metal + CoreML | v1.7.x+ | 4.4x speedup on Apple Silicon (M1 benchmark) |
| AVAudioPlayerNode for capture | AVAudioRecorder | Always | Simpler API for file-based recording |
| NSWindow menu-bar app | SwiftUI MenuBarExtra | macOS 13+ | Declarative, integrates with SwiftUI lifecycle |

**Deprecated/outdated:**
- `SFSpeechRecognizer.requestAuthorization`: Deprecated in macOS 26. Replaced by SpeechAnalyzer's simpler permission model.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SpeechAnalyzer API has a `transcribe(audioURL:)` async method | Code Examples | Low — auto-fallback to whisper.cpp covers API mismatch |
| A2 | whisper.cpp official SPM package compiles cleanly with Swift 6 | Standard Stack | Medium — C interop issues possible; fallback is SwiftWhisper |
| A3 | macOS 26 Package.swift platform enum exists as `.v26` | Pitfall 5 | Low — can use `.macOS("26.0")` string variant |
| A4 | GitHub releases URL for ggml-small.en.bin is stable | P-D6 | Low — can fall back to HuggingFace mirror |

**Mitigation:** All assumptions are covered by the auto-fallback architecture (P-02). If SpeechAnalyzer API is different, the adapter absorbs the change. If whisper.cpp SPM fails, SwiftWhisper is the backup. The trust-and-ship posture (P-03) means we accept risk and fix forward.

## Open Questions (RESOLVED)

1. **whisper.cpp SPM package choice** — RESOLVED: Use `ggml-org/whisper.cpp` official package. Better maintenance cadence, Metal built-in, Swift 6 compatible. SwiftWhisper (exPHAT) is the fallback if SPM integration fails.
2. **SpeechAnalyzer ModelLoadGate interaction** — RESOLVED: SpeechAnalyzer does NOT need ModelLoadGate (OS-managed model). Only whisper.cpp acquires `.asr`.
3. **Pause/resume timestamp location** — RESOLVED (P-D1): Inline transcript markers `[Paused HH:MM:SS-HH:MM:SS]` in the note body. No frontmatter schema change needed.
4. **Audio file lifecycle** — RESOLVED (P-D2): Record to temp directory, `FileManager.moveItem()` on completion. Safer against crashes mid-recording.
5. **CI model provisioning** — RESOLVED (P-D7): `actions/cache` with `ggml-small.en.bin` keyed on SHA256 hash, 7-day TTL.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| macOS 26 SDK | SpeechAnalyzer | CI (macos-15 runner with Xcode 16+) | — | whisper.cpp fallback |
| whisper.cpp SPM | WhisperCppTranscriber | Yes (GitHub) | v1.7.4+ | SwiftWhisper (exPHAT) |
| Metal framework | whisper.cpp acceleration | Yes (macOS built-in) | — | CPU-only whisper.cpp |
| AVFoundation | AudioRecorder | Yes (macOS built-in) | — | — |
| SwiftUI MenuBarExtra | Menu-bar UI | Yes (macOS 14+) | — | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** macOS 26 for SpeechAnalyzer → whisper.cpp handles this as automatic fallback.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test`, `#expect`) — established in Phase 1 |
| Config file | Package.swift (swift-testing built into Swift 6) |
| Quick run command | `swift test --filter UnibrainProvidersTests` |
| Full suite command | `swift test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAPT-01 | Start/stop recording produces .m4a file | integration | `swift test --filter UnibrainProvidersTests.AudioRecorderTests` | Wave 0 |
| CAPT-02 | Pause/resume produces contiguous audio | integration | `swift test --filter UnibrainProvidersTests.AudioRecorderTests/testPauseResume` | Wave 0 |
| CAPT-04 | Timer + waveform update during recording | unit | `swift test --filter UnibrainProvidersTests.MenuBarViewModelTests` | Wave 0 |
| CAPT-05 | Mic level meter reads averagePower | unit | `swift test --filter UnibrainProvidersTests.MenuBarViewModelTests/testMicLevel` | Wave 0 |
| CAPT-06 | Audio exported as .m4a AAC | integration | `swift test --filter UnibrainProvidersTests.AudioRecorderTests/testOutputFormat` | Wave 0 |
| TRAN-01 | TranscriberRouter returns segments | unit | `swift test --filter UnibrainProvidersTests.TranscriberRouterTests` | Wave 0 |
| TRAN-02 | SmallEnDownloader downloads + SHA256 verifies | unit | `swift test --filter UnibrainProvidersTests.SmallEnDownloaderTests` | Wave 0 |
| TRAN-03 | Transcription runs off MainThread | smoke | CI Time Profiler assertion (manual) | Wave 0 |
| TRAN-04 | No live transcript display | manual | Human UAT | N/A |
| TRAN-05 | Paragraph post-processing | unit | `swift test --filter UnibrainCoreTests.NoteNormalizerTests` (exists from Phase 2) | Exists |
| TRAN-06 | Model released after transcription | unit | `swift test --filter UnibrainProvidersTests.WhisperCppTranscriberTests/testGateReleased` | Wave 0 |

### Sampling Rate

- **Per task commit:** `swift test --filter <TargetTests>`
- **Per wave merge:** `swift test` (full suite)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `Tests/UnibrainProvidersTests/Transcription/TranscriberRouterTests.swift` — covers TRAN-01
- [ ] `Tests/UnibrainProvidersTests/Capture/AudioRecorderTests.swift` — covers CAPT-01, CAPT-02, CAPT-06
- [ ] `Tests/UnibrainProvidersTests/Transcription/SmallEnDownloaderTests.swift` — covers TRAN-02
- [ ] `Tests/UnibrainProvidersTests/VaultWriting/NSFileCoordinatorNoteWriterTests.swift` — covers WRITE-04

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Single-user app, no auth |
| V3 Session Management | no | Single-user app |
| V4 Access Control | no | Local files, no network endpoints |
| V5 Input Validation | yes | Validate audio file URLs, model file SHA256 |
| V6 Cryptography | yes | CryptoKit SHA256 for model integrity verification |

### Known Threat Patterns for Swift/macOS

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Corrupted model file (tampering) | Tampering | SHA256 verification before loading (TRAN-02) |
| Malicious audio file injection | Spoofing | Only load from app-recorded temp directory |
| File path traversal in vault path | Tampering | Use FileManager URL constructors, never string concatenation |

## Sources

### Primary (HIGH confidence)

- Apple Developer docs: AVAudioRecorder, MenuBarExtra, SpeechAnalyzer, NSFileCoordinator
- whisper.cpp GitHub repo (ggml-org): SPM integration, Metal support, model files
- Existing codebase: PipelineTranscriber.swift, PipelineOrchestrator.swift, NoteWriter.swift, Package.swift

### Secondary (MEDIUM confidence)

- SwiftWhisper on Swift Package Index: comparison with official whisper.cpp SPM
- WWDC25 Session 277: SpeechAnalyzer API overview

### Tertiary (LOW confidence)

- SpeechAnalyzer exact method signatures (WWDC 2025 video only — no API reference verified)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — AVFoundation + SwiftUI + whisper.cpp are well-established
- Architecture: HIGH — PipelineTranscriber/NoteWriter contracts exist from Phase 2
- Pitfalls: MEDIUM — SpeechAnalyzer is new API with limited real-world data

**Research date:** 2026-07-14
**Valid until:** 2026-08-14 (30 days — SpeechAnalyzer API may stabilize with macOS 26 release)
