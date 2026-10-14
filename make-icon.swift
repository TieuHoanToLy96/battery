import AppKit

let px = 1024
let image = NSImage(size: NSSize(width: px, height: px))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: px, height: px)

// Nền squircle gradient (xanh lá → xanh dương, chủ đề pin + bluetooth).
let radius = CGFloat(px) * 0.2237
let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
bg.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.18, green: 0.80, blue: 0.44, alpha: 1),
    NSColor(srgbRed: 0.03, green: 0.52, blue: 0.98, alpha: 1),
])
gradient?.draw(in: rect, angle: -55)

// Lớp sáng nhẹ ở trên cho cảm giác bóng.
NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.clear])?
    .draw(in: rect, angle: -90)

// Biểu tượng pin trắng ở giữa (thử vài tên SF Symbol).
let config = NSImage.SymbolConfiguration(pointSize: 560, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
let names = ["battery.100percent.bolt", "battery.100.bolt", "battery.100percent", "battery.100"]
var symbol: NSImage?
for name in names {
    if let s = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        symbol = s; break
    }
}
if let symbol {
    let s = symbol.size
    // Đổ bóng nhẹ cho icon.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    symbol.draw(in: NSRect(x: (CGFloat(px) - s.width) / 2, y: (CGFloat(px) - s.height) / 2, width: s.width, height: s.height))
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("fail"); exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icon-1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
