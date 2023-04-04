import SwiftUI
import CodeScanner
import AriesFramework

struct CredentialsView: View {
    
    @EnvironmentObject var agent: AriesAgentFacade
    
    var body: some View {
        NavigationView {
            VStack {
                List (self.agent.credentials, id: \.self, selection: $agent.selectedConnection) { c in
                    CredentialRecordView(credential: c)
                }
            }
            .navigationTitle("Credential List")
            .listStyle(.plain)
            
            .task {
                do {
                    try? await agent.credentialsUpdate()
                }
            }
        }
    }
}

struct CredentialRecordView: View {
    let credential: CredentialRecord
    
    var body: some View {
        HStack {
            Image(systemName:"phone.fill.connection")
            Text(credential.referent).frame(width:220).background(Color.blue)
            Text(credential.cred_def_id).frame(width:80, alignment: .leading).background(Color.red)
        }
    }
}

struct CredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        CredentialsView()
    }
}
