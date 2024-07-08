
import Foundation
import os
import BlueSwift

public class BleInboundTransport: InboundTransport {
    let logger = Logger(subsystem: "AriesFramework", category: "BleInboundTransport")
    let agent: Agent
    let advertisement = BluetoothAdvertisement.shared
    var receivedMessage = Data()
    var uuid = ""
    /// The UUID used for BLE service and characteristic
    public var identifier: String {
        return uuid
    }

    init(agent: Agent) {
        self.agent = agent
    }

    public func start() async throws {
        uuid = UUID().uuidString
        let characteristic = try Characteristic(uuid: uuid)
        let service = try Service(uuid: uuid, characteristics: [characteristic])
        let configuration = try Configuration(services: [service], advertisement: uuid)
        let peripheral = Peripheral(configuration: configuration, advertisementData: [.servicesUUIDs(uuid)])

        let error = await withCheckedContinuation({ continuation in
            advertisement.advertise(peripheral: peripheral) { error in
                continuation.resume(returning: error)
            }
        })
        if error != nil {
            throw AriesFrameworkError.frameworkError("BLE advertisement failed: \(error!)")
        }
        logger.debug("BLE advertisement started!")

        advertisement.writeRequestCallback = { [weak self] characteristic, data in
            guard let data = data else { return }
            do {
                if String(data: data, encoding: .utf8) == BleOutboundTransport.EOF && self != nil {
                    let encryptedMessage = try JSONDecoder().decode(EncryptedMessage.self, from: self!.receivedMessage)
                    Task { [weak self] in
                        try await self?.agent.receiveMessage(encryptedMessage)
                    }
                    self?.receivedMessage = Data()
                } else {
                    self?.receivedMessage.append(data)
                }
            } catch {
                self?.logger.error("Error receiving message via BLE: \(error)")
            }
        }
    }

    public func stop() async throws {
        uuid = ""
        advertisement.stopAdvertising()
        logger.debug("BLE advertisement stoped")
    }

    public func endpoint(domain: String = "aries/endpoint") throws -> String {
        if uuid == "" {
            throw AriesFrameworkError.frameworkError("BleInboundTransport is not started yet")
        }
        return BleInboundTransport.urlFromUUID(uuid, domain: domain)
    }

    public static func urlFromUUID(_ uuid: String, domain: String = "aries/endpoint") -> String {
       return "ble://\(domain)?uuid=\(uuid)"
    }
}
