// Renders the app icon to Icon/AppIcon.png (1024×1024).
// Run via Icon/make_icon.sh, which also produces AppIcon.icns.
import AppKit

let canvas: CGFloat = 1024
let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824pt body centered on a 1024pt canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Drop shadow under the body.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
color(0x1C1B22).setFill()
bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()

// Body gradient and a soft top highlight.
NSGradient(starting: color(0x34323D), ending: color(0x16151B))!.draw(in: bodyPath, angle: -90)
NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()
color(0xFFFFFF, 0.08).setStroke()
let rim = NSBezierPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), xRadius: 184, yRadius: 184)
rim.lineWidth = 3
rim.stroke()

// Two usage bars, like the session and weekly rows in the app, in Claude's brand orange.
func bar(y: CGFloat, height: CGFloat, fraction: CGFloat, start: UInt32, end: UInt32) {
    let track = NSRect(x: 232, y: y, width: 560, height: height)
    let radius = height / 2
    color(0xFFFFFF, 0.12).setFill()
    NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius).fill()

    var fill = track
    fill.size.width = max(height, track.width * fraction)
    let fillPath = NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = color(start, 0.55)
    glow.shadowBlurRadius = 36
    glow.set()
    color(start).setFill()
    fillPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: color(start), ending: color(end))!.draw(in: fillPath, angle: 0)
}

bar(y: 578, height: 118, fraction: 0.78, start: 0xD97757, end: 0xE89A7E)
bar(y: 398, height: 82, fraction: 0.52, start: 0xD97757, end: 0xE89A7E)

// Small tick marks under the bars, a hint of a gauge scale.
color(0xFFFFFF, 0.18).setFill()
for i in 0...4 {
    let x = 232 + CGFloat(i) * 140 - 4
    NSBezierPath(roundedRect: NSRect(x: x, y: 322, width: 8, height: i % 2 == 0 ? 34 : 22),
                 xRadius: 4, yRadius: 4).fill()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
