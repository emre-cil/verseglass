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

    func load(title: String, artist: String, duration: TimeInterval?) async -> LyricLookup {
        let candidates = TrackText.lookupCandidates(title: title, artist: artist)
        let primary = candidates[0]
        let key = LyricCache.cacheKey(artist: primary.artist, title: primary.title, duration: duration)
        if let entry = cache.load(key: key), let record = entry.record {
            return .match(record)
        }
        var failed = false
        for candidate in candidates {
            switch await resolve(title: candidate.title, artist: candidate.artist, duration: duration) {
            case .match(let record):
                cache.save(key: key, record: record)
                return .match(record)
            case .miss:
                continue
            case .failed:
                failed = true
            }
        }
        if failed { return .failed }
        cache.save(key: key, record: nil)
        return .miss
    }

    private func resolve(title: String, artist: String, duration: TimeInterval?) async -> LyricLookup {
        if case .body(let data) = await fetch(LRCLIB.getURL(title: title, artist: artist, duration: duration)) {
            if let record = try? LRCLIB.decodeRecord(from: data) {
                return .match(record)
            }
            return .failed
        }
        guard case .body(let data) = await fetch(LRCLIB.searchURL(title: title, artist: artist)) else {
            return .failed
        }
        let results = (try? LRCLIB.decodeSearch(from: data)) ?? []
        let chosen = LRCLIB.choose(from: results, title: title, artist: artist, duration: duration)
        return chosen.map(LyricLookup.match) ?? .miss
    }

    private func fetch(_ url: URL?) async -> HTTPBody {
        guard let url else { return .failed }
        var request = URLRequest(url: url)
        request.setValue("Verseglass/1.1.0", forHTTPHeaderField: "User-Agent")
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

enum LyricLookup: Sendable {
    case match(LyricRecord)
    case miss
    case failed
}

private enum HTTPBody {
    case body(Data)
    case missing
    case failed
}
