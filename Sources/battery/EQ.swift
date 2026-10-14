import Foundation

/// Một preset equalizer: gain (dB) cho từng dải tần.
struct EQPreset: Equatable {
    let name: String
    let gains: [Double]
}

/// Các preset EQ nổi tiếng + dải tần dùng cho Web Audio (BiquadFilter peaking).
enum EQ {

    /// 6 dải: sub-bass, bass, low-mid, mid, upper-mid, treble.
    static let bands: [Double] = [60, 230, 910, 3000, 6000, 12000]

    static let presets: [EQPreset] = [
        EQPreset(name: "Flat", gains: [0, 0, 0, 0, 0, 0]),
        // Bass + treble mạnh, hạ mid sâu — sôi động.
        EQPreset(name: "V-Shape", gains: [6, 3, -3, -2, 3, 6]),
        // Sub-bass + treble đẩy, mid giữ vừa (không lùi sâu) — nịnh tai, sáng.
        EQPreset(name: "U-Shape (Harman)", gains: [6, 2, -1, 1, 4, 5]),
        // Mid đẩy tới, treble mượt — nghiện vocal, ballad/bolero.
        EQPreset(name: "Mid-Forward (Vocal)", gains: [-2, 0, 3, 4, 2, 0]),
        // Tăng trầm.
        EQPreset(name: "Bass Boost", gains: [8, 5, 2, 0, 0, 0]),
        // Tăng cao.
        EQPreset(name: "Treble Boost", gains: [0, 0, 0, 2, 5, 8]),
        // Trong trẻo cho nhạc mộc.
        EQPreset(name: "Acoustic", gains: [3, 1, 2, 3, 3, 2]),
        // Giảm chói, êm tai.
        EQPreset(name: "Warm / Êm", gains: [3, 2, 1, 0, -2, -3]),
    ]

    static func preset(named name: String) -> EQPreset {
        presets.first { $0.name == name } ?? presets[0]
    }

    /// Tên preset khớp với mảng gain, hoặc "Tùy chỉnh".
    static func name(for gains: [Double]) -> String {
        presets.first { $0.gains == gains }?.name ?? "Tùy chỉnh"
    }

    /// Nhãn tần số ngắn gọn cho mỗi dải (vd "60", "3k").
    static func bandLabel(_ freq: Double) -> String {
        freq < 1000 ? "\(Int(freq))" : "\(Int(freq / 1000))k"
    }
}
