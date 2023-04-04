import SwiftUI

struct BaseView<Content>: View where Content: View {
    
    private let bgImage = Image.init(systemName: "m.circle.fill")
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body : some View {
        ZStack {
            bgImage
                .resizable()
                .opacity(0.2)
            content
        }
    }
}

struct BaseView_Previews: View {
    var body: some View {
        BaseView {
            Text("BaseView")
        }
    }
}
