import Foundation
import VerseglassCore

enum Copy {
    static var nothingPlaying: String { String(localized: "Nothing playing") }
    static var noLyrics: String { String(localized: "No lyrics") }
    static var sourceFormat: String { String(localized: "Source: %@") }
    static var back: String { String(localized: "Back 0.5 s") }
    static var forward: String { String(localized: "Forward 0.5 s") }
    static var offsetFormat: String { String(localized: "Offset: %@") }
    static var hide: String { String(localized: "Hide card") }
    static var show: String { String(localized: "Show card") }
    static var narrower: String { String(localized: "Narrower") }
    static var wider: String { String(localized: "Wider") }
    static var widthFormat: String { String(localized: "Width: %d") }
    static var resetWidth: String { String(localized: "Reset width") }
    static var resetOffset: String { String(localized: "Reset offset") }
    static var quit: String { String(localized: "Quit") }
    static var downloadFormat: String { String(localized: "Download %@ translation") }
    static var secondsFormat: String { String(localized: "%@ s") }

    static func offset(_ value: Double) -> String {
        String(format: secondsFormat, OffsetStore.format(value))
    }
}
