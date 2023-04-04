import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ConnectionsView()
                .tabItem {
                    Image(systemName: "list.dash")
                    Text("Connections")
                }
            CredentialsView()
                .tabItem {
                    Image(systemName: "list.dash")
                    Text("Credentials")
                }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
