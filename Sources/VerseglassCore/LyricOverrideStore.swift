import Foundation

public struct LyricOverride: Codable, Equatable, Sendable {
    public var title: String
    public var syncedLyrics: String

    public init(title: String, syncedLyrics: String) {
        self.title = title
        self.syncedLyrics = syncedLyrics
    }
}

public final class LyricOverrideStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let storageKey: String

    public init(defaults: UserDefaults, storageKey: String = "lyricOverrides") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func choice(for trackKey: String) -> LyricOverride? {
        guard let data = storedMap()[trackKey] else { return nil }
        return try? JSONDecoder().decode(LyricOverride.self, from: data)
    }

    public func save(_ choice: LyricOverride, for trackKey: String) {
        var stored = storedMap()
        stored[trackKey] = (try? JSONEncoder().encode(choice)) ?? Data()
        defaults.set(stored, forKey: storageKey)
    }

    public func clear(_ trackKey: String) {
        var stored = storedMap()
        stored.removeValue(forKey: trackKey)
        defaults.set(stored, forKey: storageKey)
    }

    private func storedMap() -> [String: Data] {
        guard let raw = defaults.dictionary(forKey: storageKey) else { return [:] }
        var map: [String: Data] = [:]
        for (key, value) in raw {
            if let data = value as? Data {
                map[key] = data
            }
        }
        return map
    }
}
