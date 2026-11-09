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
    static var smallerText: String { String(localized: "Smaller text") }
    static var largerText: String { String(localized: "Larger text") }
    static var textFormat: String { String(localized: "Text: %d") }
    static var resetText: String { String(localized: "Reset text size") }
    static var thisLine: String { String(localized: "This line") }
    static var nearbyLines: String { String(localized: "Nearby lines") }
    static var widerContext: String { String(localized: "Wider context") }
    static var moreTransparent: String { String(localized: "More transparent") }
    static var moreOpaque: String { String(localized: "More opaque") }
    static var opacityFormat: String { String(localized: "Opacity: %d%%") }
    static var centerLines: String { String(localized: "Center lines") }
    static var copyLine: String { String(localized: "Copy line") }
    static var chooseLyrics: String { String(localized: "Choose lyrics") }
    static var noLyricChoices: String { String(localized: "No other matches") }
    static var useAutomatic: String { String(localized: "Use automatic match") }
    static var pasteLyrics: String { String(localized: "Paste lyrics…") }
    static var saveLyrics: String { String(localized: "Save") }
    static var cancel: String { String(localized: "Cancel") }
    static var pasteNeedsTime: String { String(localized: "Need at least one timestamp") }
    static var openAtLogin: String { String(localized: "Open at login") }
    static var loginFailed: String { String(localized: "Couldn't change login item") }
    static var pastedLyrics: String { String(localized: "Pasted lyrics") }
    static var quit: String { String(localized: "Quit") }
    static var downloadFormat: String { String(localized: "Download %@ translation") }
    static var secondsFormat: String { String(localized: "%@ s") }

    static func offset(_ value: Double) -> String {
        String(format: secondsFormat, OffsetStore.format(value))
    }
}
