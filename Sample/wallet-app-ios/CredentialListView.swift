//
//  CredentialListView.swift
//  wallet-app-ios
//

import SwiftUI
import AriesFramework
import Anoncreds

class CredentialList: ObservableObject {
    @Published var list: [CredentialInfo] = []
}

struct CredentialInfo : Decodable {
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
                self.credentials.list = try! (await agent!.credentialRepository.getAll()).map { record in
                    let credential = try Credential(json: record.credential)
                    return CredentialInfo(
                        referent: record.credentialId,
                        attrs: credential.values(),
                        schema_id: credential.schemaId(),
                        cred_def_id: credential.credDefId(),
                        rev_reg_id: credential.revRegId(),
                        cred_rev_id: credential.revRegIndex().map { String($0) })
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
