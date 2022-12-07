//
//  WalletMainView.swift
//  wallet-app-ios
//

import SwiftUI

enum MainMenu: Identifiable {
    case qrcode, list, loading
    var id: Int {
        hashValue
    }
}

struct WalletMainView: View {
    @State var invitation: String = ""
    @StateObject var credentialHandler = CredentialHandler.shared

    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List {
                        Button(action: {
                            credentialHandler.menu = .qrcode
                        }) {
                            Text("Connect")
                        }

                        Button(action: {
                            credentialHandler.menu = .list
                        }) {
                            Text("Credentials")
                        }
                    }
                    .navigationTitle("Wallet App")
                    .listStyle(.plain)

                    Spacer()

                    HStack {
                        TextField("invitation url", text: $invitation)
                            .textFieldStyle(.roundedBorder)

                        Button("Connect", action: {
                            QRCodeHandler().receiveInvitation(url: invitation)
                        })
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .sheet(item: $credentialHandler.menu) { item in
                switch item {
                case .qrcode:
                    QRScanView(handler: QRCodeHandler())
                case .list:
                    CredentialListView()
                case .loading:
                    Text("Processing ...")
                }
            }
            .alert(item: $credentialHandler.actionType) { item in
                switch item {
                case .credOffer:
                    return Alert(title: Text("Credential"), message: Text(credentialHandler.confirmMessage), primaryButton: .default(Text("OK"), action: {
                        credentialHandler.getCredential()
                    }), secondaryButton: .cancel())
                case .proofRequest:
                    return Alert(title: Text("Proof"), message: Text(credentialHandler.confirmMessage), primaryButton: .default(Text("OK"), action: {
                        credentialHandler.sendProof()
                    }), secondaryButton: .cancel())
                }
            }
            .alert(credentialHandler.alertMessage, isPresented: $credentialHandler.showAlert) {}
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        WalletMainView()
    }
}
