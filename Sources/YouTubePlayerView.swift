import SwiftUI
import WebKit

// MARK: - États renvoyés par le lecteur YouTube
// Valeurs définies par l'IFrame Player API (onStateChange).
enum PlayerState: Int {
    case unstarted = -1
    case ended     = 0
    case playing   = 1
    case paused    = 2
    case buffering = 3
    case cued      = 5
    case unknown   = 99
}

// MARK: - Contrôleur
// Objet observable que la vue garde, et via lequel le reste de l'app
// pilote le lecteur (pause, reprise, lecture du time code...).
@MainActor
final class YouTubePlayerController: ObservableObject {
    fileprivate weak var webView: WKWebView?

    func play() {
        webView?.evaluateJavaScript("player.playVideo();", completionHandler: nil)
    }

    func pause() {
        webView?.evaluateJavaScript("player.pauseVideo();", completionHandler: nil)
    }

    func seek(to seconds: Double) {
        webView?.evaluateJavaScript("player.seekTo(\(seconds), true);", completionHandler: nil)
    }

    /// Charge une vidéo (et démarre à `startSeconds` — c'est la reprise).
    func load(videoID: String, startSeconds: Double = 0) {
        webView?.evaluateJavaScript(
            "player.loadVideoById('\(videoID)', \(startSeconds));",
            completionHandler: nil
        )
    }

    /// Renvoie le time code courant en secondes. C'est CE que veut ta copine :
    /// la position exacte au moment où elle s'endort.
    func currentTime() async -> Double {
        guard let webView else { return 0 }
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("player.getCurrentTime();") { result, _ in
                let value = (result as? NSNumber)?.doubleValue ?? 0
                continuation.resume(returning: value)
            }
        }
    }
}

// MARK: - Vue (pont SwiftUI <-> WKWebView)
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @ObservedObject var controller: YouTubePlayerController
    var onStateChange: ((PlayerState) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChange: onStateChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true                  // lecture en ligne, pas plein écran forcé
        config.mediaTypesRequiringUserActionForPlayback = []     // autorise la lecture programmée

        let userController = WKUserContentController()
        userController.add(context.coordinator, name: "player")  // canal JS -> Swift
        config.userContentController = userController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black

        // baseURL = youtube.com : sert d'origine pour l'IFrame API et fournit
        // le Referer exigé par les CGU de YouTube en contexte WebView.
        webView.loadHTMLString(Self.html(videoID: videoID),
                               baseURL: URL(string: "https://www.youtube.com"))

        controller.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: Coordinator — reçoit les événements du lecteur
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onStateChange: ((PlayerState) -> Void)?

        init(onStateChange: ((PlayerState) -> Void)?) {
            self.onStateChange = onStateChange
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            if let raw = body["state"] as? Int {
                onStateChange?(PlayerState(rawValue: raw) ?? .unknown)
            }
        }
    }

    // MARK: HTML embarqué (lecteur IFrame)
    private static func html(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport"
                content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
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
                playerVars: {
                  'playsinline': 1,
                  'controls': 1,
                  'rel': 0,
                  'modestbranding': 1
                },
                events: {
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
