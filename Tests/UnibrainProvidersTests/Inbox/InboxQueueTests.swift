import Testing
import Foundation
@testable import UnibrainProviders

@Suite("InboxQueue")
struct InboxQueueTests {

    // MARK: - Test 1 (TRIG-02): FIFO ordering

    @Test("enqueue adds URL; processNext returns it in FIFO order")
    func enqueueAndProcessFIFO() async throws {
        #if os(macOS)
        let queue = InboxQueue()
        let urlA = URL(fileURLWithPath: "/tmp/inbox/iphone-20260915T101530-a3f8.m4a")
        let urlB = URL(fileURLWithPath: "/tmp/inbox/iphone-20260915T111500-b71c.m4a")

        await queue.enqueue(urlA)
        await queue.enqueue(urlB)

        let first = try await queue.processNext()
        let second = try await queue.processNext()

        #expect(first == urlA)
        #expect(second == urlB)
        #expect(first != urlB)
        #else
        #expect(Bool(true)) // macOS-only — skipped on Linux
        #endif
    }

    // MARK: - Test 2 (TRIG-02): Empty queue returns nil

    @Test("processNext returns nil when queue is empty")
    func processNextReturnsNilWhenEmpty() async throws {
        #if os(macOS)
        let queue = InboxQueue()
        let result = try await queue.processNext()
        #expect(result == nil)
        #else
        #expect(Bool(true))
        #endif
    }

    // MARK: - Test 3 (TRIG-02): Sequential processing of 3 URLs

    @Test("queue with 3 URLs processes them sequentially")
    func processesThreeURLsSequentially() async throws {
        #if os(macOS)
        let queue = InboxQueue()
        let url1 = URL(fileURLWithPath: "/tmp/inbox/a.m4a")
        let url2 = URL(fileURLWithPath: "/tmp/inbox/b.m4a")
        let url3 = URL(fileURLWithPath: "/tmp/inbox/c.m4a")

        await queue.enqueue(url1)
        await queue.enqueue(url2)
        await queue.enqueue(url3)

        let first = try await queue.processNext()
        await queue.markComplete()
        let second = try await queue.processNext()
        await queue.markComplete()
        let third = try await queue.processNext()
        await queue.markComplete()
        let fourth = try await queue.processNext()

        #expect(first == url1)
        #expect(second == url2)
        #expect(third == url3)
        #expect(fourth == nil)
        #else
        #expect(Bool(true))
        #endif
    }

    // MARK: - Test 4: De-duplication

    @Test("enqueue skips duplicate URLs already pending")
    func enqueueDeduplicates() async throws {
        #if os(macOS)
        let queue = InboxQueue()
        let url = URL(fileURLWithPath: "/tmp/inbox/iphone-20260915T101530-a3f8.m4a")

        await queue.enqueue(url)
        await queue.enqueue(url) // duplicate — should be skipped

        let pendingCount = await queue.pendingCount
        #expect(pendingCount == 1)
        #else
        #expect(Bool(true))
        #endif
    }
}
