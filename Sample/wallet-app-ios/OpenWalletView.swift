//
//  OpenWalletView.swift
//  wallet-app-ios
//

import SwiftUI

struct OpenWalletView: View {
    @StateObject var walletState = WalletState()
    @StateObject var walletOpener = WalletOpener()

    var body: some View {
        VStack {
            if walletState.walletOpened {
                WalletMainView()
            } else {
                Text("Opening a wallet...")
                ProgressView()
            }
        }
        .task {
            await walletOpener.openWallet(walletState: walletState)
        }
    }
}

struct OpenWalletView_Previews: PreviewProvider {
    static var previews: some View {
        OpenWalletView()
    }
}
