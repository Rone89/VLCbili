import SwiftUI
import WebKit

struct UserSpaceWebView: View {
    let userID: String?
    let username: String

    var body: some View {
        Group {
            if let userID, let url = URL(string: "https://space.bilibili.com/\(userID)") {
                WebPageView(url: url)
            } else {
                ContentUnavailableView(
                    "无法打开用户空间",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(username)
                )
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebPageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
