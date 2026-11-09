import Foundation

public enum Marquee {
    public static func window(_ text: String, step: Int, width: Int = 42) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        let chars = Array(flat)
        guard chars.count > width, width > 0 else { return flat }
        let padded = chars + Array("   ")
        let start = ((step % padded.count) + padded.count) % padded.count
        var out = ""
        out.reserveCapacity(width)
        for index in 0..<width {
            out.append(padded[(start + index) % padded.count])
        }
        return out
    }
}
