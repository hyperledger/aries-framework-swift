//
//  QRScanView.swift
//  wallet-app-ios
//

import SwiftUI
import QRScanner

struct QRScanView: View {
    var handler: QRCodeHandler

    var body: some View {
        QRScannerSwiftUIView(handler: handler)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QRScanView_Previews: PreviewProvider {
    static var previews: some View {
        Text("QRScannerView")
    }
}

struct QRScannerSwiftUIView: UIViewRepresentable {
    var handler: QRCodeHandler

    func makeUIView(context: Context) -> QRScannerView {
        let screen = UIScreen.main.bounds.size
        let view = QRScannerView(frame: CGRect(x: 0, y: 0, width: screen.width, height: screen.height))
        return view
    }
    
    func updateUIView(_ qrScannerView: QRScannerView, context: Context) {
        qrScannerView.configure(delegate: handler)
        qrScannerView.startRunning()
    }
}
