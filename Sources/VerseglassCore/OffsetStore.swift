import Foundation

public final class OffsetStore: @unchecked Sendable {
    public static let step = 0.5
    private let defaults: UserDefaults
    private let storageKey: String

    public init(defaults: UserDefaults, storageKey: String = "trackOffsets") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public static func trackKey(artist: String, title: String) -> String {
        "\(TrackText.normalize(artist))|\(TrackText.normalize(title))"
    }

    public func offset(for trackKey: String) -> Double {
        storedMap()[trackKey] ?? 0
    }

    @discardableResult
    public func nudge(_ trackKey: String, steps: Int) -> Double {
        let current = Int((offset(for: trackKey) / Self.step).rounded())
        let value = Double(current + steps) * Self.step
        var stored = storedMap()
        stored[trackKey] = value
        defaults.set(stored, forKey: storageKey)
        return value
    }

    private func storedMap() -> [String: Double] {
        guard let raw = defaults.dictionary(forKey: storageKey) else { return [:] }
        var map: [String: Double] = [:]
        for (key, value) in raw {
            if let number = value as? NSNumber {
                map[key] = number.doubleValue
            }
        }
        return map
    }

    public static func format(_ value: Double) -> String {
        let tenths = (value * 10).rounded() / 10
        if tenths == 0 { return "0" }
        let sign = tenths > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", tenths))"
    }
}
