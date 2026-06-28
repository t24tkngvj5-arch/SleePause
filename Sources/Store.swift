import Foundation
import SwiftUI

enum Config {
    // ⚠️ URL de la page du lecteur (GitHub Pages). Doit matcher le nom du dépôt.
    static let playerPageURL = URL(string: "https://t24tkngvj5-arch.github.io/SleePause/player.html")!
}

struct VideoRef: Codable, Identifiable, Equatable {
    let id: String          // videoId
    var title: String
    var thumbnailURL: URL? { URL(string: "https://img.youtube.com/vi/\(id)/mqdefault.jpg") }
}

struct SleepEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let minutes: Double      // temps avant l'endormissement
}

final class AppState: ObservableObject {
    private let d = UserDefaults.standard

    // Réglages
    @Published var sleepThreshold: Double { didSet { d.set(sleepThreshold, forKey: "sleepThreshold") } }
    @Published var wakeThreshold:  Double { didSet { d.set(wakeThreshold,  forKey: "wakeThreshold") } }
    @Published var sensitivity:    Double { didSet { d.set(sensitivity,    forKey: "sensitivity") } }
    @Published var rewindSeconds:  Double { didSet { d.set(rewindSeconds,  forKey: "rewindSeconds") } }
    @Published var fadeEnabled:    Bool   { didSet { d.set(fadeEnabled,    forKey: "fadeEnabled") } }
    @Published var dimEnabled:     Bool   { didSet { d.set(dimEnabled,     forKey: "dimEnabled") } }
    @Published var keepAwake:      Bool   { didSet { d.set(keepAwake,      forKey: "keepAwake") } }
    @Published var partnerName:    String { didSet { d.set(partnerName,    forKey: "partnerName") } }

    // Bibliothèque
    @Published var favorites: [VideoRef] { didSet { saveJSON(favorites, "favorites") } }
    @Published var recents:   [VideoRef] { didSet { saveJSON(recents, "recents") } }
    @Published var sleepLog:  [SleepEntry] { didSet { saveJSON(sleepLog, "sleepLog") } }

    init() {
        sleepThreshold = d.object(forKey: "sleepThreshold") as? Double ?? 8
        wakeThreshold  = d.object(forKey: "wakeThreshold")  as? Double ?? 3
        sensitivity    = d.object(forKey: "sensitivity")    as? Double ?? 0.55
        rewindSeconds  = d.object(forKey: "rewindSeconds")  as? Double ?? 12
        fadeEnabled    = d.object(forKey: "fadeEnabled")    as? Bool ?? true
        dimEnabled     = d.object(forKey: "dimEnabled")     as? Bool ?? true
        keepAwake      = d.object(forKey: "keepAwake")      as? Bool ?? true
        partnerName    = d.string(forKey: "partnerName") ?? ""
        favorites = AppState.loadJSON("favorites") ?? []
        recents   = AppState.loadJSON("recents") ?? []
        sleepLog  = AppState.loadJSON("sleepLog") ?? []
    }

    func addRecent(_ v: VideoRef) {
        recents.removeAll { $0.id == v.id }
        recents.insert(v, at: 0)
        if recents.count > 12 { recents = Array(recents.prefix(12)) }
    }
    func isFavorite(_ id: String) -> Bool { favorites.contains { $0.id == id } }
    func toggleFavorite(_ v: VideoRef) {
        if isFavorite(v.id) { favorites.removeAll { $0.id == v.id } }
        else { favorites.insert(v, at: 0) }
    }

    func logSleep(minutes: Double) {
        sleepLog.append(SleepEntry(date: Date(), minutes: minutes))
        if sleepLog.count > 200 { sleepLog = Array(sleepLog.suffix(200)) }
    }
    var weeklyAverageMinutes: Double? {
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let recent = sleepLog.filter { $0.date >= weekAgo }
        guard !recent.isEmpty else { return nil }
        return recent.map(\.minutes).reduce(0, +) / Double(recent.count)
    }

    private func saveJSON<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { d.set(data, forKey: key) }
    }
    private static func loadJSON<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
