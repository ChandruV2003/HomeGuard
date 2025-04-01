import SwiftUI
import WebKit

struct CameraLivestreamView: UIViewRepresentable {
    let streamURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: streamURL)
        uiView.load(request)
    }
}

struct CameraLivestreamView_Previews: PreviewProvider {
    static var previews: some View {
        CameraLivestreamView(streamURL: URL(string: "http://192.168.4.2:81/stream")!)
    }
}
