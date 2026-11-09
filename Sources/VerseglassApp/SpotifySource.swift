import Foundation
import VerseglassCore

@MainActor
final class SpotifySource {
    private var inFlight = false
    private var last: PlaybackSnapshot?

    func snapshot() async -> PlaybackSnapshot? {
        if inFlight { return last }
        inFlight = true
        defer { inFlight = false }
        let receivedAt = Date()
        guard let output = await Self.run(),
              let data = output.data(using: .utf8),
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            last = nil
            return nil
        }
        if payload.state == "stopped" {
            last = nil
            return nil
        }
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            last = nil
            return nil
        }
        if TrackText.isAdvertisement(title: title, artist: payload.artist) {
            last = nil
            return nil
        }
        let snapshot = PlaybackSnapshot(
            title: title,
            artist: payload.artist.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: max(0, payload.duration),
            position: max(0, payload.position),
            isPlaying: payload.state == "playing",
            source: .spotify,
            sampledAt: receivedAt
        )
        last = snapshot
        return snapshot
    }

    private struct Payload: Decodable {
        var state: String
        var title: String
        var artist: String
        var duration: Double
        var position: Double
    }

    private static func run() async -> String? {
        let script = """
        function run() {
          const events = Application('System Events');
          if (events.processes.whose({ name: 'Spotify' }).length === 0) return '';
          const spotify = Application('Spotify');
          const state = String(spotify.playerState());
          if (state === 'stopped') return '';
          const track = spotify.currentTrack;
          return JSON.stringify({
            state: state,
            title: String(track.name()),
            artist: String(track.artist()),
            duration: Number(track.duration()) / 1000,
            position: Number(spotify.playerPosition())
          });
        }
        """
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", script]
            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }
            guard process.terminationStatus == 0 else { return nil }
            return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        }.value
    }
}
