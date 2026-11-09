import Foundation

public enum LyricSource: String, Equatable, Sendable {
    case spotify = "Spotify"
    case youtube = "YouTube"
    case appleMusic = "Apple Music"
}

public enum CardDepth: Int, Sendable {
    case current = 0
    case nearby = 1
    case context = 2

    public var before: Int { self == .current ? 0 : 1 }

    public var after: Int {
        switch self {
        case .current: 0
        case .nearby: 1
        case .context: 3
        }
    }
}

public enum SourceKind {
    /// Nil means "ignore this player".
    public static func source(bundleIdentifier: String?) -> LyricSource? {
        guard let bundleIdentifier else { return .youtube }
        switch bundleIdentifier {
        case "com.spotify.client":
            return .spotify
        case "com.apple.Music", "com.apple.iTunes":
            return .appleMusic
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

    /// 0...1 across the active line. The playhead moves with the lyric, then
    /// the next timestamp starts a new line. A long gap finishes the sweep
    /// early and holds the line, instead of crawling through an instrumental.
    public static func sungFraction(in lines: [LyricLine], at index: Int?, position: TimeInterval) -> Double {
        guard let index, lines.indices.contains(index) else { return 0 }
        let start = lines[index].time
        let untilNext = index + 1 < lines.count ? lines[index + 1].time - start : nil
        let span = sungSpan(characterCount: lines[index].text.count, untilNext: untilNext)
        guard span > 0 else { return 1 }
        return min(1, max(0, (position - start) / span))
    }

    public static func sungSpan(characterCount: Int, untilNext: TimeInterval?) -> TimeInterval {
        let estimated = min(8, max(0.9, Double(max(characterCount, 1)) * 0.085))
        guard let untilNext else { return estimated }
        return min(max(untilNext, 0.05), estimated)
    }

    /// Letters already sung. Word stamps advance word by word. A line with no
    /// word stamps keeps an even sweep until the next line.
    public static func sungPrefixLength(in line: LyricLine, position: TimeInterval, nextTime: TimeInterval?) -> Int {
        if line.words.isEmpty {
            let untilNext = nextTime.map { $0 - line.time }
            let span = sungSpan(characterCount: line.text.count, untilNext: untilNext)
            guard span > 0 else { return line.text.count }
            let fraction = min(1, max(0, (position - line.time) / span))
            return sungPrefixLength(line.text, fraction: fraction)
        }
        var count = 0
        for (index, word) in line.words.enumerated() {
            let start = word.time
            let end: TimeInterval
            if index + 1 < line.words.count {
                end = max(line.words[index + 1].time, start + 0.05)
            } else if let nextTime, nextTime > start {
                end = nextTime
            } else {
                end = start + max(0.35, Double(max(word.text.count, 1)) * 0.085)
            }
            let characters = word.text.count
            if position >= end - 0.000_1 {
                count += characters
                continue
            }
            if position <= start { break }
            let span = max(0.05, end - start)
            let fraction = min(1, (position - start) / span)
            count += min(characters, Int((Double(characters) * fraction).rounded(.down)))
            break
        }
        return min(line.text.count, count)
    }

    /// Extended grapheme clusters at the start of `text` that the playhead has passed.
    public static func sungPrefixLength(_ text: String, fraction: Double) -> Int {
        let count = text.count
        guard count > 0 else { return 0 }
        let clamped = min(1, max(0, fraction))
        return min(count, Int((Double(count) * clamped).rounded(.down)))
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
