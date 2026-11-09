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
        var fontSize: Int
        var canShrinkFont: Bool
        var canGrowFont: Bool
        var depth: Int
        var opacityPercent: Int
        var canFade: Bool
        var canSolid: Bool
        var centered: Bool
        var canCopy: Bool
        var lyricChoices: [String]
        var selectedLyric: Int?
        var usingManual: Bool
        var canPaste: Bool
        var opensAtLogin: Bool
    }

    var onNudge: ((Int) -> Void)?
    var onResetOffset: (() -> Void)?
    var onToggleOverlay: (() -> Void)?
    var onAdjustWidth: ((Int) -> Void)?
    var onAdjustFont: ((Int) -> Void)?
    var onSelectDepth: ((Int) -> Void)?
    var onAdjustOpacity: ((Int) -> Void)?
    var onToggleCentered: (() -> Void)?
    var onCopyLine: (() -> Void)?
    var onPickLyric: ((Int) -> Void)?
    var onUseAutomatic: (() -> Void)?
    var onPasteLyrics: (() -> Void)?
    var onToggleLogin: (() -> Void)?
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
        canWiden: true,
        fontSize: 22,
        canShrinkFont: true,
        canGrowFont: true,
        depth: 2,
        opacityPercent: 100,
        canFade: true,
        canSolid: false,
        centered: false,
        canCopy: false,
        lyricChoices: [],
        selectedLyric: nil,
        usingManual: false,
        canPaste: false,
        opensAtLogin: false
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
        let copy = menu.addItem(withTitle: Copy.copyLine, action: #selector(copyLine), keyEquivalent: "")
        copy.target = self
        copy.isEnabled = state.canCopy
        menu.addItem(.separator())
        let back = menu.addItem(withTitle: Copy.back, action: #selector(nudgeBack), keyEquivalent: "[")
        back.keyEquivalentModifierMask = [.command, .option]
        back.target = self
        back.isEnabled = state.canNudge
        let forward = menu.addItem(withTitle: Copy.forward, action: #selector(nudgeForward), keyEquivalent: "]")
        forward.keyEquivalentModifierMask = [.command, .option]
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
        let smaller = menu.addItem(withTitle: Copy.smallerText, action: #selector(smallerText), keyEquivalent: "")
        smaller.target = self
        smaller.isEnabled = state.canShrinkFont
        let larger = menu.addItem(withTitle: Copy.largerText, action: #selector(largerText), keyEquivalent: "")
        larger.target = self
        larger.isEnabled = state.canGrowFont
        menu.addItem(disabled(String(format: Copy.textFormat, state.fontSize)))
        let resetText = menu.addItem(withTitle: Copy.resetText, action: #selector(resetText), keyEquivalent: "")
        resetText.target = self
        checked(Copy.thisLine, on: state.depth == 0, action: #selector(showCurrentLine))
        checked(Copy.nearbyLines, on: state.depth == 1, action: #selector(showNearbyLines))
        checked(Copy.widerContext, on: state.depth == 2, action: #selector(showWiderContext))
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
        let fade = menu.addItem(withTitle: Copy.moreTransparent, action: #selector(fade), keyEquivalent: "")
        fade.target = self
        fade.isEnabled = state.canFade
        let solid = menu.addItem(withTitle: Copy.moreOpaque, action: #selector(solid), keyEquivalent: "")
        solid.target = self
        solid.isEnabled = state.canSolid
        menu.addItem(disabled(String(format: Copy.opacityFormat, state.opacityPercent)))
        checked(Copy.centerLines, on: state.centered, action: #selector(toggleCentered))
        menu.addItem(.separator())
        let choices = NSMenu()
        if state.lyricChoices.isEmpty {
            choices.addItem(disabled(Copy.noLyricChoices))
        } else {
            for (index, title) in state.lyricChoices.enumerated() {
                let item = choices.addItem(withTitle: title, action: #selector(pickLyric(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.state = state.selectedLyric == index ? .on : .off
            }
        }
        if state.usingManual {
            let automatic = choices.addItem(withTitle: Copy.useAutomatic, action: #selector(useAutomatic), keyEquivalent: "")
            automatic.target = self
        }
        let choose = menu.addItem(withTitle: Copy.chooseLyrics, action: nil, keyEquivalent: "")
        choose.submenu = choices
        let paste = menu.addItem(withTitle: Copy.pasteLyrics, action: #selector(pasteLyrics), keyEquivalent: "")
        paste.target = self
        paste.isEnabled = state.canPaste
        menu.addItem(.separator())
        checked(Copy.openAtLogin, on: state.opensAtLogin, action: #selector(toggleLogin))
        let toggleTitle = state.overlayVisible ? Copy.hide : Copy.show
        let toggle = menu.addItem(withTitle: toggleTitle, action: #selector(toggleOverlay), keyEquivalent: "h")
        toggle.keyEquivalentModifierMask = [.command, .option]
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
    @objc private func smallerText() { onAdjustFont?(-1) }
    @objc private func largerText() { onAdjustFont?(1) }
    @objc private func resetText() { onAdjustFont?(0) }
    @objc private func showCurrentLine() { onSelectDepth?(0) }
    @objc private func showNearbyLines() { onSelectDepth?(1) }
    @objc private func showWiderContext() { onSelectDepth?(2) }
    @objc private func fade() { onAdjustOpacity?(-1) }
    @objc private func solid() { onAdjustOpacity?(1) }
    @objc private func toggleCentered() { onToggleCentered?() }
    @objc private func copyLine() { onCopyLine?() }
    @objc private func pickLyric(_ sender: NSMenuItem) { onPickLyric?(sender.tag) }
    @objc private func useAutomatic() { onUseAutomatic?() }
    @objc private func pasteLyrics() { onPasteLyrics?() }
    @objc private func toggleLogin() { onToggleLogin?() }
    @objc private func toggleOverlay() { onToggleOverlay?() }
    @objc private func installTranslation() { onInstallTranslation?() }
    @objc private func quit() { NSApp.terminate(nil) }

    @discardableResult
    private func checked(_ title: String, on: Bool, action: Selector) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

}
