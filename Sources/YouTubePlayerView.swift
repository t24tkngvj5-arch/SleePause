import SwiftUI
import WebKit

// MARK: - États du lecteur (IFrame Player API, onStateChange)
enum PlayerState: Int {
    case unstarted = -1
    case ended     = 0
    case playing   = 1
    case paused    = 2
    case buffering = 3
    case cued      = 5
    case unknown   = 99
}

// MARK: - Contenu YouTube reconnu à partir d'un lien collé
enum YouTubeContent {
    case video(String)
    case playlist(String)

    /// Extrait un ID de vidéo ou de playlist depuis une URL YouTube, ou un ID brut.
    static func parse(_ raw: String) -> YouTubeContent? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        if let comps = URLComponents(string: s) {
            let items = comps.queryItems ?? []
            // ?list=... a priorité (playlist)
            if let list = items.first(where: { $0.name == "list" })?.value, !list.isEmpty {
                return .playlist(list)
            }
            // ?v=...
            if let v = items.first(where: { $0.name == "v" })?.value, !v.isEmpty {
                return .video(v)
            }
            // youtu.be/ID
            if comps.host?.contains("youtu.be") == true {
                let id = comps.path.replacingOccurrences(of: "/", with: "")
                if !id.isEmpty { return .video(id) }
            }
            // /embed/ID, /shorts/ID, /v/ID
            let parts = comps.path.split(separator: "/").map(String.init)
            if let idx = parts.firstIndex(where: { ["embed", "shorts", "v"].contains($0) }),
               idx + 1 < parts.count {
                return .video(parts[idx + 1])
            }
        }

        // ID brut collé directement
        for prefix in ["PL", "UU", "LL", "FL", "RD", "OL"] where s.hasPrefix(prefix) {
            return .playlist(s)
        }
        if s.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil {
            return .video(s)
        }
        return nil
    }
}

// MARK: - Contrôleur
@MainActor
final class YouTubePlayerController: ObservableObject {
    fileprivate weak var webView: WKWebView?

    func play()  { webView?.evaluateJavaScript("player.playVideo();",  completionHandler: nil) }
    func pause() { webView?.evaluateJavaScript("player.pauseVideo();", completionHandler: nil) }

    func seek(to seconds: Double) {
        webView?.evaluateJavaScript("player.seekTo(\(seconds), true);", completionHandler: nil)
    }

    func load(videoID: String, startSeconds: Double = 0) {
        webView?.evaluateJavaScript("player.loadVideoById('\(videoID)', \(startSeconds));", completionHandler: nil)
    }

    func loadPlaylist(playlistID: String, startSeconds: Double = 0) {
        webView?.evaluateJavaScript(
            "player.loadPlaylist({listType: 'playlist', list: '\(playlistID)', index: 0, startSeconds: \(startSeconds)});",
            completionHandler: nil
        )
    }

    func load(_ content: YouTubeContent, startSeconds: Double = 0) {
        switch content {
        case .video(let id):    load(videoID: id, startSeconds: startSeconds)
        case .playlist(let id): loadPlaylist(playlistID: id, startSeconds: startSeconds)
        }
    }

    /// Time code courant en secondes (position où elle s'endort).
    func currentTime() async -> Double {
        guard let webView else { return 0 }
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("player.getCurrentTime();") { result, _ in
                continuation.resume(returning: (result as? NSNumber)?.doubleValue ?? 0)
            }
        }
    }
}

// MARK: - Vue (pont SwiftUI <-> WKWebView)
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @ObservedObject var controller: YouTubePlayerController
    var onReady: (() -> Void)? = nil
    var onStateChange: ((PlayerState) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onReady, onStateChange: onStateChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userController = WKUserContentController()
        userController.add(context.coordinator, name: "player")
        config.userContentController = userController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.loadHTMLString(Self.html(videoID: videoID),
                               baseURL: URL(string: "https://www.youtube.com"))
        controller.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onReady: (() -> Void)?
        let onStateChange: ((PlayerState) -> Void)?

        init(onReady: (() -> Void)?, onStateChange: ((PlayerState) -> Void)?) {
            self.onReady = onReady
            self.onStateChange = onStateChange
        }

        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            if body["event"] as? String == "ready" {
                onReady?()
            } else if let raw = body["state"] as? Int {
                onStateChange?(PlayerState(rawValue: raw) ?? .unknown)
            }
        }
    }

    private static func html(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            * { margin: 0; padding: 0; }
            html, body { background: #000; height: 100%; overflow: hidden; }
            #player { width: 100%; height: 100%; }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script src="https://www.youtube.com/iframe_api"></script>
          <script>
            var player;
            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                videoId: '\(videoID)',
                playerVars: { 'playsinline': 1, 'controls': 1, 'rel': 0, 'modestbranding': 1 },
                events: {
                  'onReady': function(e) {
                    window.webkit.messageHandlers.player.postMessage({ event: 'ready' });
                  },
                  'onStateChange': function(e) {
                    window.webkit.messageHandlers.player.postMessage({ state: e.data });
                  }
                }
              });
            }
          </script>
        </body>
        </html>
        """
    }
}
