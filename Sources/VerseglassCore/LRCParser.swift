import Foundation

public struct LyricLine: Equatable, Sendable {
    public var time: TimeInterval
    public var text: String

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}

public enum LRCParser {
    public static func parse(_ raw: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for rawLine in raw.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let stamps = timestamps(in: line)
            guard !stamps.isEmpty else { continue }
            let text = lyricText(from: line).trimmingCharacters(in: .whitespaces)
            for time in stamps {
                lines.append(LyricLine(time: time, text: text))
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

    private static func lyricText(from line: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return line }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
    }
}
