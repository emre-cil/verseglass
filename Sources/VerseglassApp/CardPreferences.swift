import Foundation
import VerseglassCore

@MainActor
final class CardPreferences {
    static let minFont = 16.0
    static let maxFont = 36.0
    static let defaultFont = 22.0
    static let fontStep = 2.0
    static let minOpacity = 0.4
    static let maxOpacity = 1.0

    private let defaults: UserDefaults
    private(set) var fontSize: Double
    private(set) var depth: CardDepth
    private(set) var opacity: Double
    private(set) var centered: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.fontKey) != nil {
            fontSize = min(Self.maxFont, max(Self.minFont, defaults.double(forKey: Self.fontKey)))
        } else {
            fontSize = Self.defaultFont
        }
        if defaults.object(forKey: Self.depthKey) != nil {
            depth = CardDepth(rawValue: defaults.integer(forKey: Self.depthKey)) ?? .context
        } else {
            depth = .context
        }
        if defaults.object(forKey: Self.opacityKey) != nil {
            opacity = min(Self.maxOpacity, max(Self.minOpacity, defaults.double(forKey: Self.opacityKey)))
        } else {
            opacity = 1
        }
        centered = defaults.bool(forKey: Self.centeredKey)
    }

    func adjustFont(steps: Int) {
        fontSize = min(Self.maxFont, max(Self.minFont, fontSize + Double(steps) * Self.fontStep))
        defaults.set(fontSize, forKey: Self.fontKey)
    }

    func resetFont() {
        fontSize = Self.defaultFont
        defaults.set(fontSize, forKey: Self.fontKey)
    }

    func setDepth(_ depth: CardDepth) {
        self.depth = depth
        defaults.set(depth.rawValue, forKey: Self.depthKey)
    }

    func adjustOpacity(steps: Int) {
        let percent = (opacity * 100).rounded() + Double(steps) * 15
        opacity = min(Self.maxOpacity, max(Self.minOpacity, percent / 100))
        defaults.set(opacity, forKey: Self.opacityKey)
    }

    func setCentered(_ centered: Bool) {
        self.centered = centered
        defaults.set(centered, forKey: Self.centeredKey)
    }

    var canShrinkFont: Bool { fontSize > Self.minFont + 0.1 }
    var canGrowFont: Bool { fontSize < Self.maxFont - 0.1 }
    var canFade: Bool { opacity > Self.minOpacity + 0.01 }
    var canSolid: Bool { opacity < Self.maxOpacity - 0.01 }

    private static let fontKey = "cardFontSize"
    private static let depthKey = "cardDepth"
    private static let opacityKey = "cardOpacity"
    private static let centeredKey = "cardCentered"
}
