import Foundation

struct VideoResult: Identifiable {
    let id: String            // videoId
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
}

enum YouTubeSearch {
    static func search(_ query: String) async throws -> [VideoResult] {
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        comps.queryItems = [
            .init(name: "part", value: "snippet"),
            .init(name: "type", value: "video"),
            .init(name: "maxResults", value: "20"),
            .init(name: "q", value: query),
            .init(name: "key", value: Secrets.youtubeAPIKey)
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.items.compactMap { item in
            guard let vid = item.id.videoId else { return nil }
            let thumb = item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.default?.url
            return VideoResult(
                id: vid,
                title: item.snippet.title,
                channelTitle: item.snippet.channelTitle,
                thumbnailURL: thumb.flatMap(URL.init(string:))
            )
        }
    }

    private struct SearchResponse: Decodable { let items: [Item] }
    private struct Item: Decodable { let id: ID; let snippet: Snippet }
    private struct ID: Decodable { let videoId: String? }
    private struct Snippet: Decodable {
        let title: String
        let channelTitle: String
        let thumbnails: Thumbnails
    }
    private struct Thumbnails: Decodable {
        let `default`: Thumb?
        let medium: Thumb?
        struct Thumb: Decodable { let url: String }
    }
}
