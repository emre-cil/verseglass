import AppKit
import Foundation
import VerseglassCore

@MainActor
final class PlaybackEngine {
    private let spotify = SpotifySource()
    private let nowPlaying = NowPlayingSource()
    private let lyrics: LyricsClient
    private let offsets: OffsetStore
    private let overrides: LyricOverrideStore
    private let preferences: CardPreferences
    private let hotkeys = HotKeyController()
    private let pastePanel = PasteLyricsPanel()
    private let status = StatusItemController()
    private let translator = LyricTranslator()
    private let overlay: OverlayPanel
    private let defaults: UserDefaults

    private var sample: PlaybackSample?
    private var lines: [LyricLine] = []
    private var alternatives: [LyricRecord] = []
    private var hasSynced = false
    private var fetchSettled = true
    private var fetchFailed = false
    private var forceFetch = false
    private var nextFetchAt = Date.distantPast
    private var trackKey = ""
    private var manualTitle: String?
    private var copyText: String?
    private var copyTranslation: String?
    private var displayTitle = ""
    private var sourceLabel = "—"
    private var fetchTask: Task<Void, Never>?
    private var marqueeTick = 0
    private var overlayVisible: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Verseglass/lyrics", isDirectory: true)
        lyrics = LyricsClient(cache: LyricCache(directory: support))
        offsets = OffsetStore(defaults: defaults)
        overrides = LyricOverrideStore(defaults: defaults)
        preferences = CardPreferences(defaults: defaults)
        overlay = OverlayPanel(defaults: defaults, translatorView: translator.view)
        if defaults.object(forKey: Self.overlayKey) == nil {
            overlayVisible = true
        } else {
            overlayVisible = defaults.bool(forKey: Self.overlayKey)
        }
        status.onNudge = { [weak self] steps in
            self?.nudge(steps)
        }
        status.onResetOffset = { [weak self] in
            self?.resetOffset()
        }
        status.onToggleOverlay = { [weak self] in
            self?.toggleOverlay()
        }
        status.onAdjustWidth = { [weak self] steps in
            self?.adjustWidth(steps)
        }
        status.onAdjustFont = { [weak self] steps in
            self?.adjustFont(steps)
        }
        status.onSelectDepth = { [weak self] raw in
            guard let depth = CardDepth(rawValue: raw) else { return }
            self?.preferences.setDepth(depth)
            self?.tick()
        }
        status.onAdjustOpacity = { [weak self] steps in
            self?.preferences.adjustOpacity(steps: steps)
            self?.tick()
        }
        status.onToggleCentered = { [weak self] in
            guard let self else { return }
            self.preferences.setCentered(!self.preferences.centered)
            self.tick()
        }
        status.onCopyLine = { [weak self] in
            self?.copyLine()
        }
        status.onPickLyric = { [weak self] index in
            self?.pickLyric(index)
        }
        status.onUseAutomatic = { [weak self] in
            self?.useAutomatic()
        }
        status.onPasteLyrics = { [weak self] in
            self?.beginPaste()
        }
        status.onToggleLogin = { [weak self] in
            self?.toggleLogin()
        }
        pastePanel.onSave = { [weak self] raw in
            self?.savePasted(raw)
        }
        hotkeys.onToggle = { [weak self] in
            self?.toggleOverlay()
        }
        hotkeys.onNudge = { [weak self] steps in
            self?.nudge(steps)
        }
        overlay.onNudge = { [weak self] steps in
            self?.nudge(steps)
        }
        overlay.onResetOffset = { [weak self] in
            self?.resetOffset()
        }
        overlay.onHide = { [weak self] in
            self?.setOverlayVisible(false)
        }
        status.onInstallTranslation = { [weak self] in
            self?.translator.requestInstall()
        }
    }

    func start() {
        closeStrayWindows()
        hotkeys.start()
        nowPlaying.start()
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.poll()
            }
        }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        Task { await poll() }
    }

    func stop() {
        fetchTask?.cancel()
        nowPlaying.stop()
    }

    private func poll() async {
        async let spotifySnapshot = spotify.snapshot()
        let systemSnapshot = nowPlaying.snapshot()
        let chosen = PlaybackSelector.choose(spotify: await spotifySnapshot, system: systemSnapshot)
        guard let chosen else {
            sample = nil
            trackKey = ""
            lines = []
            hasSynced = false
            fetchSettled = true
            fetchFailed = false
            translator.update(lines: [])
            alternatives = []
            manualTitle = nil
            copyText = nil
            copyTranslation = nil
            displayTitle = ""
            sourceLabel = "—"
            return
        }
        sample = PlaybackSample(
            position: chosen.position,
            sampledAt: chosen.sampledAt,
            isPlaying: chosen.isPlaying,
            duration: chosen.duration
        )
        displayTitle = chosen.displayTitle
        sourceLabel = chosen.source.rawValue
        let sameTrack = chosen.trackKey == trackKey
        if sameTrack {
            let retry = forceFetch || (fetchFailed && Date() >= nextFetchAt)
            guard retry else { return }
            forceFetch = false
        } else {
            trackKey = chosen.trackKey
            alternatives = []
            if let choice = overrides.choice(for: chosen.trackKey) {
                manualTitle = choice.title
                apply(choice.syncedLyrics)
            } else {
                manualTitle = nil
                lines = []
                hasSynced = false
                translator.update(lines: [])
            }
        }
        fetchSettled = false
        fetchFailed = false
        let key = chosen.trackKey
        let title = chosen.title
        let artist = chosen.artist
        let duration = chosen.duration > 0 ? chosen.duration : nil
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            let found = await self.lyrics.discover(title: title, artist: artist, duration: duration)
            guard !Task.isCancelled, key == self.trackKey else { return }
            self.alternatives = found.alternatives
            self.fetchFailed = found.failed
            if found.failed {
                self.nextFetchAt = Date().addingTimeInterval(5)
            }
            if self.overrides.choice(for: key) == nil {
                if found.match?.instrumental == true {
                    self.apply(nil)
                } else {
                    self.apply(found.match?.syncedLyrics)
                }
            }
            self.fetchSettled = true
        }
    }

    private func apply(_ synced: String?) {
        if let synced, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines = LRCParser.parse(synced)
            hasSynced = !lines.isEmpty
        } else {
            lines = []
            hasSynced = false
        }
        translator.update(lines: lines.map(\.text))
    }

    private func tick() {
        marqueeTick += 1
        let step = marqueeTick / 3
        guard let sample else {
            status.apply(idleState(), marqueeStep: step)
            copyText = nil
            copyTranslation = nil
            overlay.update(
                rows: [CardRow(text: Copy.nothingPlaying, translation: nil, isCurrent: true, sungCount: nil)],
                visible: overlayVisible,
                playing: false,
                offsetLabel: "0",
                canNudge: false,
                fontSize: preferences.fontSize,
                centered: preferences.centered,
                opacity: preferences.opacity
            )
            return
        }
        let position = sample.position(at: Date()) + offsets.offset(for: trackKey)
        let index = hasSynced ? LyricClock.activeIndex(in: lines, at: position) : nil
        let current = index.map { lines[$0].text } ?? ""
        let next = hasSynced ? LyricClock.nextText(in: lines, after: index) : ""
        let card = hasSynced
            ? LyricClock.cardLines(in: lines, at: index, before: preferences.depth.before, after: preferences.depth.after)
            : []
        let nextTime: TimeInterval? = index.flatMap { cursor in
            cursor + 1 < lines.count ? lines[cursor + 1].time : nil
        }
        let sung = index.map { LyricClock.sungPrefixLength(in: lines[$0], position: position, nextTime: nextTime) }
        if let index, hasSynced, !lines[index].text.isEmpty {
            copyText = lines[index].text
            copyTranslation = translator.translation(for: lines[index].text)
        } else {
            copyText = nil
            copyTranslation = nil
        }
        let rows: [CardRow]
        if card.isEmpty {
            let title = displayTitle.isEmpty ? "…" : displayTitle
            let missing = fetchSettled && !hasSynced && !displayTitle.isEmpty
            rows = [CardRow(text: title, translation: missing ? Copy.noLyrics : nil, isCurrent: true, sungCount: nil)]
        } else {
            rows = card.map { line in
                CardRow(
                    text: line.text,
                    translation: translator.translation(for: line.text),
                    isCurrent: line.isCurrent,
                    sungCount: line.isCurrent ? sung : nil
                )
            }
        }
        let visible = overlayVisible && !rows.isEmpty
        overlay.update(
            rows: rows,
            visible: visible,
            playing: sample.isPlaying,
            offsetLabel: OffsetStore.format(offsets.offset(for: trackKey)),
            canNudge: !trackKey.isEmpty,
            fontSize: preferences.fontSize,
            centered: preferences.centered,
            opacity: preferences.opacity
        )
        status.apply(menuState(current: current, next: next), marqueeStep: step)
    }

    private func menuState(current: String, next: String) -> StatusItemController.State {
        let line: String
        if hasSynced {
            line = current.isEmpty ? (next.isEmpty ? displayTitle : next) : current
        } else {
            line = displayTitle.isEmpty ? "…" : displayTitle
        }
        return StatusItemController.State(
            statusText: line,
            trackLine: displayTitle,
            source: sourceLabel,
            offsetText: Copy.offset(offsets.offset(for: trackKey)),
            lyricsMissing: fetchSettled && !hasSynced,
            overlayVisible: overlayVisible,
            canNudge: !trackKey.isEmpty,
            offerTranslationInstall: translator.needsInstall,
            translationLanguageName: translator.targetLanguageName,
            cardWidth: overlay.widthPoints,
            canNarrow: overlay.canNarrow,
            canWiden: overlay.canWiden,
            fontSize: Int(preferences.fontSize.rounded()),
            canShrinkFont: preferences.canShrinkFont,
            canGrowFont: preferences.canGrowFont,
            depth: preferences.depth.rawValue,
            opacityPercent: Int((preferences.opacity * 100).rounded()),
            canFade: preferences.canFade,
            canSolid: preferences.canSolid,
            centered: preferences.centered,
            canCopy: copyText != nil,
            lyricChoices: choiceTitles(),
            selectedLyric: selectedLyricIndex(),
            usingManual: manualTitle != nil,
            canPaste: !trackKey.isEmpty,
            opensAtLogin: LoginItem.isEnabled
        )
    }

    private func idleState() -> StatusItemController.State {
        StatusItemController.State(
            statusText: "♪",
            trackLine: Copy.nothingPlaying,
            source: "—",
            offsetText: Copy.offset(0),
            lyricsMissing: false,
            overlayVisible: overlayVisible,
            canNudge: false,
            offerTranslationInstall: translator.needsInstall,
            translationLanguageName: translator.targetLanguageName,
            cardWidth: overlay.widthPoints,
            canNarrow: overlay.canNarrow,
            canWiden: overlay.canWiden,
            fontSize: Int(preferences.fontSize.rounded()),
            canShrinkFont: preferences.canShrinkFont,
            canGrowFont: preferences.canGrowFont,
            depth: preferences.depth.rawValue,
            opacityPercent: Int((preferences.opacity * 100).rounded()),
            canFade: preferences.canFade,
            canSolid: preferences.canSolid,
            centered: preferences.centered,
            canCopy: false,
            lyricChoices: [],
            selectedLyric: nil,
            usingManual: false,
            canPaste: false,
            opensAtLogin: LoginItem.isEnabled
        )
    }

    private func nudge(_ steps: Int) {
        guard !trackKey.isEmpty else { return }
        offsets.nudge(trackKey, steps: steps)
        tick()
    }

    private func resetOffset() {
        guard !trackKey.isEmpty else { return }
        offsets.reset(trackKey)
        tick()
    }

    private func adjustFont(_ steps: Int) {
        if steps == 0 {
            preferences.resetFont()
        } else {
            preferences.adjustFont(steps: steps)
        }
        tick()
    }

    private func copyLine() {
        guard let copyText else { return }
        var text = copyText
        if let copyTranslation, !copyTranslation.isEmpty {
            text += "\n" + copyTranslation
        }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }

    private func pickLyric(_ index: Int) {
        guard !trackKey.isEmpty, alternatives.indices.contains(index) else { return }
        let record = alternatives[index]
        guard let synced = record.syncedLyrics, !synced.isEmpty else { return }
        let title = choiceTitles()[index]
        overrides.save(LyricOverride(title: title, syncedLyrics: synced), for: trackKey)
        manualTitle = title
        apply(synced)
        fetchSettled = true
        tick()
    }

    private func useAutomatic() {
        guard !trackKey.isEmpty else { return }
        overrides.clear(trackKey)
        manualTitle = nil
        apply(nil)
        fetchSettled = false
        forceFetch = true
        Task { await poll() }
    }

    private func beginPaste() {
        guard !trackKey.isEmpty else { return }
        pastePanel.show(existing: overrides.choice(for: trackKey)?.syncedLyrics ?? "")
    }

    private func savePasted(_ raw: String) {
        guard !trackKey.isEmpty else { return }
        overrides.save(LyricOverride(title: Copy.pastedLyrics, syncedLyrics: raw), for: trackKey)
        manualTitle = Copy.pastedLyrics
        apply(raw)
        fetchSettled = true
        tick()
    }

    private func toggleLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            let alert = NSAlert()
            alert.messageText = Copy.loginFailed
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        tick()
    }

    private func choiceTitles() -> [String] {
        alternatives.map { record in
            let name = [record.artistName, record.trackName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " — ")
            if name.count > 80 {
                return String(name.prefix(79)) + "…"
            }
            return name.isEmpty ? Copy.pastedLyrics : name
        }
    }

    private func selectedLyricIndex() -> Int? {
        guard let synced = overrides.choice(for: trackKey)?.syncedLyrics else { return nil }
        return alternatives.firstIndex { $0.syncedLyrics == synced }
    }

    private func adjustWidth(_ steps: Int) {
        if steps == 0 {
            overlay.resetWidth()
        } else {
            overlay.adjustWidth(steps: steps)
        }
        tick()
    }

    private func toggleOverlay() {
        setOverlayVisible(!overlayVisible)
    }

    private func setOverlayVisible(_ visible: Bool) {
        overlayVisible = visible
        defaults.set(overlayVisible, forKey: Self.overlayKey)
        tick()
    }

    private static let overlayKey = "overlayVisible"

    private func closeStrayWindows() {
        for window in NSApp.windows where window.identifier?.rawValue != "lyric-overlay" && window.identifier?.rawValue != "paste-lyrics" {
            window.orderOut(nil)
        }
    }
}
