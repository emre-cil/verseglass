import Foundation

public enum LyricSource: String, Equatable, Sendable {
    case spotify = "Spotify"
    case youtube = "YouTube"
}

public enum SourceKind {
    /// Apple Music is left to a later AppleScript path. Nil means "ignore".
    public static func source(bundleIdentifier: String?) -> LyricSource? {
        guard let bundleIdentifier else { return .youtube }
        switch bundleIdentifier {
        case "com.spotify.client":
            return .spotify
        case "com.apple.Music", "com.apple.iTunes":
            return nil
        default:
            return .youtube
        }
    }
}

public struct PlaybackSnapshot: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var duration: TimeInterval
    public var position: TimeInterval
    public var isPlaying: Bool
    public var source: LyricSource
    public var sampledAt: Date

    public init(
        title: String,
        artist: String,
        duration: TimeInterval,
        position: TimeInterval,
        isPlaying: Bool,
        source: LyricSource,
        sampledAt: Date
    ) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
        self.source = source
        self.sampledAt = sampledAt
    }

    public var trackKey: String {
        OffsetStore.trackKey(artist: artist, title: TrackText.queryTitle(title, artist: artist))
    }

    public var displayTitle: String {
        [artist, title].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
    }
}

public struct PlaybackSample: Equatable, Sendable {
    public var position: TimeInterval
    public var sampledAt: Date
    public var isPlaying: Bool
    public var duration: TimeInterval

    public init(position: TimeInterval, sampledAt: Date, isPlaying: Bool, duration: TimeInterval) {
        self.position = position
        self.sampledAt = sampledAt
        self.isPlaying = isPlaying
        self.duration = duration
    }

    public func position(at date: Date) -> TimeInterval {
        let raw = isPlaying ? position + date.timeIntervalSince(sampledAt) : position
        let clamped = max(0, raw)
        if duration > 0 {
            return min(clamped, duration)
        }
        return clamped
    }
}

public enum PlaybackSelector {
    /// Spotify wins only while it is actually playing. A paused Spotify app
    /// must not hide a browser that is playing.
    public static func choose(spotify: PlaybackSnapshot?, system: PlaybackSnapshot?) -> PlaybackSnapshot? {
        if let spotify, spotify.isPlaying {
            return spotify
        }
        if let system, system.isPlaying {
            return system
        }
        if let system, system.source != .spotify {
            return system
        }
        if let spotify {
            return spotify
        }
        return system
    }
}

public enum LyricClock {
    /// Last line whose timestamp is at or before `position`. Lines must be sorted.
    public static func activeIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
        var found: Int?
        for (index, line) in lines.enumerated() {
            if line.time <= position + 0.000_1 {
                found = index
            } else {
                break
            }
        }
        return found
    }

    public static func nextText(in lines: [LyricLine], after index: Int?) -> String {
        if let index {
            let next = index + 1
            guard next < lines.count else { return "" }
            return lines[next].text
        }
        return lines.first?.text ?? ""
    }

    /// One previous line, the line being sung, then the following ones.
    /// Blanks are skipped. Before the first stamp nothing is current; the
    /// upcoming lines fill the card.
    public static func cardLines(
        in lines: [LyricLine],
        at index: Int?,
        before: Int = 1,
        after: Int = 3
    ) -> [LyricCardLine] {
        guard !lines.isEmpty else { return [] }
        func text(at cursor: Int) -> String? {
            let value = lines[cursor].text.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        guard let index else {
            var upcoming: [LyricCardLine] = []
            var cursor = 0
            while cursor < lines.count, upcoming.count < max(0, after) {
                if let value = text(at: cursor) {
                    upcoming.append(LyricCardLine(text: value, isCurrent: false))
                }
                cursor += 1
            }
            return upcoming
        }
        guard index >= 0, index < lines.count else { return [] }

        var earlier: [LyricCardLine] = []
        var cursor = index - 1
        while cursor >= 0, earlier.count < max(0, before) {
            if let value = text(at: cursor) {
                earlier.append(LyricCardLine(text: value, isCurrent: false))
            }
            cursor -= 1
        }
        earlier.reverse()

        var rows = earlier
        if let value = text(at: index) {
            rows.append(LyricCardLine(text: value, isCurrent: true))
        }
        cursor = index + 1
        var following = 0
        while cursor < lines.count, following < max(0, after) {
            if let value = text(at: cursor) {
                rows.append(LyricCardLine(text: value, isCurrent: false))
                following += 1
            }
            cursor += 1
        }
        return rows
    }
}

public struct LyricCardLine: Equatable, Sendable {
    public var text: String
    public var isCurrent: Bool

    public init(text: String, isCurrent: Bool) {
        self.text = text
        self.isCurrent = isCurrent
    }
}
