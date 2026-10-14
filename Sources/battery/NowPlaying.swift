import Foundation

/// Thông tin "đang phát" lấy từ CLI `media-control` (ungive/mediaremote-adapter).
struct NowPlaying: Equatable {
    let title: String
    let artist: String
    let app: String
    let duration: Double    // giây
    let elapsed: Double     // giây (tại thời điểm `timestamp`)
    let timestamp: Date?    // thời điểm `elapsed` được ghi
    let playing: Bool
    let artwork: Data?
}

/// Đọc now-playing và gửi lệnh điều khiển qua `media-control`.
final class NowPlayingController {

    /// Đường dẫn tới `media-control` (Homebrew). nil nếu chưa cài.
    static let toolPath: String? = {
        for path in ["/opt/homebrew/bin/media-control", "/usr/local/bin/media-control"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }()

    var isAvailable: Bool { Self.toolPath != nil }

    private let queue = DispatchQueue(label: "NowPlayingController")

    /// Lấy thông tin hiện tại (chạy nền, callback trên main).
    func fetch(completion: @escaping (NowPlaying?) -> Void) {
        guard let tool = Self.toolPath else { completion(nil); return }
        queue.async {
            let data = Self.run(tool, ["get"])
            let np = data.flatMap(Self.parse)
            DispatchQueue.main.async { completion(np) }
        }
    }

    func togglePlayPause() { runAsync(["toggle-play-pause"]) }
    func next() { runAsync(["next-track"]) }
    func previous() { runAsync(["previous-track"]) }
    func seek(_ seconds: Double) { runAsync(["seek", String(format: "%.2f", max(0, seconds))]) }

    // MARK: - Private

    private func runAsync(_ args: [String]) {
        guard let tool = Self.toolPath else { return }
        queue.async { _ = Self.run(tool, args) }
    }

    static func parse(_ data: Data) -> NowPlaying? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = obj["title"] as? String, !title.isEmpty else {
            return nil
        }
        let artwork = (obj["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
        let timestamp = (obj["timestamp"] as? String).flatMap(parseDate)
        return NowPlaying(
            title: title,
            artist: obj["artist"] as? String ?? "",
            app: obj["bundleIdentifier"] as? String ?? "",
            duration: (obj["duration"] as? NSNumber)?.doubleValue ?? 0,
            elapsed: (obj["elapsedTime"] as? NSNumber)?.doubleValue ?? 0,
            timestamp: timestamp,
            playing: (obj["playing"] as? Bool) ?? false,
            artwork: artwork
        )
    }

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static func parseDate(_ s: String) -> Date? {
        isoPlain.date(from: s) ?? isoFractional.date(from: s)
    }

    private static func run(_ path: String, _ args: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }
}
