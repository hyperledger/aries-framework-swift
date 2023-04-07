import SwiftUI

@main
struct SampleWalletSwiftUIApp: App {
    @ObservedObject var agent: AriesAgentFacade = AriesAgentFacade()
    var body: some Scene {
        WindowGroup {
            if agent.isReady {
                ContentView().environmentObject(agent)
            } else {
                OnboardingView().environmentObject(agent)
            }
        }
    }
}
