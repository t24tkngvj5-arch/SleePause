import SwiftUI

struct ContentView: View {
    @StateObject private var player   = YouTubePlayerController()
    @StateObject private var detector = SleepDetector()

    private let defaultVideoID = "M7lc1UVf-VE"

    @State private var query = ""
    @State private var results: [VideoResult] = []
    @State private var searching = false
    @State private var lastTimecode = UserDefaults.standard.double(forKey: "lastTimecode")
    @State private var statusText = "En lecture"
    @State private var playerReady = false

    var body: some View {
        VStack(spacing: 12) {
            YouTubePlayerView(
                controller: player,
                onReady: {
                    playerReady = true
                    if let saved = UserDefaults.standard.string(forKey: "lastContentURL"),
                       let content = YouTubeContent.parse(saved) {
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
                TextField("Rechercher une vidéo ou coller un lien", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                    .onSubmit { submit() }
                Button("OK") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!playerReady || query.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            statusRow

            if searching {
                ProgressView().padding(.top, 8)
                Spacer()
            } else if !results.isEmpty {
                List(results) { r in
                    Button { pick(r) } label: {
                        HStack(spacing: 10) {
                            AsyncImage(url: r.thumbnailURL) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Color.gray.opacity(0.2) }
                            .frame(width: 120, height: 68).clipped().cornerRadius(6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title).font(.subheadline).lineLimit(2)
                                Text(r.channelTitle).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            } else {
                if lastTimecode > 1 {
                    Button {
                        player.seek(to: lastTimecode); player.play(); detector.reset()
                        statusText = "Reprise à \(format(lastTimecode))"
                    } label: {
                        Label("Reprendre à \(format(lastTimecode))", systemImage: "play.circle.fill").font(.headline)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
        .padding()
        .onAppear {
            detector.onAsleep = handleAsleep
            detector.onWake   = handleWake
            detector.start()
        }
        .onDisappear { detector.stop() }
    }

    private var statusRow: some View {
        HStack {
            Circle().fill(detector.eyesClosed ? Color.orange : Color.green).frame(width: 12, height: 12)
            Text(detector.isAsleep ? "Endormie 😴" : (detector.eyesClosed ? "Yeux fermés…" : "Éveillée"))
            Spacer()
            Text(statusText).foregroundColor(.secondary).lineLimit(1)
        }
        .font(.subheadline)
    }

    // Lien -> chargement direct. Sinon -> recherche.
    private func submit() {
        let input = query.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }
        if let content = YouTubeContent.parse(input) {
            player.load(content)
            UserDefaults.standard.set(input, forKey: "lastContentURL")
            resetTimecode(); detector.reset(); results = []; statusText = "Chargé"
            return
        }
        Task {
            searching = true; statusText = "Recherche…"
            do {
                results = try await YouTubeSearch.search(input)
                statusText = results.isEmpty ? "Aucun résultat" : "\(results.count) résultats"
            } catch {
                statusText = "Erreur de recherche"
            }
            searching = false
        }
    }

    private func pick(_ r: VideoResult) {
        player.load(videoID: r.id)
        UserDefaults.standard.set("https://youtu.be/\(r.id)", forKey: "lastContentURL")
        resetTimecode(); detector.reset(); results = []; query = ""
        statusText = "Lecture : \(r.title)"
    }

    private func resetTimecode() {
        lastTimecode = 0
        UserDefaults.standard.set(0.0, forKey: "lastTimecode")
    }

    private func handleAsleep() {
        Task {
            let t = await player.currentTime()
            player.pause()
            lastTimecode = t; UserDefaults.standard.set(t, forKey: "lastTimecode")
            statusText = "Endormie — pause à \(format(t))"
        }
    }

    private func handleWake() { player.play(); statusText = "Réveillée — reprise" }

    private func format(_ s: Double) -> String { String(format: "%d:%02d", Int(s)/60, Int(s)%60) }
}

#Preview { ContentView() }
