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
            Button(action: {
                Task {
                    do {
                        _ = try await agent.issueCredentialPropose()
                        try await agent.credentialsUpdate()
                    } catch {
                        self.error = error
                        self.showingAlert = true
                    }
                }
            }) {
                Image(systemName: "icloud.and.arrow.down")
            }
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
            Image(systemName:"text.badge.checkmark")
            Text(credential.referent).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(Color.blue)
        }
    }
}

struct CredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        CredentialsView()
    }
}
