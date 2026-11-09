import Foundation

public struct LyricRecord: Codable, Equatable, Sendable {
    public var id: Int?
    public var trackName: String
    public var artistName: String
    public var albumName: String?
    public var duration: Double
    public var instrumental: Bool
    public var plainLyrics: String?
    public var syncedLyrics: String?

    public init(
        id: Int? = nil,
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: Double,
        instrumental: Bool = false,
        plainLyrics: String? = nil,
        syncedLyrics: String? = nil
    ) {
        self.id = id
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }

    public var hasSyncedLyrics: Bool {
        guard let syncedLyrics else { return false }
        return !syncedLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case id
        case trackName
        case artistName
        case albumName
        case duration
        case instrumental
        case plainLyrics
        case syncedLyrics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        trackName = try container.decode(String.self, forKey: .trackName)
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName) ?? ""
        albumName = try container.decodeIfPresent(String.self, forKey: .albumName)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        instrumental = try container.decodeIfPresent(Bool.self, forKey: .instrumental) ?? false
        plainLyrics = try container.decodeIfPresent(String.self, forKey: .plainLyrics)
        let synced = try container.decodeIfPresent(String.self, forKey: .syncedLyrics)
        if let synced, synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            syncedLyrics = nil
        } else {
            syncedLyrics = synced
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(trackName, forKey: .trackName)
        try container.encode(artistName, forKey: .artistName)
        try container.encodeIfPresent(albumName, forKey: .albumName)
        try container.encode(duration, forKey: .duration)
        try container.encode(instrumental, forKey: .instrumental)
        try container.encodeIfPresent(plainLyrics, forKey: .plainLyrics)
        try container.encodeIfPresent(syncedLyrics, forKey: .syncedLyrics)
    }
}

public enum LRCLIB {
    public static func getURL(title: String, artist: String, duration: TimeInterval?) -> URL? {
        url(path: "/api/get", title: title, artist: artist, duration: duration)
    }

    public static func searchURL(title: String, artist: String) -> URL? {
        url(path: "/api/search", title: title, artist: artist, duration: nil)
    }

    public static func decodeRecord(from data: Data) throws -> LyricRecord {
        try JSONDecoder().decode(LyricRecord.self, from: data)
    }

    public static func decodeSearch(from data: Data) throws -> [LyricRecord] {
        try JSONDecoder().decode([LyricRecord].self, from: data)
    }

    /// Picks a record that matches the query. A weak title-only hit is rejected
    /// when the artist was known and does not match.
    public static func choose(
        from records: [LyricRecord],
        title: String,
        artist: String,
        duration: TimeInterval?
    ) -> LyricRecord? {
        let wantedTitle = TrackText.normalize(TrackText.queryTitle(title))
        let wantedArtist = TrackText.normalize(artist)
        let ranked = records
            .map { record -> (LyricRecord, Int) in
                (record, score(record, title: wantedTitle, artist: wantedArtist, duration: duration))
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.hasSyncedLyrics != rhs.0.hasSyncedLyrics {
                    return lhs.0.hasSyncedLyrics && !rhs.0.hasSyncedLyrics
                }
                return durationDistance(lhs.0, duration: duration) < durationDistance(rhs.0, duration: duration)
            }
        guard let best = ranked.first, best.1 >= 5 else { return nil }
        return best.0
    }

    /// Near matches the automatic picker can reject, highest score first.
    /// The menu offers these when the best hit is wrong or missing.
    public static func rank(
        from records: [LyricRecord],
        title: String,
        artist: String,
        duration: TimeInterval?,
        minimumScore: Int = 3
    ) -> [LyricRecord] {
        let wantedTitle = TrackText.normalize(TrackText.queryTitle(title))
        let wantedArtist = TrackText.normalize(artist)
        var seen: Set<String> = []
        let unique = records.filter { record in
            let lyric = record.syncedLyrics ?? ""
            let key = "\(TrackText.normalize(record.artistName))|\(TrackText.normalize(record.trackName))|\(lyric)"
            return seen.insert(key).inserted
        }
        return unique
            .map { record -> (LyricRecord, Int) in
                (record, score(record, title: wantedTitle, artist: wantedArtist, duration: duration))
            }
            .filter { $0.1 >= minimumScore && $0.0.hasSyncedLyrics && !$0.0.instrumental }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return durationDistance(lhs.0, duration: duration) < durationDistance(rhs.0, duration: duration)
            }
            .map(\.0)
    }

    private static func url(path: String, title: String, artist: String, duration: TimeInterval?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "lrclib.net"
        components.path = path
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        if let duration {
            items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        components.queryItems = items
        return components.url
    }

    private static func score(
        _ record: LyricRecord,
        title: String,
        artist: String,
        duration: TimeInterval?
    ) -> Int {
        let recordTitle = TrackText.normalize(record.trackName)
        let recordArtist = TrackText.normalize(record.artistName)
        var score = 0
        if recordTitle == title {
            score += 5
        } else if !title.isEmpty, recordTitle.contains(title) || title.contains(recordTitle) {
            score += 3
        }
        if !artist.isEmpty {
            if recordArtist == artist {
                score += 5
            } else if recordArtist.contains(artist) || artist.contains(recordArtist) {
                score += 2
            } else {
                return -100
            }
        } else {
            score += 1
        }
        if let duration, record.duration > 0 {
            let diff = abs(record.duration - duration)
            if diff <= 2 {
                score += 4
            } else if diff <= 5 {
                score += 2
            } else if diff > 15 {
                score -= 6
            }
        }
        if record.hasSyncedLyrics {
            score += 1
        }
        if record.instrumental {
            score -= 3
        }
        return score
    }

    private static func durationDistance(_ record: LyricRecord, duration: TimeInterval?) -> Double {
        guard let duration else { return 0 }
        return abs(record.duration - duration)
    }
}
