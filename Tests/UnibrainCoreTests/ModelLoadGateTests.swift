import Testing
@testable import UnibrainCore

@Suite("ModelLoadGate")
struct ModelLoadGateTests {

    @Test("Acquire ASR lease succeeds when gate is free")
    func acquireASRSucceeds() async throws {
        let gate = ModelLoadGate()
        let lease = try await gate.acquire(.asr)
        #expect(lease.kind == .asr)
        await lease.release()
    }

    @Test("Acquiring LLM while ASR is held throws busy")
    func denyOnConflict() async throws {
        let gate = ModelLoadGate()
        let asrLease = try await gate.acquire(.asr)

        await #expect(throws: ModelLoadGateError.self) {
            _ = try await gate.acquire(.llm)
        }

        await asrLease.release()
    }

    @Test("Acquiring same model kind twice succeeds (reentrant)")
    func reentrantSameKind() async throws {
        let gate = ModelLoadGate()
        let lease1 = try await gate.acquire(.asr)
        let lease2 = try await gate.acquire(.asr)
        #expect(lease1.kind == .asr)
        #expect(lease2.kind == .asr)
        await lease1.release()
        await lease2.release()
    }

    @Test("After release, gate accepts different model")
    func releaseAllowsNewModel() async throws {
        let gate = ModelLoadGate()
        let asrLease = try await gate.acquire(.asr)
        await asrLease.release()
        let llmLease = try await gate.acquire(.llm)
        #expect(llmLease.kind == .llm)
        await llmLease.release()
    }
}
