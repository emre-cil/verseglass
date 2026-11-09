import Foundation
import VerseglassCore
import Testing

@Test func parsesLRCTimestampsAndSkipsMetadata() {
    let raw = """
    [ti:Song]
    [ar:Artist]
    [00:12.40]first
    [00:18.02]second
    [01:01]third
    [00:05.50][00:40.00]chorus
    """
    let lines = LRCParser.parse(raw)
    #expect(lines.map(\.text) == ["chorus", "first", "second", "chorus", "third"])
    #expect(lines.map(\.time) == [5.5, 12.4, 18.02, 40, 61])
}

@Test func activeLineIsTheLastStampAtOrBeforeThePosition() {
    let lines = [
        LyricLine(time: 5, text: "a"),
        LyricLine(time: 12.4, text: "b"),
        LyricLine(time: 18, text: "c"),
    ]
    #expect(LyricClock.activeIndex(in: lines, at: 0) == nil)
    #expect(LyricClock.activeIndex(in: lines, at: 12.4) == 1)
    #expect(LyricClock.activeIndex(in: lines, at: 12.39) == 0)
    #expect(LyricClock.activeIndex(in: lines, at: 30) == 2)
    #expect(LyricClock.nextText(in: lines, after: nil) == "a")
    #expect(LyricClock.nextText(in: lines, after: 1) == "c")
    #expect(LyricClock.nextText(in: lines, after: 2) == "")
    #expect(LyricClock.cardLines(in: lines, at: nil).map(\.text) == ["a", "b", "c"])
    #expect(LyricClock.cardLines(in: lines, at: nil).allSatisfy { !$0.isCurrent })
    let around = LyricClock.cardLines(in: lines, at: 1)
    #expect(around.map(\.text) == ["a", "b", "c"])
    #expect(around.map(\.isCurrent) == [false, true, false])
}

@Test func clockInterpolatesWhilePlayingAndHoldsWhilePaused() {
    let start = Date(timeIntervalSince1970: 1_000)
    let playing = PlaybackSample(position: 10, sampledAt: start, isPlaying: true, duration: 20)
    #expect(playing.position(at: start.addingTimeInterval(1.5)) == 11.5)
    #expect(playing.position(at: start.addingTimeInterval(30)) == 20)
    let paused = PlaybackSample(position: 10, sampledAt: start, isPlaying: false, duration: 20)
    #expect(paused.position(at: start.addingTimeInterval(4)) == 10)
}

@Test func spotifyWinsOnlyWhileItIsPlaying() {
    let now = Date(timeIntervalSince1970: 50)
    let spotify = PlaybackSnapshot(
        title: "Song", artist: "A", duration: 180, position: 3,
        isPlaying: true, source: .spotify, sampledAt: now
    )
    let youtube = PlaybackSnapshot(
        title: "Other", artist: "B", duration: 200, position: 9,
        isPlaying: true, source: .youtube, sampledAt: now
    )
    #expect(PlaybackSelector.choose(spotify: spotify, system: youtube)?.source == .spotify)

    var pausedSpotify = spotify
    pausedSpotify.isPlaying = false
    #expect(PlaybackSelector.choose(spotify: pausedSpotify, system: youtube)?.title == "Other")
    #expect(PlaybackSelector.choose(spotify: pausedSpotify, system: nil)?.source == .spotify)
    #expect(PlaybackSelector.choose(spotify: nil, system: nil) == nil)
}

@Test func appleMusicIsIgnoredAndBrowsersCountAsYouTube() {
    #expect(SourceKind.source(bundleIdentifier: "com.spotify.client") == .spotify)
    #expect(SourceKind.source(bundleIdentifier: "com.apple.Music") == nil)
    #expect(SourceKind.source(bundleIdentifier: "com.google.Chrome") == .youtube)
    #expect(SourceKind.source(bundleIdentifier: nil) == .youtube)
}

