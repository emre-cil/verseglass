import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = PlaybackEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApp.windows where window.identifier?.rawValue != "lyric-overlay" {
            window.orderOut(nil)
        }
        engine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }
}

@main
@MainActor
enum VerseglassMain {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
