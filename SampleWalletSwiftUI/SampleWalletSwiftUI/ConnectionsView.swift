import SwiftUI
import AriesFramework

struct ConnectionsView: View {
    
    @EnvironmentObject var agent: AriesAgentFacade
    
    @State var showingAlert = false
    @State var error: Error? = nil
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List (self.agent.connections, id: \.self, selection: $agent.selectedConnection) { c in
                        ConnectionItemView(connection: c)
                    }
                    .navigationTitle("Connections")
                    .listStyle(.plain)
                    .background(Color.yellow)
                    .task {
                        do {
                            try? await agent.connectionsUpdate()
                        }
                    }
                    Spacer()
                    ManualConnectionView()
                }
            }
        }
    }
    
    func ManualConnectionView() -> some View {
        return HStack {
            Button(action: {
                Task {
                    do {
                        agent.connectionRequestInvitation()
                    } catch {
                        self.error = error
                        self.showingAlert = true
                    }
                }
            }) {
                Image(systemName: "icloud.and.arrow.down")
            }
            TextField("invitation url", text: $agent.connectionInvitation)
                .textFieldStyle(.roundedBorder)
            
            Button(action: {
                agent.connectionInvitation = ""
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            Button(action: {
                Task {
                    do {
                        _ = try await agent.connectionReceiveInvitation()
                    } catch {
                        self.error = error
                        self.showingAlert = true
                    }
                }
            }) {
                Image(systemName: "phone.fill.arrow.right")
            }
            .buttonStyle(.bordered)
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(error!.localizedDescription), dismissButton: .default(Text("Dismiss")))
            }
        }
    }
}



struct ConnectionItemView: View {
    let connection: ConnectionRecord
    
    var body: some View {
        HStack {
            Image(systemName:"phone.fill.connection")
            Text(connection.id).frame(width:220).background(Color.blue)
            Text(connection.state.rawValue).frame(width:80, alignment: .leading).background(Color.red)
        }
    }
}

struct ConnectionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsView()
    }
}
