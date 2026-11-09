import Foundation

public struct LyricWord: Equatable, Sendable {
    public var time: TimeInterval
    public var text: String

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}

public struct LyricLine: Equatable, Sendable {
    public var time: TimeInterval
    public var text: String
    public var words: [LyricWord]

    public init(time: TimeInterval, text: String, words: [LyricWord] = []) {
        self.time = time
        self.text = text
        self.words = words
    }
}

public enum LRCParser {
    public static func parse(_ raw: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for rawLine in raw.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let stamps = timestamps(in: line)
            guard !stamps.isEmpty else { continue }
            let body = lyricText(from: line).trimmingCharacters(in: .whitespaces)
            for time in stamps {
                let parsed = Self.words(in: body, lineTime: time)
                lines.append(LyricLine(time: time, text: parsed.text, words: parsed.words))
            }
        }
        lines.sort { lhs, rhs in
            if lhs.time == rhs.time { return lhs.text < rhs.text }
            return lhs.time < rhs.time
        }
        return lines
    }

    private static let pattern = #"\[(\d{1,3}):(\d{2}(?:\.\d{1,3})?)\]"#

    private static func timestamps(in line: String) -> [TimeInterval] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let minuteRange = Range(match.range(at: 1), in: line),
                  let secondRange = Range(match.range(at: 2), in: line),
                  let minutes = Double(line[minuteRange]),
                  let seconds = Double(line[secondRange])
            else { return nil }
            return minutes * 60 + seconds
        }
    }

    /// `<mm:ss.xx>` tags mark words. The plain line is the tags removed, with
    /// the spaces the file already had. No tags means a normal line.
    static func words(in text: String, lineTime: TimeInterval) -> (text: String, words: [LyricWord]) {
        guard let regex = try? NSRegularExpression(pattern: wordPattern) else { return (text, []) }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return (text, []) }
        var words: [LyricWord] = []
        var cursor = text.startIndex
        var pending = lineTime
        for match in matches {
            guard let tag = Range(match.range, in: text),
                  let minuteRange = Range(match.range(at: 1), in: text),
                  let secondRange = Range(match.range(at: 2), in: text),
                  let minutes = Double(text[minuteRange]),
                  let seconds = Double(text[secondRange])
            else { continue }
            let chunk = String(text[cursor..<tag.lowerBound])
            if !chunk.isEmpty {
                words.append(LyricWord(time: pending, text: chunk))
            }
            pending = minutes * 60 + seconds
            cursor = tag.upperBound
        }
        let tail = String(text[cursor...])
        if !tail.isEmpty {
            words.append(LyricWord(time: pending, text: tail))
        }
        guard !words.isEmpty else { return (text, []) }
        return (words.map(\.text).joined(), words)
    }

    private static let wordPattern = #"<(\d{1,3}):(\d{2}(?:\.\d{1,3})?)>"#

    private static func lyricText(from line: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return line }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
    }
}
