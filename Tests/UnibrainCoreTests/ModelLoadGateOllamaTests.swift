import Testing
import Foundation
@testable import UnibrainCore

/// Tests for summary-default.md prompt template and ModelLoadGate Ollama support.
///
/// Phase 06-01 Task 5: Verifies SUMM-04 prompt template is bundled and
/// ModelLoadGate enforces SUMM-07 (Ollama denied while ASR loaded).
@Suite("ModelLoadGateOllamaTests")
struct ModelLoadGateOllamaTests {

    // MARK: - Prompt Template Verification

    @Test("summary-default.md file exists in build directory")
    func promptFileExistsInBuild() throws {
        let buildPath = ".build/x86_64-unknown-linux-gnu/debug/unibrain_UnibrainCore.resources/Prompts/summary-default.md"
        #expect(FileManager.default.fileExists(atPath: buildPath), "summary-default.md should exist in build resources")
    }

    @Test("Prompt content contains '5-8 bullet points' requirement")
    func promptContainsBulletRequirement() throws {
        let buildPath = ".build/x86_64-unknown-linux-gnu/debug/unibrain_UnibrainCore.resources/Prompts/summary-default.md"
        let content = try String(contentsOfFile: buildPath, encoding: .utf8)
        #expect(content.contains("5-8"))
        #expect(content.contains("bullet"))
    }

    @Test("Prompt content contains 'concepts and definitions' focus")
    func promptContainsConceptsFocus() throws {
        let buildPath = ".build/x86_64-unknown-linux-gnu/debug/unibrain_UnibrainCore.resources/Prompts/summary-default.md"
        let content = try String(contentsOfFile: buildPath, encoding: .utf8)
        #expect(content.contains("concepts"))
        #expect(content.contains("definitions"))
    }

    // MARK: - ModelLoadGate Ollama Support

    @Test("ModelLoadGate.acquire(.ollama) succeeds when gate is free")
    func acquireOllamaSucceedsWhenFree() async throws {
        let gate = ModelLoadGate.shared

        // Acquire Ollama lease
        let lease = try await gate.acquire(.ollama)
        #expect(lease.kind == .ollama)

        await lease.release()
    }

    @Test("ModelLoadGate.acquire(.asr) then .ollama throws .busy (SUMM-07 enforcement)")
    func asrBlocksOllama() async throws {
        let gate = ModelLoadGate.shared

        // Acquire ASR lease first
        let asrLease = try await gate.acquire(.asr)

        // Try to acquire Ollama while ASR is held - should throw busy
        await #expect(throws: ModelLoadGateError.self) {
            _ = try await gate.acquire(.ollama)
        }

        await asrLease.release()
    }

    @Test("ModelLoadGate.acquire(.ollama) then .asr throws .busy (symmetric conflict)")
    func ollamaBlocksASR() async throws {
        let gate = ModelLoadGate.shared

        // Acquire Ollama lease first
        let ollamaLease = try await gate.acquire(.ollama)

        // Try to acquire ASR while Ollama is held - should throw busy
        await #expect(throws: ModelLoadGateError.self) {
            _ = try await gate.acquire(.asr)
        }

        await ollamaLease.release()
    }

    @Test("ModelLoadGate.acquire(.ollama) twice (reentrant) succeeds")
    func reentrantOllamaSucceeds() async throws {
        let gate = ModelLoadGate.shared

        let lease1 = try await gate.acquire(.ollama)
        let lease2 = try await gate.acquire(.ollama)

        #expect(lease1.kind == .ollama)
        #expect(lease2.kind == .ollama)

        await lease1.release()
        await lease2.release()
    }
}
