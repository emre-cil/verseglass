import Foundation
import VerseglassCore

@MainActor
final class LyricsClient {
    private let cache: LyricCache
    private let session: URLSession

    init(cache: LyricCache, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    func discover(title: String, artist: String, duration: TimeInterval?) async -> LyricDiscovery {
        let candidates = TrackText.lookupCandidates(title: title, artist: artist)
        let primary = candidates[0]
        let key = LyricCache.cacheKey(artist: primary.artist, title: primary.title, duration: duration)
        let cached = cache.load(key: key)
        if let cached, cached.record == nil {
            return LyricDiscovery(match: nil, alternatives: [], failed: false)
        }
        var pooled: [LyricRecord] = []
        var poolTitle = primary.title
        var poolArtist = primary.artist
        var failed = false
        for candidate in candidates {
            let gathered = await gather(title: candidate.title, artist: candidate.artist, duration: duration)
            if gathered.failed { failed = true }
            let ranked = LRCLIB.rank(
                from: gathered.records,
                title: candidate.title,
                artist: candidate.artist,
                duration: duration
            )
            if !ranked.isEmpty {
                pooled = ranked
                poolTitle = candidate.title
                poolArtist = candidate.artist
                break
            }
        }
        let best = LRCLIB.choose(from: pooled, title: poolTitle, artist: poolArtist, duration: duration) ?? cached?.record
        if pooled.isEmpty, let best {
            pooled = [best]
        }
        if let best {
            cache.save(key: key, record: best)
        } else if pooled.isEmpty, !failed {
            cache.save(key: key, record: nil)
        }
        return LyricDiscovery(
            match: best,
            alternatives: Array(pooled.prefix(8)),
            failed: best == nil && pooled.isEmpty && failed
        )
    }

    private func gather(title: String, artist: String, duration: TimeInterval?) async -> (records: [LyricRecord], failed: Bool) {
        var records: [LyricRecord] = []
        var failed = false
        switch await fetch(LRCLIB.getURL(title: title, artist: artist, duration: duration)) {
        case .body(let data):
            if let record = try? LRCLIB.decodeRecord(from: data) {
                records.append(record)
            } else {
                failed = true
            }
        case .missing:
            break
        case .failed:
            failed = true
        }
        switch await fetch(LRCLIB.searchURL(title: title, artist: artist)) {
        case .body(let data):
            if let list = try? LRCLIB.decodeSearch(from: data) {
                records.append(contentsOf: list)
            } else {
                failed = true
            }
        case .missing:
            break
        case .failed:
            failed = true
        }
        return (records, failed)
    }

    private func fetch(_ url: URL?) async -> HTTPBody {
        guard let url else { return .failed }
        var request = URLRequest(url: url)
        request.setValue("Verseglass/1.2.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }
            if http.statusCode == 404 { return .missing }
            guard (200..<300).contains(http.statusCode) else { return .failed }
            return .body(data)
        } catch {
            return .failed
        }
    }
}

struct LyricDiscovery: Sendable {
    var match: LyricRecord?
    var alternatives: [LyricRecord]
    var failed: Bool
}

private enum HTTPBody {
    case body(Data)
    case missing
    case failed
}
