//
//  CredentialDetailView.swift
//  wallet-app-ios
//

import SwiftUI

struct CredentialDetailView: View {
    var credential: Credential

    var body: some View {
        List {
            ForEach(credential.attrs.sorted(by: >), id: \.key) { key, value in
                Section(header: Text(key)) {
                    Text(value)
                }
            }
        }
    }
}

struct CredentialDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CredentialDetailView(credential: Credential(referent: "test", attrs: [:], schema_id: "", cred_def_id: ""))
    }
}
