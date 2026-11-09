import Foundation

public enum TrackText {
    public static func normalize(_ value: String) -> String {
        let folded = value.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        var pieces: [String] = []
        var current = ""
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                pieces.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            pieces.append(current)
        }
        return pieces.joined(separator: " ")
    }

    /// Strips upload decorations and a leading "Artist - " so a YouTube title
    /// can be looked up as a song.
    public static func queryTitle(_ raw: String, artist: String = "") -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"\s*[\[(][^)\]]*(official|lyrics?|audio|visualizer|mv|hd|4k|music video|video)[^)\]]*[)\]]"#,
            #"\s*-\s*youtube music\s*$"#,
            #"\s*-\s*youtube\s*$"#,
        ]
        for pattern in patterns {
            title = title.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artistTrim = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !artistTrim.isEmpty {
            for separator in [" - ", " – ", " — "] {
                let prefix = artistTrim + separator
                if title.lowercased().hasPrefix(prefix.lowercased()) {
                    title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }
        return title
    }

    /// YouTube often puts "Sanatçı - Şarkı" in the title and the channel name in the artist field.
    public static func splitPerformer(in title: String) -> (artist: String, title: String)? {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for separator in [" - ", " – ", " — "] {
            guard let range = cleaned.range(of: separator) else { continue }
            let left = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !left.isEmpty, !right.isEmpty else { continue }
            return (left, right)
        }
        return nil
    }

    /// First pair is the reported artist. A second pair is added when the title
    /// itself names a different performer, so a channel credit can miss.
    public static func lookupCandidates(title: String, artist: String) -> [(artist: String, title: String)] {
        let cleaned = queryTitle(title, artist: artist)
        var pairs = [(artist.trimmingCharacters(in: .whitespacesAndNewlines), cleaned)]
        if let split = splitPerformer(in: cleaned), normalize(split.artist) != normalize(artist) {
            pairs.append((split.artist, split.title))
        }
        return pairs
    }

    public static func isAdvertisement(title: String, artist: String) -> Bool {
        let titleKey = normalize(title)
        let artistKey = normalize(artist)
        let ads = ["advertisement", "reklam", "sponsored", "sponsorlu"]
        if ads.contains(titleKey) || ads.contains(artistKey) {
            return true
        }
        if titleKey.contains("advertisement") || artistKey.contains("advertisement") {
            return true
        }
        return false
    }
}
