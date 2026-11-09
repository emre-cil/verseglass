import Foundation
import VerseglassCore
import os

@MainActor
final class NowPlayingSource {
    private let log = Logger(subsystem: "app.verseglass", category: "nowplaying")
    private let lock = NSLock()
    private var latest: [String: Any] = [:]
    private var latestUpdatedAt: Date = .distantPast
    private var helper: Process?
    private var restarting = false

    func start() {
        spawn()
    }

    func stop() {
        helper?.terminate()
        helper = nil
    }

    func snapshot() -> PlaybackSnapshot? {
        lock.lock()
        let dict = latest
        let updatedAt = latestUpdatedAt
        lock.unlock()
        guard Date().timeIntervalSince(updatedAt) < 15 else { return nil }
        guard let title = (dict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty
        else { return nil }
        let artist = (dict["artist"] as? String) ?? ""
        if TrackText.isAdvertisement(title: title, artist: artist) { return nil }
        let bundleID = dict["bundleId"] as? String
        guard let source = SourceKind.source(bundleIdentifier: bundleID) else { return nil }
        let duration = Self.number(dict["duration"]) ?? 0
        let rawElapsed = Self.number(dict["elapsed"]) ?? 0
        let isPlaying = (dict["isPlaying"] as? Bool) ?? ((dict["isPlaying"] as? NSNumber)?.boolValue ?? false)
        let timestamp = Self.number(dict["timestamp"]).map { Date(timeIntervalSince1970: $0) }
        var elapsed = rawElapsed
        let now = Date()
        if isPlaying, let timestamp {
            elapsed = max(0, rawElapsed + now.timeIntervalSince(timestamp))
        }
        if duration > 0 {
            elapsed = min(duration, elapsed)
        }
        return PlaybackSnapshot(
            title: title,
            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: duration,
            position: elapsed,
            isPlaying: isPlaying,
            source: source,
            sampledAt: now
        )
    }

    private func spawn() {
        guard helper == nil || helper?.isRunning == false else { return }
        guard let scriptURL = HelperLocator.url() else {
            log.error("now_playing_helper.swift is missing")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [scriptURL.path]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.helper = nil
                self?.scheduleRestart()
            }
        }
        do {
            try process.run()
        } catch {
            log.error("helper failed to start: \(error.localizedDescription, privacy: .public)")
            return
        }
        helper = process
        log.info("helper pid \(process.processIdentifier, privacy: .public)")
        readLines(from: stdout.fileHandleForReading) { [weak self] line in
            self?.handle(line)
        }
        readLines(from: stderr.fileHandleForReading) { [weak self] line in
            guard !line.isEmpty else { return }
            self?.log.error("helper: \(line, privacy: .public)")
        }
    }

    private func scheduleRestart() {
        guard !restarting else { return }
        restarting = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.restarting = false
            self.spawn()
        }
    }

    private func handle(_ line: String) {
        guard let data = line.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        lock.lock()
        latest = dict
        latestUpdatedAt = Date()
        lock.unlock()
    }

    private func readLines(from handle: FileHandle, onLine: @escaping @MainActor (String) -> Void) {
        let buffer = LineBuffer()
        handle.readabilityHandler = { current in
            let data = current.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = buffer.append(text)
            guard !lines.isEmpty else { return }
            Task { @MainActor in
                for line in lines {
                    onLine(line)
                }
            }
        }
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}

private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = ""

    func append(_ chunk: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(chunk)
        var lines: [String] = []
        while let range = pending.range(of: "\n") {
            let line = String(pending[..<range.lowerBound])
            pending.removeSubrange(pending.startIndex..<range.upperBound)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}

enum HelperLocator {
    static func url() -> URL? {
        if let url = Bundle.main.url(forResource: "now_playing_helper", withExtension: "swift") {
            return url
        }
        return Bundle.module.url(forResource: "now_playing_helper", withExtension: "swift")
    }
}
