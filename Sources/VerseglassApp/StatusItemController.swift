import AppKit
import VerseglassCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    struct State {
        var statusText: String
        var trackLine: String
        var source: String
        var offsetText: String
        var lyricsMissing: Bool
        var overlayVisible: Bool
        var canNudge: Bool
        var offerTranslationInstall: Bool
        var translationLanguageName: String
        var cardWidth: Int
        var canNarrow: Bool
        var canWiden: Bool
    }

    var onNudge: ((Int) -> Void)?
    var onResetOffset: (() -> Void)?
    var onToggleOverlay: (() -> Void)?
    var onAdjustWidth: ((Int) -> Void)?
    var onInstallTranslation: (() -> Void)?

    private let item: NSStatusItem
    private let menu = NSMenu()
    private var state = State(
        statusText: "♪",
        trackLine: Copy.nothingPlaying,
        source: "—",
        offsetText: Copy.offset(0),
        lyricsMissing: false,
        overlayVisible: true,
        canNudge: false,
        offerTranslationInstall: false,
        translationLanguageName: "",
        cardWidth: 480,
        canNarrow: true,
        canWiden: true
    )

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.button?.font = .systemFont(ofSize: 13)
        if let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Verseglass") {
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageLeading
        }
        item.button?.title = "♪"
        menu.delegate = self
        item.menu = menu
    }

    func apply(_ state: State, marqueeStep: Int) {
        self.state = state
        item.button?.title = Marquee.window(state.statusText, step: marqueeStep)
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(disabled(state.trackLine.isEmpty ? Copy.nothingPlaying : state.trackLine))
        menu.addItem(disabled(String(format: Copy.sourceFormat, state.source)))
        if state.lyricsMissing {
            menu.addItem(disabled(Copy.noLyrics))
        }
        menu.addItem(.separator())
        let back = menu.addItem(withTitle: Copy.back, action: #selector(nudgeBack), keyEquivalent: "")
        back.target = self
        back.isEnabled = state.canNudge
        let forward = menu.addItem(withTitle: Copy.forward, action: #selector(nudgeForward), keyEquivalent: "")
        forward.target = self
        forward.isEnabled = state.canNudge
        menu.addItem(disabled(String(format: Copy.offsetFormat, state.offsetText)))
        let resetOffset = menu.addItem(withTitle: Copy.resetOffset, action: #selector(resetOffset), keyEquivalent: "")
        resetOffset.target = self
        resetOffset.isEnabled = state.canNudge
        if state.offerTranslationInstall {
            let install = menu.addItem(
                withTitle: String(format: Copy.downloadFormat, state.translationLanguageName),
                action: #selector(installTranslation),
                keyEquivalent: ""
            )
            install.target = self
        }
        menu.addItem(.separator())
        let narrower = menu.addItem(withTitle: Copy.narrower, action: #selector(narrower), keyEquivalent: "")
        narrower.target = self
        narrower.isEnabled = state.canNarrow
        let wider = menu.addItem(withTitle: Copy.wider, action: #selector(wider), keyEquivalent: "")
        wider.target = self
        wider.isEnabled = state.canWiden
        menu.addItem(disabled(String(format: Copy.widthFormat, state.cardWidth)))
        let resetWidth = menu.addItem(withTitle: Copy.resetWidth, action: #selector(resetWidth), keyEquivalent: "")
        resetWidth.target = self
        menu.addItem(.separator())
        let toggleTitle = state.overlayVisible ? Copy.hide : Copy.show
        let toggle = menu.addItem(withTitle: toggleTitle, action: #selector(toggleOverlay), keyEquivalent: "")
        toggle.target = self
        let quit = menu.addItem(withTitle: Copy.quit, action: #selector(quit), keyEquivalent: "q")
        quit.target = self
    }

    @objc private func nudgeBack() { onNudge?(-1) }
    @objc private func nudgeForward() { onNudge?(1) }
    @objc private func resetOffset() { onResetOffset?() }
    @objc private func narrower() { onAdjustWidth?(-1) }
    @objc private func wider() { onAdjustWidth?(1) }
    @objc private func resetWidth() { onAdjustWidth?(0) }
    @objc private func toggleOverlay() { onToggleOverlay?() }
    @objc private func installTranslation() { onInstallTranslation?() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

}
