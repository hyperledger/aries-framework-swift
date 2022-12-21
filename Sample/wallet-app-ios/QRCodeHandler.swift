//
//  QRCodeHandler.swift
//  wallet-app-ios
//

import SwiftUI
import CodeScanner

class QRCodeHandler {
    let credentialHandler = CredentialHandler.shared
    
    public func receiveInvitation(url: String) {
        Task {
            do {
                let (_, connection) = try await agent!.oob.receiveInvitationFromUrl(url)
                await credentialHandler.showSimpleAlert(message: "Connected with \(connection?.theirLabel ?? "unknown agent")")
            } catch {
                print(error)
                await credentialHandler.reportError()
            }
        }
    }

    @MainActor public func handleResult(_ result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            print("Scanned code: [\(result.string)]")
            credentialHandler.menu = nil
            receiveInvitation(url: result.string.trimmingCharacters(in: .whitespacesAndNewlines))
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
}
