import Foundation
import UserNotifications

/// Decides whether a usage window was renewed between two readings.
enum ResetDetector {
    /// Ignore resets older than this, e.g. the Mac was asleep or the app closed for a day.
    static let maxAge: TimeInterval = 3600
    /// The CLI rounds reset times to the minute and the rounding varies between
    /// runs, so a new reset time must be clearly later to count as a new window.
    static let minShift: TimeInterval = 300

    static func renewed(previous: UsageWindow, current: UsageWindow, now: Date) -> Bool {
        guard let previousReset = previous.resetsAt, previousReset <= now,
              now.timeIntervalSince(previousReset) <= maxAge
        else { return false }
        guard let currentReset = current.resetsAt else { return true }  // new window not started yet
        return currentReset > previousReset.addingTimeInterval(minShift)
    }
}

/// Posts macOS notifications when the session or weekly limit renews.
@MainActor
enum Notifier {
    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        // Show banners even though this menu bar app counts as "foreground".
        nonisolated func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .list, .sound]
        }
    }

    private static let delegate = Delegate()
    private static var center: UNUserNotificationCenter { .current() }

    static func start() {
        center.delegate = delegate
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: UserDefaults.Keys.notifyOnReset) }

    static func notifyRenewal(session: Bool, weekly: Bool) {
        guard isEnabled, session || weekly else { return }
        switch (session, weekly) {
        case (true, true):
            post(title: "Claude usage renewed", body: "Your session and weekly limits have both reset.")
        case (true, false):
            post(title: "Claude session renewed", body: "Your 5-hour session limit has reset.")
        default:
            post(title: "Claude weekly limit renewed", body: "Your weekly limit has reset.")
        }
    }

    static func sendTest() {
        post(title: "Claude Assist", body: "Notifications are working. You'll be told when your limits reset.")
    }

    private static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
