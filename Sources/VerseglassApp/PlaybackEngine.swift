import AppKit
import Foundation
import VerseglassCore

@MainActor
final class PlaybackEngine {
    private let spotify = SpotifySource()
    private let nowPlaying = NowPlayingSource()
    private let lyrics: LyricsClient
    private let offsets: OffsetStore
    private let status = StatusItemController()
    private let translator = LyricTranslator()
    private let overlay: OverlayPanel
    private let defaults: UserDefaults

    private var sample: PlaybackSample?
    private var lines: [LyricLine] = []
    private var hasSynced = false
    private var fetchSettled = true
    private var fetchFailed = false
    private var nextFetchAt = Date.distantPast
    private var trackKey = ""
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
        overlay = OverlayPanel(defaults: defaults, translatorView: translator.view)
        if defaults.object(forKey: Self.overlayKey) == nil {
            overlayVisible = true
        } else {
            overlayVisible = defaults.bool(forKey: Self.overlayKey)
        }
        status.onNudge = { [weak self] steps in
            self?.nudge(steps)
        }
        status.onToggleOverlay = { [weak self] in
            self?.toggleOverlay()
        }
        status.onInstallTranslation = { [weak self] in
            self?.translator.requestInstall()
        }
    }

    func start() {
        closeStrayWindows()
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
            guard fetchFailed, Date() >= nextFetchAt else { return }
        } else {
            trackKey = chosen.trackKey
            lines = []
            hasSynced = false
            translator.update(lines: [])
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
            let lookup = await self.lyrics.load(title: title, artist: artist, duration: duration)
            guard !Task.isCancelled, key == self.trackKey else { return }
            switch lookup {
            case .match(let record):
                if record.instrumental {
                    self.lines = []
                    self.hasSynced = false
                } else if let synced = record.syncedLyrics {
                    self.lines = LRCParser.parse(synced)
                    self.hasSynced = !self.lines.isEmpty
                } else {
                    self.lines = []
                    self.hasSynced = false
                }
                self.translator.update(lines: self.lines.map(\.text))
                self.fetchFailed = false
            case .miss:
                self.lines = []
                self.hasSynced = false
                self.fetchFailed = false
            case .failed:
                self.fetchFailed = true
                self.nextFetchAt = Date().addingTimeInterval(5)
            }
            self.fetchSettled = true
        }
    }

    private func tick() {
        marqueeTick += 1
        let step = marqueeTick / 3
        guard let sample else {
            status.apply(idleState(), marqueeStep: step)
            overlay.update(
                rows: [CardRow(text: Copy.nothingPlaying, translation: nil, isCurrent: true)],
                visible: overlayVisible,
                playing: false
            )
            return
        }
        let position = sample.position(at: Date()) + offsets.offset(for: trackKey)
        let index = hasSynced ? LyricClock.activeIndex(in: lines, at: position) : nil
        let current = index.map { lines[$0].text } ?? ""
        let next = hasSynced ? LyricClock.nextText(in: lines, after: index) : ""
        let card = hasSynced ? LyricClock.cardLines(in: lines, at: index) : []
        let rows: [CardRow]
        if card.isEmpty {
            let title = displayTitle.isEmpty ? "…" : displayTitle
            let missing = fetchSettled && !hasSynced && !displayTitle.isEmpty
            rows = [CardRow(text: title, translation: missing ? Copy.noLyrics : nil, isCurrent: true)]
        } else {
            rows = card.map { line in
                CardRow(
                    text: line.text,
                    translation: translator.translation(for: line.text),
                    isCurrent: line.isCurrent
                )
            }
        }
        let visible = overlayVisible && !rows.isEmpty
        overlay.update(rows: rows, visible: visible, playing: sample.isPlaying)
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
            translationLanguageName: translator.targetLanguageName
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
            translationLanguageName: translator.targetLanguageName
        )
    }

    private func nudge(_ steps: Int) {
        guard !trackKey.isEmpty else { return }
        offsets.nudge(trackKey, steps: steps)
        tick()
    }

    private func toggleOverlay() {
        overlayVisible.toggle()
        defaults.set(overlayVisible, forKey: Self.overlayKey)
        tick()
    }

    private static let overlayKey = "overlayVisible"

    private func closeStrayWindows() {
        for window in NSApp.windows where window.identifier?.rawValue != "lyric-overlay" {
            window.orderOut(nil)
        }
    }
}
