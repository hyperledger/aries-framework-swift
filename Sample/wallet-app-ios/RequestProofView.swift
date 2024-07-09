//
//  RequestProofView.swift
//  wallet-app-ios
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct RequestProofView: View {
    @State var qrReady: Bool = false
    @State var invitation = "hello world!"
    let credentialHandler = CredentialHandler.shared
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        VStack {
            Image(uiImage: generateQRCode(from: invitation))
                .resizable()
                .scaledToFit()
            if !qrReady {
                ProgressView()
            }
        }
        .task {
            do {
                try await agent!.startBLE()
                invitation = try await credentialHandler.createProofInvitation()
                qrReady = true
            } catch {
                print("Failed to create QR: \(error)")
            }
        }
        .onDisappear() {
            Task {
                try? await agent!.stopBLE()
            }
        }
    }
    
    func generateQRCode(from string: String) -> UIImage {
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

#Preview {
    RequestProofView()
}
