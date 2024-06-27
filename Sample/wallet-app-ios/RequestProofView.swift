//
//  RequestProofView.swift
//  wallet-app-ios
//

import SwiftUI

struct RequestProofView: View {
    @State var qrReady: Bool = false
    var body: some View {
        VStack {
            if qrReady {
                Text("ImageView will be here")
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    RequestProofView()
}
