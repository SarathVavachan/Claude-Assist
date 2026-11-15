import SwiftUI
import AppKit
import Charts

struct UsagePopoverView: View {
    @ObservedObject var store: UsageStore
    var onOpenSettings: () -> Void = {}

    var body: some View {
        // Re-render every second so the reset countdowns stay live.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    SessionChart(history: store.history,
                                 windowEnd: store.snapshot?.session.resetsAt,
                                 now: context.date,
                                 color: store.snapshot.map {
                                     Color(nsColor: MenuBarIcon.fillColor(used: $0.session.utilization))
                                 } ?? Color(nsColor: .systemGreen))
                        .card()

                    if let snapshot = store.snapshot {
                        UsageRow(title: "Session", subtitle: "5-hour window",
                                 window: snapshot.session, now: context.date)
                            .card()
                        UsageRow(title: "Weekly", subtitle: "7-day window",
                                 window: snapshot.weekly, now: context.date)
                            .card()
                    } else if store.errorMessage == nil {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Loading usage…").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .card()
                    }

                    if let note = store.statusNote(now: context.date) {
                        Label(note, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    footer(now: context.date)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(width: 320)
            .background(Theme.background)
        }
    }

    private var header: some View {
        HStack {
            // 30% larger than the system headline (13pt).
            HStack(spacing: 6) {
                ClaudeLogo(color: Color(red: 0.85, green: 0.47, blue: 0.34))
                    .frame(width: 18, height: 18)
                Text("Claude Assist").font(.system(size: 16.9, weight: .bold))
            }
            Spacer()
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(HoverButtonStyle())
            .help("Settings")
            .accessibilityLabel("Settings")
            .frame(width: 18, height: 18)
            Button {
                store.refresh()
            } label: {
                if store.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(HoverButtonStyle())
            .help("Refresh now")
            .disabled(store.isLoading)
            .frame(width: 18, height: 18)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func refreshText(now: Date) -> String {
        if store.isLoading { return "Refreshing…" }
        guard let next = store.nextRefresh(now: now) else { return "" }
        return "Refreshing in \(Formatting.shortCountdown(to: next, now: now))"
    }

    private func footer(now: Date) -> some View {
        HStack {
            Text(refreshText(now: now))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(QuitButtonStyle())
            .help("Quit Claude Assist")
            .accessibilityLabel("Quit")
        }
    }
}

/// Adaptive palette: soft grey canvas with white cards in light mode,
/// near-black canvas with raised dark cards in dark mode.
enum Theme {
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }
    static let background = dynamic(light: NSColor(white: 0.95, alpha: 1), dark: NSColor(white: 0.10, alpha: 1))
    static let card = dynamic(light: .white, dark: NSColor(white: 0.17, alpha: 1))
}

extension View {
    func card() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
    }
}

/// Borderless button that shows a rounded highlight on hover and press.
/// The highlight is drawn outside the label so it doesn't affect layout.
private struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverHighlight(isPressed: configuration.isPressed) { configuration.label }
    }
}

/// Solid red rounded box that darkens on hover and press.
private struct QuitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuitBox(isPressed: configuration.isPressed) { configuration.label }
    }
}

private struct QuitBox<Label: View>: View {
    let isPressed: Bool
    @ViewBuilder let label: () -> Label
    @StateObject private var hover = HoverState()

    var body: some View {
        label()
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .systemRed))
                    .brightness(isPressed ? -0.25 : (hover.isHovering ? -0.12 : 0))
            )
            .contentShape(Rectangle())
            .onHover { hover.isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hover.isHovering)
    }
}

private final class HoverState: ObservableObject {
    @Published var isHovering = false
}

private struct HoverHighlight<Label: View>: View {
    let isPressed: Bool
    @ViewBuilder let label: () -> Label
    @StateObject private var hover = HoverState()
    @Environment(\.isEnabled) private var isEnabled

    private let outset: CGFloat = 5

