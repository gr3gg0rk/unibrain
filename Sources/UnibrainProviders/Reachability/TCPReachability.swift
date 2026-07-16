import Foundation
import UnibrainCore

#if canImport(Network)
import Network
#endif

/// Abstraction over the TCP pre-flight check enabling test injection.
///
/// Per CF-02: quick TCP connect probe to `{provider-host}:443` with a 2s
/// timeout. Returns on success; throws ``ProviderError/providerUnreachable``
/// on any failure (refused, timeout, DNS).
public protocol ReachabilityProbe: Sendable {
    /// Probe the given host:port with a timeout.
    ///
    /// - Parameters:
    ///   - host: Hostname or IP literal.
    ///   - port: TCP port (typically 443 for cloud providers).
    ///   - timeout: Maximum wait for connection establishment.
    /// - Throws: ``ProviderError/providerUnreachable`` when the endpoint
    ///   cannot be reached within `timeout`.
    func probe(host: String, port: Int, timeout: TimeInterval) async throws
}

/// TCP pre-flight reachability check per CF-02.
///
/// Used by every cloud provider client to fast-fail when the network is down
/// or a provider endpoint is unreachable. Avoids the 60s default `URLRequest`
/// timeout UX. The check is a single TCP connect attempt: success returns,
/// any failure throws ``ProviderError/providerUnreachable``.
///
/// Per T-06-16 (accept): false positives are harmless — the user gets the
/// standard CF-01 fallback sheet. No security impact.
///
/// On Darwin this wraps `NWConnection`. On Linux (CI), the production
/// initializer surfaces as `unsupportedPlatform` — tests inject a
/// ``StubReachabilityProbe`` to avoid real sockets.
public struct TCPReachability: ReachabilityProbe, Sendable {
    private let probeImpl: @Sendable (String, Int, TimeInterval) async throws -> Void

    /// Construct with an explicit probe closure (advanced use).
    public init(probe: @escaping @Sendable (String, Int, TimeInterval) async throws -> Void) {
        self.probeImpl = probe
    }

    /// Construct with a `ReachabilityProbe` delegate (preferred test path).
    public init(probe delegate: any ReachabilityProbe) {
        self.init(probe: { host, port, timeout in
            try await delegate.probe(host: host, port: port, timeout: timeout)
        })
    }

    #if canImport(Network)
    /// Production initializer — uses `NWConnection` for the TCP probe.
    public init() {
        self.init(probe: { host, port, timeout in
            try await Self.probeNWConnection(host: host, port: port, timeout: timeout)
        })
    }

    /// NWConnection-based probe (Darwin only).
    private static func probeNWConnection(host: String, port: Int, timeout: TimeInterval) async throws {
        guard let portValue = NWEndpoint.Port(rawValue: port) else {
            throw ProviderError.providerUnreachable(host: host)
        }
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: portValue)

        let connection = NWConnection(to: endpoint, using: .tcp)
        defer { connection.cancel() } // Cleanup — prevent leak

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            let resume: @Sendable (Error?) -> Void = { err in
                guard !resumed else { return }
                resumed = true
                if let err {
                    continuation.resume(throwing: err)
                } else {
                    continuation.resume()
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resume(nil)
                case .failed:
                    resume(ProviderError.providerUnreachable(host: host))
                case .cancelled:
                    resume(ProviderError.providerUnreachable(host: host))
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout race
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                resume(ProviderError.providerUnreachable(host: host))
            }
        }
    }
    #else
    /// Production initializer on Linux — NWConnection unavailable.
    /// Tests inject a stub; production cloud-client code runs on macOS/iOS.
    public init() {
        self.init(probe: { _, _, _ in
            throw ProviderError.unsupportedPlatform
        })
    }
    #endif

    public func probe(host: String, port: Int, timeout: TimeInterval) async throws {
        try await probeImpl(host, port, timeout)
    }

    /// Convenience entry point matching the plan's API surface.
    ///
    /// - Parameters:
    ///   - host: Hostname (e.g., `api.openai.com`).
    ///   - port: TCP port (typically 443).
    ///   - timeout: Seconds to wait before declaring unreachable (default 2s per CF-02).
    /// - Throws: ``ProviderError/providerUnreachable`` when unreachable.
    public func check(host: String, port: Int, timeout: TimeInterval = 2.0) async throws {
        try await probe(host: host, port: port, timeout: timeout)
    }
}