@Test func queryTitleDropsUploadDecorationsAndAdsAreDetected() {
    #expect(TrackText.queryTitle("Song (Official Video)") == "Song")
    #expect(TrackText.queryTitle("Song - YouTube Music") == "Song")
    #expect(TrackText.queryTitle("Video Games") == "Video Games")
    #expect(
        TrackText.queryTitle(
            "Ravyn Lenae - Love Me Not (Official Music Video)",
            artist: "Ravyn Lenae"
        ) == "Love Me Not"
    )
    let channel = TrackText.lookupCandidates(
        title: "Bôa -  Duvet (Official Video)",
        artist: "Burak ŞOLT"
    )
    #expect(channel.count == 2)
    #expect(channel[1].artist == "Bôa")
    #expect(channel[1].title == "Duvet")
    #expect(TrackText.isAdvertisement(title: "Advertisement", artist: ""))
    #expect(!TrackText.isAdvertisement(title: "Advert", artist: "Band"))
}

@Test func searchRejectsADifferentArtist() {
    let records = [
        LyricRecord(trackName: "Song", artistName: "Someone Else", duration: 180, syncedLyrics: "[00:01.00]nope"),
        LyricRecord(trackName: "Song", artistName: "Right Artist", duration: 181, syncedLyrics: "[00:01.00]yes"),
    ]
    let chosen = LRCLIB.choose(from: records, title: "Song", artist: "Right Artist", duration: 180)
    #expect(chosen?.artistName == "Right Artist")
    let miss = LRCLIB.choose(from: [records[0]], title: "Song", artist: "Right Artist", duration: 180)
    #expect(miss == nil)
}

@Test func plainLyricsDoNotCountAsSynced() {
    let json = #"{"trackName":"Song","artistName":"A","duration":10,"plainLyrics":"hello","syncedLyrics":"  "}"#.data(using: .utf8)!
    let record = try! LRCLIB.decodeRecord(from: json)
    #expect(!record.hasSyncedLyrics)
}

@Test func offsetStepsStayOnAHalfSecondGrid() {
    let defaults = UserDefaults(suiteName: "verseglass.tests.offset")!
    defaults.removePersistentDomain(forName: "verseglass.tests.offset")
    let store = OffsetStore(defaults: defaults)
    let key = OffsetStore.trackKey(artist: "Renée", title: "Café")
    #expect(store.nudge(key, steps: 1) == 0.5)
    #expect(store.nudge(key, steps: 1) == 1)
    #expect(store.nudge(key, steps: -3) == -0.5)
    #expect(store.offset(for: key) == -0.5)
    #expect(OffsetStore.format(0) == "0")
    #expect(OffsetStore.format(0.5) == "+0.5")
    #expect(OffsetStore.format(-1) == "-1.0")
}

@Test func cacheKeepsHitsAndExpiresMisses() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let cache = LyricCache(directory: directory, missTTL: 10)
    let key = LyricCache.cacheKey(artist: "A", title: "Song (Official Video)", duration: 180.4)
    let record = LyricRecord(trackName: "Song", artistName: "A", duration: 180, syncedLyrics: "[00:01.00]line")
    let then = Date(timeIntervalSince1970: 10_000)
    cache.save(key: key, record: record, now: then)
    #expect(cache.load(key: key, now: then.addingTimeInterval(10_000))?.record == record)
    cache.save(key: key, record: nil, now: then)
    #expect(cache.load(key: key, now: then.addingTimeInterval(5))?.record == nil)
    #expect(cache.load(key: key, now: then.addingTimeInterval(11)) == nil)
}

@Test func marqueeWindowWalksALongLine() {
    let text = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMN"
    let shown = Marquee.window(text, step: 0)
    #expect(shown.count == 42)
    #expect(shown.hasPrefix("abc"))
    #expect(Marquee.window(text, step: 1) != shown)
    #expect(Marquee.window("kısa", step: 4) == "kısa")
}
