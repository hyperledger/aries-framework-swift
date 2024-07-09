
import Foundation
import os
import BlueSwift
import Algorithms

public class BleOutboundTransport: OutboundTransport {
    let logger = Logger(subsystem: "AriesFramework", category: "BleOutboundTransport")
    let agent: Agent
    let central = BluetoothConnection.shared
    let chunkSize = 128
    static let EOF = "ARIES_BLE_EOF"

    init(_ agent: Agent) {
        self.agent = agent
    }

    public func sendPackage(_ package: OutboundPackage) async throws {
        logger.debug("Sending outbound message to endpoint \(package.endpoint)")
        let uuid = try uuidFromUrl(package.endpoint)
        let characteristic = try Characteristic(uuid: uuid)
        let service = try Service(uuid: uuid, characteristics: [characteristic])
        let configuration = try Configuration(services: [service], advertisement: uuid)
        let peripheral = Peripheral(configuration: configuration)

        let bleWaiter = AsyncWaiter(timeout: 10)
        var connectionError: ConnectionError?
        central.connect(peripheral) { error in
            connectionError = error
            bleWaiter.finish()
        }
        let success = try await bleWaiter.wait()
        try validateConnection(success: success, connectionError: connectionError)

        try await writeTo(peripheral: peripheral, characteristic: characteristic, payload: try JSONEncoder().encode(package.payload))
        central.disconnect(peripheral)
    }

    func writeTo(peripheral: Peripheral<Connectable>, characteristic: Characteristic, payload: Data) async throws {
        let bleWaiter = AsyncWaiter(timeout: 10)
        let chunks = payload.chunks(ofCount: chunkSize)
        let dataChunks = chunks.map { Data($0) }
        for chunk in dataChunks {
            let command = Command.data(chunk)
            var sendError: Error?
            peripheral.write(command: command, characteristic: characteristic) { error in
                sendError = error
                bleWaiter.finish()
            }
            let success = try await bleWaiter.wait()
            try validateWrite(success: success, sendError: sendError)
        }

        let command = Command.utf8String(BleOutboundTransport.EOF)
        var sendError: Error?
        peripheral.write(command: command, characteristic: characteristic) { error in
            sendError = error
            bleWaiter.finish()
        }
        let success = try await bleWaiter.wait()
        try validateWrite(success: success, sendError: sendError)
    }

    func validateWrite(success: Bool, sendError: Error?) throws {
        if !success {
            throw AriesFrameworkError.frameworkError("Timeout writing to peripheral")
        }
        if sendError != nil {
            throw AriesFrameworkError.frameworkError("Failed to send message to peripheral: \(String(describing: sendError))")
        }
    }

    func validateConnection(success: Bool, connectionError: ConnectionError?) throws {
        if !success {
            throw AriesFrameworkError.frameworkError("Timeout waiting for connection to peripheral")
        }
        if connectionError != nil {
            throw AriesFrameworkError.frameworkError("Failed to connect to peripheral: \(String(describing: connectionError))")
        }
    }

    func uuidFromUrl(_ url: String) throws -> String {
        let queryItems = URLComponents(string: url)?.queryItems
        if let uuid = queryItems?.first(where: { $0.name == "uuid" })?.value {
            return uuid
        }
        throw AriesFrameworkError.frameworkError("Invalid url: Cannot find uuid in url \(url)")
    }
}
