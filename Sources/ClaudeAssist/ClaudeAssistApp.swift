import AppKit

@main
enum ClaudeAssistApp {
    static func main() {
        UserDefaults.registerAppDefaults()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.start()
        statusBar = StatusBarController(store: UsageStore())
    }
}

/// Draws the small horizontal bar shown in the menu bar.
enum MenuBarIcon {
    static let size = NSSize(width: 30, height: 18)

    /// Warns as session usage climbs: yellow from 70%, orange from 80%, red from 90%.
    static func fillColor(used: Double) -> NSColor {
        switch used {
        case 90...: return .systemRed
        case 80...: return .systemOrange
        case 70...: return .systemYellow
        default: return .systemGreen
        }
    }

    static func image(remaining: Double?, hasError: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let barHeight: CGFloat = 7
            let track = NSRect(x: 1, y: (rect.height - barHeight) / 2,
                               width: rect.width - 2, height: barHeight)
            let radius = barHeight / 2

            NSColor.labelColor.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius).fill()

            if let remaining {
                let fraction = CGFloat(remaining / 100)
                if fraction > 0 {
                    var fill = track
                    fill.size.width = max(barHeight, track.width * fraction)
                    fillColor(used: 100 - remaining).setFill()
                    NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()
                }
            } else if hasError {
                NSColor.systemRed.setStroke()
                let outline = NSBezierPath(roundedRect: track.insetBy(dx: 0.5, dy: 0.5),
                                           xRadius: radius, yRadius: radius)
                outline.lineWidth = 1
                outline.stroke()
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = remaining.map { "Claude session \(Int($0.rounded()))% remaining" }
            ?? "Claude Assist"
        return image
    }
}
