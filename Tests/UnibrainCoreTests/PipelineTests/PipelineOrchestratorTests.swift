import Testing
import Foundation
@testable import UnibrainCore

@Suite("PipelineState")
struct PipelineStateTests {

    @Test("PipelineState.idle constructs")
    func idleConstructs() {
        let state: PipelineState = .idle
        if case .idle = state { /* success */ } else {
            Issue.record("Expected .idle")
        }
    }

    @Test("PipelineState.transcribing constructs")
    func transcribingConstructs() {
        let state: PipelineState = .transcribing
        if case .transcribing = state { /* success */ } else {
            Issue.record("Expected .transcribing")
        }
    }

    @Test("PipelineState.classifying constructs")
    func classifyingConstructs() {
        let state: PipelineState = .classifying
        if case .classifying = state { /* success */ } else {
            Issue.record("Expected .classifying")
        }
    }

    @Test("PipelineState.normalizing constructs")
    func normalizingConstructs() {
        let state: PipelineState = .normalizing
        if case .normalizing = state { /* success */ } else {
            Issue.record("Expected .normalizing")
        }
    }

    @Test("PipelineState.writing constructs")
    func writingConstructs() {
        let state: PipelineState = .writing
        if case .writing = state { /* success */ } else {
            Issue.record("Expected .writing")
        }
    }

    @Test("PipelineState.completed constructs")
    func completedConstructs() {
        let state: PipelineState = .completed
        if case .completed = state { /* success */ } else {
            Issue.record("Expected .completed")
        }
    }

    @Test("PipelineState.failed constructs with Error parameter")
    func failedConstructsWithError() {
        struct TestError: Error {}
        let error = TestError()
        let state: PipelineState = .failed(error)
        if case .failed = state { /* success */ } else {
            Issue.record("Expected .failed")
        }
    }

    @Test("PipelineState.cancelled constructs")
    func cancelledConstructs() {
        let state: PipelineState = .cancelled
        if case .cancelled = state { /* success */ } else {
            Issue.record("Expected .cancelled")
        }
    }

    @Test("PipelineState is Sendable and can cross concurrency boundaries")
    func pipelineStateIsSendable() async {
        // Compile-time Sendable check: assigning to any Sendable succeeds
        // only if PipelineState conforms to Sendable.
        let state: PipelineState = .completed
        let sendable: any Sendable = state
        #expect(sendable is PipelineState)

        // Runtime check: state can cross concurrency boundaries via detached Task.
        let result = await Task.detached { () -> Bool in
            if case .completed = state { return true } else { return false }
        }.value
        #expect(result)
    }
}