    var body: some View {
        label()
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(highlightOpacity))
                    .padding(-outset)
            )
            .contentShape(Rectangle().inset(by: -outset))
            .onHover { hover.isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hover.isHovering)
    }

    private var highlightOpacity: Double {
        guard isEnabled else { return 0 }
        if isPressed { return 0.2 }
        return hover.isHovering ? 0.1 : 0
    }
}

/// Drawn by hand rather than with ProgressView, whose tint the system can
/// override with the accent color (it showed up blue).
private struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(1, fraction)) * proxy.size.width)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent remaining")
    }
}

private struct UsageRow: View {
    let title: String
    let subtitle: String
    let window: UsageWindow
    let now: Date

    private var color: Color { Color(nsColor: MenuBarIcon.fillColor(used: window.utilization)) }

    private var status: (label: String, icon: String) {
        switch window.utilization {
        case 90...: return ("Critical", "xmark.circle.fill")
        case 80...: return ("High", "exclamationmark.circle.fill")
        case 70...: return ("Elevated", "exclamationmark.circle.fill")
        default: return ("Good", "checkmark.circle.fill")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .help("\(subtitle) · \(Int(window.utilization.rounded()))% used")
            }

            HStack(alignment: .lastTextBaseline) {
                Text("\(Int(window.remaining.rounded()))%")
                    .font(.system(size: 21, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                Text(status.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(resetValue)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    Text(resetCaption)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Like the menu bar icon: length shows what's left, color warns by usage.
            UsageBar(fraction: window.remaining / 100, color: color)
        }
    }

    private var resetValue: String {
        guard let resetsAt = window.resetsAt else { return "—" }
        return Formatting.countdown(to: resetsAt, now: now)
    }

    private var resetCaption: String {
        window.resetsAt == nil ? "Not started" : "Until reset"
    }
}

enum Formatting {
    static func countdown(to date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }

    /// Second-level countdown for short spans, e.g. "42s" or "1m 05s".
    static func shortCountdown(to date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now).rounded(.up)))
        if seconds < 60 { return "\(seconds)s" }
        return String(format: "%dm %02ds", seconds / 60, seconds % 60)
    }
}


/// Small Claude-style starburst mark drawn as vector rays.
struct ClaudeLogo: View {
    var color: Color = .primary
    private let lengths: [CGFloat] = [1.0, 0.72, 0.95, 0.8, 1.0, 0.7, 0.92, 0.78, 1.0, 0.74, 0.9, 0.82]

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            var path = Path()
            for (i, len) in lengths.enumerated() {
                let a = Double(i) / Double(lengths.count) * 2 * .pi
                path.move(to: c)
                path.addLine(to: CGPoint(x: c.x + cos(a) * r * len, y: c.y + sin(a) * r * len))
            }
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: r * 0.26, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}


/// Line graph of session usage across the 5-hour window.
struct SessionChart: View {
    let history: [UsagePoint]
    let windowEnd: Date?
    let now: Date
    let color: Color

    private let span: TimeInterval = 5 * 3600
    // With no active window, begin at "now" so the graph starts on the left.
    private var start: Date { windowEnd.map { $0.addingTimeInterval(-span) } ?? now }
    private var end: Date { windowEnd ?? now.addingTimeInterval(span) }
    private var points: [UsagePoint] {
        history.filter { $0.date >= start && $0.date <= end }
    }
    private var accent: Color { color }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Text("Session usage").font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .help("Usage over the last 5 hours")
            }
            Chart {
                ForEach(points) { p in
                    AreaMark(x: .value("Time", p.date), y: .value("Used", p.percent))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(
                            colors: [accent.opacity(0.35), accent.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Time", p.date), y: .value("Used", p.percent))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(accent)
                }
                if let last = points.last {
                    PointMark(x: .value("Time", last.date), y: .value("Used", last.percent))
                        .symbolSize(40)
                        .foregroundStyle(accent)
                }
                RuleMark(x: .value("Now", min(now, end)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .chartXScale(domain: start...end)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { v in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let n = v.as(Int.self) { Text("\(n)%").font(.caption2) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                    AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                        .font(.caption2)
                }
            }
            .overlay {
                if points.count < 2 {
                    Text("Collecting data…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 110)
        }
    }
}
