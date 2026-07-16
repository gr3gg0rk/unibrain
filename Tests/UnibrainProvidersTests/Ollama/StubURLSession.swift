import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import UnibrainProviders

/// Stub URLSession implementation returning canned responses for Ollama tests.
public struct StubURLSession: HTTPSession {
    public enum Responder: Sendable {
        case success(body: String)
        case status(code: Int, body: String)
        case connectionFailure
        case timedOut
    }

    public let responder: Responder
    public init(responder: Responder) { self.responder = responder }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        switch responder {
        case .success(let body):
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Data(body.utf8), http)
        case .status(let code, let body):
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: code,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(body.utf8), http)
        case .connectionFailure:
            throw URLError(.cannotConnectToHost)
        case .timedOut:
            throw URLError(.timedOut)
        }
    }
}
