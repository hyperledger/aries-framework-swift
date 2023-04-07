import Foundation
import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject var agent: AriesAgentFacade
    @State var showingAlert = false
    @State var error: Error? = nil
    
    var body: some View {
        
        VStack(alignment:.center) {
            VStack(alignment:.center) {
            Text("Verifiable Data Registries").font(.title)
                List (self.agent.availableNetworks, id: \.self, selection: $agent.selectedNetwork) { url in
                    VerifiableDataRegistryView(url: url)
                }.background(Color.blue).frame(maxHeight: 300)
            }.background(Color.yellow)
            
            VStack(alignment:.center) {
                Text("Wallet").font(.title)
                Image(systemName:"lock")
                TextField("Enter your PIN", text:$agent.walletKeySeed)
                    .frame(width:200)
                    .multilineTextAlignment(.center)
                if agent.isProvisioned {
                    Button(action: {Task{
                        do {
                            try await self.agent.start()
                            try await self.agent.connectionsUpdate()
                        } catch {
                            self.error = error
                            self.showingAlert = true
                        }
                    }}) {
                        Text("Open Wallet")
                    }.alert(isPresented: $showingAlert) {
                        Alert(title: Text("Error"), message: Text(error!.localizedDescription), dismissButton: .default(Text("Dismiss")))
                    }

                } else {
                    Button(action: {Task{
                        do {
                            try await self.agent.provisionAndStart()
                            try await self.agent.connectionsUpdate()
                        } catch {
                            self.error = error
                            self.showingAlert = true
                        }
                    }}) {
                        Text("Create Wallet")
                    }.alert(isPresented: $showingAlert) {
                        Alert(title: Text("Error"), message: Text(error!.localizedDescription), dismissButton: .default(Text("Dismiss")))
                    }
                }
            }
            .background(Color.green)
        }
        .background(Color.red)
    }
}

struct VerifiableDataRegistryView: View {
    let url: URL
    
    var body: some View {
        HStack {
            Image(systemName:"lock")
            Text(url.deletingPathExtension().lastPathComponent)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
