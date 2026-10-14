import Foundation

/// Một kết quả tìm kiếm YouTube.
public struct YouTubeResult: Equatable {
    public let videoId: String
    public let title: String
    public let author: String

    public init(videoId: String, title: String, author: String) {
        self.videoId = videoId
        self.title = title
        self.author = author
    }

    public var watchURL: URL { URL(string: "https://www.youtube.com/watch?v=\(videoId)")! }
    public var thumbnailURL: URL { URL(string: "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg")! }
}

/// Tìm kiếm YouTube bằng cách parse trang kết quả (không cần API key).
public enum YouTubeSearch {

    public static func search(_ query: String, completion: @escaping ([YouTubeResult]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let q = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(q)") else {
            completion([]); return
        }
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let html = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let results = parse(html)
            DispatchQueue.main.async { completion(results) }
        }.resume()
    }

    /// Phân tích HTML → danh sách video (hàm thuần, test được).
    public static func parse(_ html: String) -> [YouTubeResult] {
        guard let json = extractInitialData(html),
              let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        var results: [YouTubeResult] = []
        var seen = Set<String>()
        walk(root) { renderer in
            guard let id = renderer["videoId"] as? String, !seen.contains(id) else { return }
            let title = text(renderer["title"])
            guard !title.isEmpty else { return }
            var author = text(renderer["ownerText"])
            if author.isEmpty { author = text(renderer["longBylineText"]) }
            seen.insert(id)
            results.append(YouTubeResult(videoId: id, title: title, author: author))
        }
        return results
    }

    // MARK: - Private

    /// Trích object JSON của `ytInitialData` bằng cách cân bằng ngoặc.
    /// Duyệt trên byte UTF8 để nhanh (chuỗi HTML ~1.6MB).
    private static func extractInitialData(_ html: String) -> String? {
        guard let marker = html.range(of: "ytInitialData = ") else { return nil }
        let bytes = Array(html.utf8)
        let start = html.utf8.distance(from: html.utf8.startIndex, to: marker.upperBound.samePosition(in: html.utf8) ?? html.utf8.startIndex)

        let open = UInt8(ascii: "{"), close = UInt8(ascii: "}")
        let quote = UInt8(ascii: "\""), backslash = UInt8(ascii: "\\")

        var depth = 0
        var begin = -1
        var inString = false
        var escaped = false
        var i = start
        while i < bytes.count {
            let b = bytes[i]
            if begin < 0 {
                if b == open { begin = i } else { i += 1; continue }
            }
            if escaped { escaped = false; i += 1; continue }
            if b == backslash { escaped = true; i += 1; continue }
            if b == quote { inString.toggle(); i += 1; continue }
            if !inString {
                if b == open { depth += 1 }
                else if b == close {
                    depth -= 1
                    if depth == 0 { return String(decoding: bytes[begin...i], as: UTF8.self) }
                }
            }
            i += 1
        }
        return nil
    }

    private static func walk(_ obj: Any, _ handler: ([String: Any]) -> Void) {
        if let dict = obj as? [String: Any] {
            if let renderer = dict["videoRenderer"] as? [String: Any] { handler(renderer) }
            for value in dict.values { walk(value, handler) }
        } else if let array = obj as? [Any] {
            for value in array { walk(value, handler) }
        }
    }

    private static func text(_ any: Any?) -> String {
        guard let dict = any as? [String: Any] else { return "" }
        if let simple = dict["simpleText"] as? String { return simple }
        if let runs = dict["runs"] as? [[String: Any]] {
            return runs.compactMap { $0["text"] as? String }.joined()
        }
        return ""
    }
}
