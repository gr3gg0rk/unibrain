import Testing
import Foundation
import UnibrainCore
@testable import UnibrainProviders

/// Test double for TCPReachability probing — avoids real network sockets.
public final class StubReachabilityProbe: ReachabilityProbe, @unchecked Sendable {
    public enum Result: Sendable {
        case reachable
        case failed
        case timedOut
    }

    public let result: Result
    public let expectedHost: String?
    public let expectedPort: Int?
    public private(set) var capturedHosts: [(host: String, port: Int, timeout: TimeInterval)] = []

    public init(result: Result, expectedHost: String? = nil, expectedPort: Int? = nil) {
        self.result = result
        self.expectedHost = expectedHost
        self.expectedPort = expectedPort
    }

    public func probe(host: String, port: Int, timeout: TimeInterval) async throws {
        capturedHosts.append((host, port, timeout))
        switch result {
        case .reachable:
            return
        case .failed:
            throw ProviderError.providerUnreachable(host: host)
        case .timedOut:
            throw ProviderError.providerUnreachable(host: host)
        }
    }
}

@Suite
enum TCPReachabilityTests {

    @Test("TCPReachability.check succeeds when probe returns reachable")
    static func checkSucceedsWhenReachable() async throws {
        let probe = StubReachabilityProbe(result: .reachable)
        let reachability = TCPReachability(probe: probe)

        try await reachability.check(host: "api.openai.com", port: 443, timeout: 2.0)

        #expect(probe.capturedHosts.count == 1)
        let captured = try #require(probe.capturedHosts.first)
        #expect(captured.host == "api.openai.com")
        #expect(captured.port == 443)
        #expect(captured.timeout == 2.0)
    }

    @Test("TCPReachability.check throws providerUnreachable when connection refused")
    static func checkThrowsWhenConnectionRefused() async throws {
        let probe = StubReachabilityProbe(result: .failed)
        let reachability = TCPReachability(probe: probe)

        await #expect(throws: ProviderError.self) {
            try await reachability.check(host: "localhost", port: 1, timeout: 2.0)
        }
    }

    @Test("TCPReachability.check throws providerUnreachable on timeout")
    static func checkThrowsOnTimeout() async throws {
        let probe = StubReachabilityProbe(result: .timedOut)
        let reachability = TCPReachability(probe: probe)

        await #expect(throws: ProviderError.self) {
            try await reachability.check(host: "example.com", port: 443, timeout: 0.1)
        }
    }

    @Test("TCPReachability.check throws providerUnreachable on DNS failure")
    static func checkThrowsOnDNSFailure() async throws {
        // DNS failure maps to .failed from the probe; the reachability layer
        // surfaces it as ProviderError.providerUnreachable regardless of
        // underlying cause (DNS, refused, timeout).
        let probe = StubReachabilityProbe(result: .failed)
        let reachability = TCPReachability(probe: probe)

        await #expect(throws: ProviderError.self) {
            try await reachability.check(host: "nonexistent.example.invalid", port: 443, timeout: 2.0)
        }
    }

    @Test("TCPReachability is Sendable and can be constructed with default probe")
    static func reachabilityIsSendableWithDefaultProbe() async throws {
        // Verifies the default initializer works and the type is Sendable.
        // The default probe uses real NWConnection — we don't invoke check()
        // here (no real network in tests), just confirm construction.
        let reachability = TCPReachability()
        #expect(type(of: reachability) == TCPReachability.self)
    }
}
