//
//  CredentialListView.swift
//  wallet-app-ios
//

import SwiftUI
import Indy

class CredentialList: ObservableObject {
    @Published var list: [Credential] = []
}

struct Credential : Codable {
    var referent: String
    var attrs: [String: String]
    var schema_id: String
    var cred_def_id: String
    var rev_reg_id: String?
    var cred_rev_id: String?
}

struct CredentialListView: View {
    @StateObject var credentials: CredentialList = CredentialList()
    var body: some View {
        NavigationView {            
            List {
                ForEach($credentials.list, id: \.referent) { credential in
                    NavigationLink(destination: CredentialDetailView(credential: credential.wrappedValue)) {
                        let description = "Credential " + credential.wrappedValue.referent
                        Text(description)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Credential List")
            .task {
                if let credentialsJson = try! await IndyAnoncreds.proverGetCredentials(forFilter: "{}", walletHandle: agent!.wallet.handle!) {
                    self.credentials.list = try! JSONDecoder().decode([Credential].self, from: credentialsJson.data(using: .utf8)!)
                }
            }
        }
    }
}

struct CredentialListView_Previews: PreviewProvider {
    static var previews: some View {
        CredentialListView()
    }
}
