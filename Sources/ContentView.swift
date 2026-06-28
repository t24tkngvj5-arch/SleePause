import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var player   = YouTubePlayerController()
    @StateObject private var detector = SleepDetector()

    private let defaultVideoID = "M7lc1UVf-VE"

    @State private var query = ""
    @State private var results: [VideoResult] = []
    @State private var searching = false
    @State private var lastTimecode = UserDefaults.standard.double(forKey: "lastTimecode")
    @State private var statusText = "En lecture"
    @State private var playerReady = false

    @State private var currentVideo: VideoRef?
    @State private var showSettings = false
    @State private var locked = false
    @State private var cinema = false

    @State private var showGoodnight = false
    @State private var goodnightText = ""

    @State private var watchStart: Date?
    @State private var savedBrightness: CGFloat?
    @State private var dimWork: DispatchWorkItem?

    var body: some View {
        ZStack {
            Color.black.opacity(cinema ? 1 : 0).ignoresSafeArea()

            VStack(spacing: 12) {
                playerWithControls
                if !cinema {
                    searchRow
                    statusRow
                    contentArea
                }
            }
            .padding(cinema ? 0 : 16)

            if showGoodnight { goodnightBanner }
            if locked { lockOverlay }
        }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(app) }
        .onAppear { setup() }
        .onDisappear { teardown() }
        .onChange(of: detector.eyesClosed) { handleEyes($0) }
        .onChange(of: app.sleepThreshold) { _ in syncDetector() }
        .onChange(of: app.wakeThreshold)  { _ in syncDetector() }
        .onChange(of: app.sensitivity)    { _ in syncDetector() }
    }

    // MARK: Lecteur + boutons superposés
    private var playerWithControls: some View {
        ZStack(alignment: .topTrailing) {
            YouTubePlayerView(
                controller: player,
                onReady: { onPlayerReady() },
                onError: { code in statusText = "Erreur YouTube \(code)" }
            )
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .background(Color.black)
            .cornerRadius(cinema ? 0 : 12)

            HStack(spacing: 16) {
                if let cur = currentVideo {
                    Button { app.toggleFavorite(cur) } label: {
                        Image(systemName: app.isFavorite(cur.id) ? "heart.fill" : "heart")
                    }
                }
                Button { withAnimation { locked = true } } label: { Image(systemName: "lock") }
                Button { withAnimation { cinema.toggle() } } label: {
                    Image(systemName: cinema ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .padding(8)
            .background(.black.opacity(0.35), in: Capsule())
            .padding(10)
        }
    }

    private var searchRow: some View {
        HStack {
            TextField("Rechercher ou coller un lien", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .onSubmit { submit() }
            Button { submit() } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(.borderedProminent)
                .disabled(!playerReady || query.trimmingCharacters(in: .whitespaces).isEmpty)
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(.bordered)
        }
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

    @ViewBuilder private var contentArea: some View {
        if searching {
            ProgressView().padding(.top, 8); Spacer()
        } else if !results.isEmpty {
            List(results) { r in
                Button { pick(VideoRef(id: r.id, title: r.title)) } label: {
                    HStack(spacing: 10) {
                        thumb(r.thumbnailURL, w: 120, h: 68)
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
            ScrollView {
                if lastTimecode > 1 {
                    Button { resumeFromSaved() } label: {
                        Label("Reprendre à \(format(lastTimecode))", systemImage: "play.circle.fill").font(.headline)
                    }
                    .buttonStyle(.bordered).padding(.vertical, 4)
                }
                if !app.favorites.isEmpty { librarySection("Favoris ❤️", app.favorites) }
                if !app.recents.isEmpty   { librarySection("Récents", app.recents) }
            }
        }
    }

    private func librarySection(_ title: String, _ items: [VideoRef]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { v in
                        Button { pick(v) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                thumb(v.thumbnailURL, w: 160, h: 90)
                                Text(v.title).font(.caption).lineLimit(2).frame(width: 160, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    private func thumb(_ url: URL?, w: CGFloat, h: CGFloat) -> some View {
        AsyncImage(url: url) { img in img.resizable().aspectRatio(contentMode: .fill) }
        placeholder: { Color.gray.opacity(0.2) }
        .frame(width: w, height: h).clipped().cornerRadius(6)
    }

    // MARK: superpositions
    private var goodnightBanner: some View {
        VStack {
            Text(goodnightText)
                .font(.title2.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(.indigo.opacity(0.85), in: Capsule())
                .padding(.top, 60)
            Spacer()
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private var lockOverlay: some View {
        ZStack {
            Color.black.opacity(0.001).ignoresSafeArea().contentShape(Rectangle())
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.title3)
                Text("Maintenir pour déverrouiller").font(.caption)
            }
            .foregroundColor(.white).padding(12)
            .background(.black.opacity(0.45), in: Capsule())
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 40)
        }
        .onLongPressGesture(minimumDuration: 0.8) { withAnimation { locked = false } }
    }

    // MARK: cycle de vie
    private func setup() {
        syncDetector()
        detector.onAsleep = handleAsleep
        detector.onWake   = handleWake
        detector.start()
        if app.keepAwake { UIApplication.shared.isIdleTimerDisabled = true }
        presentGoodnight()
    }
    private func teardown() {
        detector.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        restoreBrightness()
    }
    private func syncDetector() {
        detector.sleepThreshold = app.sleepThreshold
        detector.wakeThreshold  = app.wakeThreshold
        detector.closedCutoff   = Float(app.sensitivity)
    }

    private func onPlayerReady() {
        playerReady = true
        if let saved = UserDefaults.standard.string(forKey: "lastContentURL"),
           let content = YouTubeContent.parse(saved) {
            player.load(content, startSeconds: lastTimecode > 1 ? lastTimecode : 0)
            if case .video(let id) = content { currentVideo = VideoRef(id: id, title: "Vidéo") }
        } else {
            player.load(videoID: defaultVideoID)
        }
        watchStart = Date()
    }

    private func submit() {
        let input = query.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }
        if let content = YouTubeContent.parse(input) {
            player.load(content)
            UserDefaults.standard.set(input, forKey: "lastContentURL")
            if case .video(let id) = content {
                let v = VideoRef(id: id, title: "Vidéo"); currentVideo = v; app.addRecent(v)
            } else { currentVideo = nil }
            resetTimecode(); detector.reset(); results = []; query = ""
            watchStart = Date(); statusText = "Chargé"
            return
        }
        Task {
            searching = true; statusText = "Recherche…"
            do {
                results = try await YouTubeSearch.search(input)
                statusText = results.isEmpty ? "Aucun résultat" : "\(results.count) résultats"
            } catch { statusText = "Erreur de recherche" }
            searching = false
        }
    }

    private func pick(_ v: VideoRef) {
        player.load(videoID: v.id)
        UserDefaults.standard.set("https://youtu.be/\(v.id)", forKey: "lastContentURL")
        currentVideo = v; app.addRecent(v)
        resetTimecode(); detector.reset(); results = []; query = ""
        watchStart = Date(); statusText = "Lecture : \(v.title)"
    }

    private func resumeFromSaved() {
        player.seek(to: lastTimecode); player.setVolume(100); player.play()
        detector.reset(); watchStart = Date(); statusText = "Reprise à \(format(lastTimecode))"
    }

    private func resetTimecode() { lastTimecode = 0; UserDefaults.standard.set(0.0, forKey: "lastTimecode") }

    // Endormie : fondu sonore -> pause -> sauvegarde -> journal
    private func handleAsleep() {
        Task {
            let t = await player.currentTime()
            if app.fadeEnabled {
                for v in stride(from: 100, through: 0, by: -10) {
                    player.setVolume(v); try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
            player.pause()
            player.setVolume(100)
            lastTimecode = t; UserDefaults.standard.set(t, forKey: "lastTimecode")
            if let start = watchStart {
                app.logSleep(minutes: Date().timeIntervalSince(start) / 60)
                watchStart = nil
            }
            statusText = "Endormie — pause à \(format(t))"
        }
    }

    // Réveillée : retour en arrière + fondu d'entrée + reprise
    private func handleWake() {
        restoreBrightness()
        let target = max(0, lastTimecode - app.rewindSeconds)
        player.seek(to: target)
        if app.fadeEnabled {
            player.setVolume(0); player.play()
            Task { for v in stride(from: 0, through: 100, by: 12) { player.setVolume(v); try? await Task.sleep(nanoseconds: 180_000_000) } }
        } else {
            player.setVolume(100); player.play()
        }
        watchStart = Date()
        statusText = "Réveillée — reprise à \(format(target))"
    }

    // Luminosité : baisse après ~1,5 s les yeux fermés, restaure à l'ouverture
    private func handleEyes(_ closed: Bool) {
        guard app.dimEnabled else { return }
        if closed {
            let work = DispatchWorkItem { dimScreen() }
            dimWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        } else {
            dimWork?.cancel(); restoreBrightness()
        }
    }
    private func dimScreen() {
        if savedBrightness == nil { savedBrightness = UIScreen.main.brightness }
        UIScreen.main.brightness = 0.12
    }
    private func restoreBrightness() {
        if let b = savedBrightness { UIScreen.main.brightness = b; savedBrightness = nil }
    }

    // Mot de bonne nuit
    private func presentGoodnight() {
        let phrases = ["Bonne nuit", "Fais de beaux rêves", "Dors bien", "Douce nuit", "Repose-toi bien"]
        let emojis  = ["🌙", "✨", "💤", "🌟"]
        let p = phrases.randomElement() ?? "Bonne nuit"
        let e = emojis.randomElement() ?? "🌙"
        goodnightText = "\(p), \(Config.partnerName) \(e)"
        withAnimation(.easeIn(duration: 0.5)) { showGoodnight = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.8)) { showGoodnight = false }
        }
    }

    private func format(_ s: Double) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }
}

#Preview { ContentView().environmentObject(AppState()) }
