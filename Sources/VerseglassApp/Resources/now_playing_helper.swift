// Long-running helper. Must run via Apple-signed /usr/bin/swift so MediaRemote
// returns data on macOS 15.4+ (unsigned apps are rejected).
// One JSON object per line on stdout.
import AppKit
import Foundation

NSApplication.shared.setActivationPolicy(.prohibited)

typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
typealias GetIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
typealias GetPIDFn = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void

let frameworkURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
guard let bundle = CFBundleCreate(kCFAllocatorDefault, frameworkURL as CFURL),
      let infoPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString),
      let playingPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString)
else {
    FileHandle.standardError.write("MediaRemote bind failed\n".data(using: .utf8)!)
    exit(1)
}

let getInfo = unsafeBitCast(infoPtr, to: GetInfoFn.self)
let getIsPlaying = unsafeBitCast(playingPtr, to: GetIsPlayingFn.self)
let getPID: GetPIDFn? = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationPID" as CFString)
    .map { unsafeBitCast($0, to: GetPIDFn.self) }
let workQueue = DispatchQueue(label: "verseglass.nowplaying", qos: .userInitiated)

func emit(_ dict: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let line = String(data: data, encoding: .utf8)
    else { return }
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

func poll() {
    getInfo(workQueue) { info in
        var dict: [String: Any] = [:]
        if let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String { dict["title"] = title }
        if let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String { dict["artist"] = artist }
        if let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String { dict["album"] = album }
        if let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double { dict["duration"] = duration }
        if let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double { dict["elapsed"] = elapsed }
        if let timestamp = info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
            dict["timestamp"] = timestamp.timeIntervalSince1970
        }
        getIsPlaying(workQueue) { isPlaying in
            dict["isPlaying"] = isPlaying
            guard let getPID else {
                emit(dict)
                return
            }
            getPID(workQueue) { pid in
                if pid > 0,
                   let app = NSRunningApplication(processIdentifier: pid),
                   let bundleID = app.bundleIdentifier {
                    dict["bundleId"] = bundleID
                }
                emit(dict)
            }
        }
    }
}

Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in poll() }
poll()
RunLoop.main.run()
