import CryptoKit
import Foundation

public struct LyricCache: Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var savedAt: Date
        public var record: LyricRecord?
    }

    public let directory: URL
    public var missTTL: TimeInterval

    public init(directory: URL, missTTL: TimeInterval = 6 * 60 * 60) {
        self.directory = directory
        self.missTTL = missTTL
    }

    public static func cacheKey(artist: String, title: String, duration: TimeInterval?) -> String {
        let seconds = duration.map { String(Int($0.rounded())) } ?? ""
        let raw = "\(TrackText.normalize(artist))|\(TrackText.normalize(TrackText.queryTitle(title, artist: artist)))|\(seconds)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func load(key: String, now: Date = Date()) -> Entry? {
        let url = fileURL(key)
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(Entry.self, from: data)
        else { return nil }
        if entry.record == nil, now.timeIntervalSince(entry.savedAt) > missTTL {
            return nil
        }
        return entry
    }

    public func save(key: String, record: LyricRecord?, now: Date = Date()) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entry = Entry(savedAt: now, record: record)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: fileURL(key), options: .atomic)
    }

    private func fileURL(_ key: String) -> URL {
        directory.appendingPathComponent(key).appendingPathExtension("json")
    }
}
