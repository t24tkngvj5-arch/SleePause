import SwiftUI

struct ContentView: View {
    @StateObject private var player   = YouTubePlayerController()
    @StateObject private var detector = SleepDetector()

    private let defaultVideoID = "M7lc1UVf-VE"

    @State private var urlInput = ""
    @State private var lastTimecode = UserDefaults.standard.double(forKey: "lastTimecode")
    @State private var statusText = "En lecture"
    @State private var playerReady = false

    var body: some View {
        VStack(spacing: 16) {
            YouTubePlayerView(
                controller: player,
                onReady: {
                    playerReady = true
                    if let saved = UserDefaults.standard.string(forKey: "lastContentURL"),
                       let content = YouTubeContent.parse(saved) {
                        urlInput = saved
                        player.load(content, startSeconds: lastTimecode > 1 ? lastTimecode : 0)
                    } else {
                        player.load(videoID: defaultVideoID)
                    }
                },
                onError: { code in statusText = "Erreur YouTube \(code)" }
            )
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .background(Color.black)
            .cornerRadius(12)

            HStack {
                TextField("Colle un lien YouTube (vidéo ou playlist)", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Button("Charger") { loadFromInput() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!playerReady || urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !detector.isSupported {
                Text("Le suivi du visage (TrueDepth / Face ID) n'est pas disponible sur cet appareil.")
                    .font(.footnote).foregroundColor(.red).multilineTextAlignment(.center)
            }

            HStack {
                Circle().fill(detector.eyesClosed ? Color.orange : Color.green).frame(width: 12, height: 12)
                Text(detector.eyesClosed ? "Yeux fermés…" : "Éveillée")
                Spacer()
                Text(statusText).foregroundColor(.secondary)
            }
            .font(.subheadline).padding(.horizontal)

            if lastTimecode > 1 {
                Button {
                    player.seek(to: lastTimecode); player.play(); detector.rearm()
                    statusText = "Reprise à \(format(lastTimecode))"
                } label: {
                    Label("Reprendre à \(format(lastTimecode))", systemImage: "play.circle.fill").font(.headline)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding()
        .onAppear { detector.onAsleep = handleAsleep; detector.start() }
        .onDisappear { detector.stop() }
    }

    private func loadFromInput() {
        guard let content = YouTubeContent.parse(urlInput) else { statusText = "Lien non reconnu"; return }
        player.load(content)
        UserDefaults.standard.set(urlInput, forKey: "lastContentURL")
        lastTimecode = 0; UserDefaults.standard.set(0.0, forKey: "lastTimecode")
        detector.rearm(); statusText = "Chargé"
    }

    private func handleAsleep() {
        Task {
            let t = await player.currentTime()
            player.pause()
            lastTimecode = t; UserDefaults.standard.set(t, forKey: "lastTimecode")
            statusText = "Endormie — pause à \(format(t))"
        }
    }

    private func format(_ s: Double) -> String { String(format: "%d:%02d", Int(s)/60, Int(s)%60) }
}

#Preview { ContentView() }
