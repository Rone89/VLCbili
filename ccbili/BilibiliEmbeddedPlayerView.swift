//
//  BilibiliEmbeddedPlayerView.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/26.
//

import SwiftUI
import WebKit

struct BilibiliEmbeddedPlayerView: UIViewRepresentable {
    let bvid: String

    func makeCoordinator() -> Coordinator {
        Coordinator(bvid: bvid)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = true
        webView.customUserAgent = AppConfig.defaultUserAgent
        webView.allowsBackForwardNavigationGestures = false

        context.coordinator.loadVideoPageIfNeeded(in: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.bvid = bvid
        context.coordinator.loadVideoPageIfNeeded(in: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var bvid: String
        private var loadedBVID: String?

        init(bvid: String) {
            self.bvid = bvid
        }

        func loadVideoPageIfNeeded(in webView: WKWebView) {
            guard loadedBVID != bvid else {
                return
            }

            loadedBVID = bvid

            Task {
                await syncCookies(to: webView)

                await MainActor.run {
                    loadVideoPage(in: webView)
                }
            }
        }

        private func loadVideoPage(in webView: WKWebView) {
            guard let url = URL(string: "https://www.bilibili.com/video/\(bvid)?autoplay=0") else {
                return
            }

            var request = URLRequest(url: url)
            request.setValue(AppConfig.defaultUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")

            webView.load(request)
        }

        private func syncCookies(to webView: WKWebView) async {
            let cookies = HTTPCookieStorage.shared.cookies ?? []
            let biliCookies = cookies.filter { cookie in
                cookie.domain.contains("bilibili.com")
            }

            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore

            for cookie in biliCookies {
                await withCheckedContinuation { continuation in
                    cookieStore.setCookie(cookie) {
                        continuation.resume()
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectPlayerFocusedLayout(into: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }

            return nil
        }

        private func injectPlayerFocusedLayout(into webView: WKWebView) {
            let script = """
            (function() {
                const style = document.createElement('style');
                style.innerHTML = `
                    html, body {
                        background: #000 !important;
                    }

                    header,
                    .bili-header,
                    .bili-header__bar,
                    .right-container,
                    .left-container,
                    .ad-report,
                    .recommend-list-v1,
                    .video-toolbar-container,
                    .video-desc-container,
                    .video-reply-container,
                    .fixed-sidenav-storage,
                    .palette-button-wrap,
                    .floor-single-card,
                    .pop-live-small-mode,
                    .bpx-player-ending-panel {
                        display: none !important;
                    }

                    #app,
                    .video-container-v1,
                    .left-container-under-player,
                    .player-wrap,
                    .bpx-player-container,
                    .bpx-player-primary-area,
                    .bpx-player-video-area {
                        width: 100vw !important;
                        max-width: 100vw !important;
                        margin: 0 !important;
                        padding: 0 !important;
                        background: #000 !important;
                    }

                    .bpx-player-container,
                    .bpx-player-primary-area,
                    .bpx-player-video-area {
                        height: 100vh !important;
                    }

                    video {
                        object-fit: contain !important;
                    }
                `;
                document.head.appendChild(style);

                setTimeout(function() {
                    const player = document.querySelector('.bpx-player-container') ||
                                   document.querySelector('#bilibili-player') ||
                                   document.querySelector('video');

                    if (player) {
                        player.scrollIntoView({
                            behavior: 'instant',
                            block: 'center'
                        });
                    }
                }, 1000);
            })();
            """

            webView.evaluateJavaScript(script)
        }
    }
}
