import SwiftUI
import WebKit

enum PlayerState: Int {
    case unstarted = -1, ended = 0, playing = 1, paused = 2, buffering = 3, cued = 5, unknown = 99
}

enum YouTubeContent {
    case video(String)
    case playlist(String)

    static func parse(_ raw: String) -> YouTubeContent? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let comps = URLComponents(string: s) {
            let items = comps.queryItems ?? []
            if let list = items.first(where: { $0.name == "list" })?.value, !list.isEmpty { return .playlist(list) }
            if let v = items.first(where: { $0.name == "v" })?.value, !v.isEmpty { return .video(v) }
            if comps.host?.contains("youtu.be") == true {
                let id = comps.path.replacingOccurrences(of: "/", with: "")
                if !id.isEmpty { return .video(id) }
            }
            let parts = comps.path.split(separator: "/").map(String.init)
            if let idx = parts.firstIndex(where: { ["embed", "shorts", "v", "live"].contains($0) }), idx + 1 < parts.count {
                return .video(parts[idx + 1])
            }
        }
        for prefix in ["PL", "UU", "LL", "FL", "RD", "OL"] where s.hasPrefix(prefix) { return .playlist(s) }
        if s.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil { return .video(s) }
        return nil
    }
}

// Contrôleur non isolé : chaque appel JS est renvoyé sur le thread principal,
// donc utilisable depuis n'importe quel contexte (Task, callbacks ARKit...).
final class YouTubePlayerController: ObservableObject {
    fileprivate weak var webView: WKWebView?

    private func js(_ s: String) {
        if Thread.isMainThread { webView?.evaluateJavaScript(s, completionHandler: nil) }
        else { DispatchQueue.main.async { self.webView?.evaluateJavaScript(s, completionHandler: nil) } }
    }

    func play()  { js("player.playVideo();") }
    func pause() { js("player.pauseVideo();") }
    func seek(to seconds: Double) { js("player.seekTo(\(seconds), true);") }
    func setVolume(_ v: Int) { js("player.setVolume(\(max(0, min(100, v))));") }
    func load(videoID: String, startSeconds: Double = 0) { js("player.loadVideoById('\(videoID)', \(startSeconds));") }
    func loadPlaylist(playlistID: String, startSeconds: Double = 0) {
        js("player.loadPlaylist({listType:'playlist', list:'\(playlistID)', index:0, startSeconds:\(startSeconds)});")
    }
    func load(_ content: YouTubeContent, startSeconds: Double = 0) {
        switch content {
        case .video(let id):    load(videoID: id, startSeconds: startSeconds)
        case .playlist(let id): loadPlaylist(playlistID: id, startSeconds: startSeconds)
        }
    }
    func currentTime() async -> Double {
        await withCheckedContinuation { c in
            DispatchQueue.main.async {
                guard let wv = self.webView else { c.resume(returning: 0); return }
                wv.evaluateJavaScript("player.getCurrentTime();") { r, _ in
                    c.resume(returning: (r as? NSNumber)?.doubleValue ?? 0)
                }
            }
        }
    }
}

struct YouTubePlayerView: UIViewRepresentable {
    @ObservedObject var controller: YouTubePlayerController
    var onReady: (() -> Void)?
    var onStateChange: ((PlayerState) -> Void)?
    var onError: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(onReady: onReady, onStateChange: onStateChange, onError: onError) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let uc = WKUserContentController()
        uc.add(context.coordinator, name: "player")
        config.userContentController = uc

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: Config.playerPageURL))
        controller.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onReady: (() -> Void)?
        let onStateChange: ((PlayerState) -> Void)?
        let onError: ((Int) -> Void)?
        init(onReady: (() -> Void)?, onStateChange: ((PlayerState) -> Void)?, onError: ((Int) -> Void)?) {
            self.onReady = onReady; self.onStateChange = onStateChange; self.onError = onError
        }
        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            if body["event"] as? String == "ready" { onReady?() }
            else if let raw = body["state"] as? Int { onStateChange?(PlayerState(rawValue: raw) ?? .unknown) }
            else if let err = body["error"] as? Int { onError?(err) }
        }
    }
}
