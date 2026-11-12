import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = PlaybackEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--open-at-login") {
            do {
                try LoginItem.setEnabled(true)
            } catch {
                let alert = NSAlert()
                alert.messageText = Copy.loginFailed
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
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
