
import Foundation
import os
import BlueSwift

public class BleOutboundTransport: OutboundTransport {
    let logger = Logger(subsystem: "AriesFramework", category: "BleOutboundTransport")
    let agent: Agent
    let central = BluetoothConnection.shared

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

        let connectionError = await withCheckedContinuation({ continuation in
            central.connect(peripheral) {  error in
                continuation.resume(returning: error)
            }
        })
        if connectionError != nil {
            throw AriesFrameworkError.frameworkError("Failed to connect to peripheral: \(String(describing: connectionError))")
        }

        let command = Command.data(try JSONEncoder().encode(package.payload))
        let sendError = await withCheckedContinuation({ continuation in
            peripheral.write(command: command, characteristic: characteristic) { error in
                continuation.resume(returning: error)
            }
        })
        if sendError != nil {
            throw AriesFrameworkError.frameworkError("Failed to send message to peripheral: \(String(describing: sendError))")
        }
        central.disconnect(peripheral)
    }

    func uuidFromUrl(_ url: String) throws -> String {
        let queryItems = URLComponents(string: url)?.queryItems
        if let uuid = queryItems?.first(where: { $0.name == "uuid" })?.value {
            return uuid
        }
        throw AriesFrameworkError.frameworkError("Invalid url: Cannot find uuid in url \(url)")
    }
}
