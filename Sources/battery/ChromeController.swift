import Foundation
import AppKit

/// Điều khiển Chrome để phát video trong tab YouTube đang mở, KHÔNG đưa
/// Chrome lên trước và không đổi view người dùng đang xem.
enum ChromeController {

    /// Thay URL của tab YouTube đang mở. Trả true nếu thay được.
    @discardableResult
    static func playInExistingYouTubeTab(_ url: URL) -> Bool {
        let link = url.absoluteString.replacingOccurrences(of: "\"", with: "")
        let script = """
        tell application "Google Chrome"
            set replaced to false
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t contains "youtube.com") then
                        set URL of t to "\(link)"
                        set replaced to true
                        exit repeat
                    end if
                end repeat
                if replaced then exit repeat
            end repeat
            return replaced
        end tell
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        if error != nil { return false }
        return result?.booleanValue ?? false
    }

    /// Bấm nút next của trình phát YouTube (hoạt động với mọi video, kể cả
    /// mở trực tiếp). Cần bật "Allow JavaScript from Apple Events" trong Chrome.
    /// Bật/tắt lặp lại video YouTube (video.loop).
    @discardableResult
    static func setLoop(_ enabled: Bool) -> Bool {
        runYouTubeJS("var v=document.querySelector('video');if(v){v.loop=\(enabled ? "true" : "false");} 'ok'")
    }

    @discardableResult
    static func youtubeNext() -> Bool {
        runYouTubeJS("var b=document.querySelector('.ytp-next-button'); if(b){b.click();} 'ok'")
    }

    @discardableResult
    static func youtubePrevious() -> Bool {
        // Nút prev của player thường ẩn/disabled với video đơn lẻ → quay lại
        // video trước bằng history.back().
        runYouTubeJS("var b=document.querySelector('.ytp-prev-button'); if(b && b.getAttribute('aria-disabled')!=='true'){b.click();} else {history.back();} 'ok'")
    }

    private static func runYouTubeJS(_ js: String) -> Bool {
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t contains "youtube.com") then
                        execute t javascript "\(js)"
                        return true
                    end if
                end repeat
            end repeat
            return false
        end tell
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        if error != nil { return false }
        return result?.booleanValue ?? false
    }

    /// Áp EQ (Web Audio BiquadFilter) vào video YouTube trong tab Chrome.
    /// Cần bật "Allow JavaScript from Apple Events".
    static func applyEQ(gains: [Double], freqs: [Double]) {
        let g = "[" + gains.map { String($0) }.joined(separator: ",") + "]"
        let f = "[" + freqs.map { String($0) }.joined(separator: ",") + "]"
        let js = "(function(gs,fs){try{var v=document.querySelector('video');if(!v)return 'novid';"
            + "if(!window.__eq){var C=window.AudioContext||window.webkitAudioContext;var ctx=new C();"
            + "var src=ctx.createMediaElementSource(v);var arr=fs.map(function(fr){var b=ctx.createBiquadFilter();"
            + "b.type='peaking';b.frequency.value=fr;b.Q.value=1.1;b.gain.value=0;return b;});var n=src;"
            + "arr.forEach(function(x){n.connect(x);n=x;});n.connect(ctx.destination);window.__eq={ctx:ctx,filters:arr};}"
            + "if(window.__eq.ctx.state==='suspended'){window.__eq.ctx.resume();}"
            + "gs.forEach(function(gv,i){if(window.__eq.filters[i]){window.__eq.filters[i].gain.value=gv;}});"
            + "return 'ok';}catch(e){return 'err';}})(\(g),\(f));"
        _ = runYouTubeJS(js)
    }

    /// Video ID của tab YouTube đang mở (đọc từ URL, không cần JS).
    static func currentYouTubeVideoID() -> String? {
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t contains "youtube.com/watch") then return (URL of t)
                end repeat
            end repeat
            return ""
        end tell
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(&error),
              error == nil, let urlString = result.stringValue,
              let comps = URLComponents(string: urlString) else {
            return nil
        }
        return comps.queryItems?.first(where: { $0.name == "v" })?.value
    }

    /// Chrome có đang chạy không.
    static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.google.Chrome" }
    }
}
