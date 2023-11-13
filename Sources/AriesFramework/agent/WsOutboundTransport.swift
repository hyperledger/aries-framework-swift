
import Foundation
import WebSockets
import os

public class WsOutboundTransport: OutboundTransport {
    let logger = Logger(subsystem: "AriesFramework", category: "WsOutboundTransport")
    let agent: Agent
    var socket: WebSocket?
    var endpoint = ""
    let lock = NSLock()
    let CLOSE_BY_CLIENT = UInt16(3000)

    public init(_ agent: Agent) {
        self.agent = agent
    }

    public func sendPackage(_ package: OutboundPackage) async throws {
        lock.lock()
        defer { lock.unlock() }

        logger.debug("Sending outbound message to endpoint \(package.endpoint)")
        if socket == nil || endpoint != package.endpoint {
            socket = try await createSocket(endpoint: package.endpoint)
        }

        // swiftlint:disable:next force_try
        await socket!.send(data: try! JSONEncoder().encode(package.payload))
    }

    func createSocket(endpoint: String) async throws -> WebSocket {
        if socket != nil {
            await socket!.close(with: .applicationCode(CLOSE_BY_CLIENT))
        }

        socket = WebSocket(url: URL(string: endpoint)!)
        self.endpoint = endpoint
        try await openSocket()
        Task {
            await handleEvents()
        }

        return socket!
    }

    func openSocket() async throws {
        do {
            for try await event in socket! {
                switch event {
                case .open:
                    return
                default:
                    throw AriesFrameworkError.frameworkError("Unexpected WebSocket event: \(event)")
                }
            }
        } catch {
            print("Socket open error: \(error)")
            socket = nil
            throw AriesFrameworkError.frameworkError("Socket open failed: \(error)")
        }
    }

    func closeSocket() async {
        if socket != nil {
            await socket!.close(with: .applicationCode(CLOSE_BY_CLIENT))
            socket = nil
        }
    }

    func handleEvents() async {
        do {
            for try await event in socket! {
                // socket may have been closed in the loop
                if socket == nil {
                    return
                }

                switch event {
                case .binary(let data):
                    let encryptedMessage = try JSONDecoder().decode(EncryptedMessage.self, from: data)
                    try await agent.receiveMessage(encryptedMessage)
                case .text(let text):
                    let encryptedMessage = try JSONDecoder().decode(EncryptedMessage.self, from: text.data(using: .utf8)!)
                    try await agent.receiveMessage(encryptedMessage)
                case .close(code: let code, reason: _, wasClean: _):
                    logger.debug("Socket close: \(code.rawValue)")
                    if code != .applicationCode(CLOSE_BY_CLIENT) {
                        socket = nil
                    }
                    return
                default:
                    break
                }
            }
        } catch {
            print("Socket error: \(error)")
            socket = nil
        }
    }
}
