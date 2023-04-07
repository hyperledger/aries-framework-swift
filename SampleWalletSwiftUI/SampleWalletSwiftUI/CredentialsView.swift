import SwiftUI
import AriesFramework

struct CredentialsView: View {
    
    @EnvironmentObject var agent: AriesAgentFacade
    
    @State var showingAlert = false
    @State var error: Error? = nil
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List (self.agent.credentials, id: \.self) { c in
                        CredentialRecordView(credential: c)
                    }
                    .navigationTitle("Credentials")
                    .listStyle(.plain)
                    .background(Color.green)
                    .task {
                        do {
                            try? await agent.credentialsUpdate()
                        }
                    }
                    Spacer()
                    IssueCredentialControlView()
                }
            }
        }
    }
    
    func IssueCredentialControlView() -> some View {
        return HStack {
            
            Image(systemName: "icloud.and.arrow.down")
            
            .buttonStyle(.bordered)
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(error!.localizedDescription), dismissButton: .default(Text("Dismiss")))
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
