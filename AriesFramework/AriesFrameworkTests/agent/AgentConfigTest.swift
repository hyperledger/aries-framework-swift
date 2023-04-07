//
//  AgentConfigTest.swift
//  AriesFrameworkTests
//
//  Created by soominlee on 2023/03/23.
//

import Foundation
import XCTest
@testable import AriesFramework

class AgentConfigTest: XCTestCase {
    
    /// all properties is codable except walletKey. walletKey must be secured.
    func testCodable() async throws {
        let walletKey = "whateverkey"
        let genesisPath = "/path/to/genesis/file"
        let config = AgentConfig(
            walletKey: walletKey,
            genesisPath: genesisPath)
        UserDefaults.standard.setValue(try? PropertyListEncoder().encode(config), forKey:"testAgentConfig")
        
        if let data = UserDefaults.standard.value(forKey:"testAgentConfig") as? Data {
            let config = try? PropertyListDecoder().decode(AgentConfig.self, from:data)
            XCTAssertNotNil(config)
            XCTAssertNil(config!.walletKey)
            XCTAssertEqual(config!.genesisPath, genesisPath)
        }
    }
}
