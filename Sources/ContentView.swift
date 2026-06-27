import SwiftUI

struct ContentView: View {
    @StateObject private var player   = YouTubePlayerController()
    @StateObject private var detector = SleepDetector()

    // ID de la vidéo YouTube (la partie après v= dans l'URL).
    // Ici l'exemple officiel de l'API ; à remplacer / rendre éditable.
    @State private var videoID = "M7lc1UVf-VE"

    @State private var lastTimecode = UserDefaults.standard.double(forKey: "lastTimecode")
    @State private var statusText = "En lecture"

    var body: some View {
        VStack(spacing: 16) {
            YouTubePlayerView(videoID: videoID, controller: player)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .background(Color.black)
                .cornerRadius(12)

            if !detector.isSupported {
                Text("Le suivi du visage (TrueDepth / Face ID) n'est pas disponible sur cet appareil.")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Circle()
                    .fill(detector.eyesClosed ? Color.orange : Color.green)
                    .frame(width: 12, height: 12)
                Text(detector.eyesClosed ? "Yeux fermés…" : "Éveillée")
                Spacer()
                Text(statusText)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .padding(.horizontal)

            if lastTimecode > 1 {
                Button {
                    player.load(videoID: videoID, startSeconds: lastTimecode)
                    detector.rearm()
                    statusText = "Reprise à \(format(lastTimecode))"
                } label: {
                    Label("Reprendre à \(format(lastTimecode))",
                          systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            detector.onAsleep = handleAsleep
            detector.start()
        }
        .onDisappear {
            detector.stop()
        }
    }

    // Endormissement détecté : on lit le time code, on met en pause, on sauvegarde.
    private func handleAsleep() {
        Task {
            let t = await player.currentTime()
            player.pause()
            lastTimecode = t
            UserDefaults.standard.set(t, forKey: "lastTimecode")
            statusText = "Endormie — pause à \(format(t))"
        }
    }

    private func format(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ContentView()
}
