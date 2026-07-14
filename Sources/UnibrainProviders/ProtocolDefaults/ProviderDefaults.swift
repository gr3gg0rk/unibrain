import Foundation

// ProviderDefaults scaffolding for Apple-framework provider conformances.
//
// Per FOUND-02: all Apple-framework imports live behind #if canImport()
// guards so that UnibrainProviders compiles on Linux (where Apple
// frameworks are unavailable) and on macOS/iOS (where they are).
//
// Phase 3+ adds concrete conformances (whisper.cpp ASR, Ollama LLM, etc.)
// inside these guard blocks. Phase 1 ships the guard scaffolding only.

#if canImport(AVFoundation)
import AVFoundation
// Phase 3: AVFoundation-based AudioTranscriber / audio capture conformance
#endif

#if canImport(Speech)
import Speech
// Phase 3: Speech framework fallback AudioTranscriber conformance
#endif

#if canImport(Vision)
import Vision
// Phase 2: Vision-based VisionDescriber conformance (OCR, scene detection)
#endif

#if canImport(AVFAudio)
import AVFAudio
// Phase 3: AVFAudio-based AudioSynthesizer / audio session conformance
#endif
