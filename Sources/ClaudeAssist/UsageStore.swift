import Foundation
import Combine

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    /// Recent session-utilization samples, used for the timeline graph.
    @Published private(set) var history: [UsagePoint] = []
    @Published private(set) var refreshInterval = UserDefaults.standard.refreshInterval
    /// Set while backing off after a 429; scheduled refreshes are skipped until then.
    @Published private(set) var retryAt: Date?
    /// When the next scheduled refresh fires (not accounting for rate-limit backoff).
    @Published private(set) var nextRefreshAt: Date?

    private static let cacheKey = "lastSnapshot"
    private static let historyKey = "sessionHistory"
    private static let historyLength: TimeInterval = 6 * 3600
    private static let initialBackoff: TimeInterval = 60
    private static let maxBackoff: TimeInterval = 15 * 60

    private var backoff = UsageStore.initialBackoff
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Show the last known numbers immediately, even if the first request is rate limited.
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey) {
            snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data)
        }
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let saved = try? JSONDecoder().decode([UsagePoint].self, from: data) {
            history = saved
        }
        refresh()
        UserDefaults.standard.publisher(for: \.refreshInterval)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seconds in self?.scheduleTimer(seconds: seconds) }
            .store(in: &cancellables)
    }

    /// Manual refreshes ignore the backoff; scheduled ones respect it.
    func refresh(scheduled: Bool = false) {
        guard !isLoading else { return }
        if scheduled, let retryAt, retryAt > Date() { return }
        // A manual refresh restarts the countdown to the next automatic one.
        if !scheduled, timer != nil { scheduleTimer(seconds: refreshInterval) }
        isLoading = true
        Task {
            do {
                let fresh = try await UsageService.fetch()
                if let previous = snapshot {
                    // Compared against the last reading, which is also restored from the
                    // cache at launch, so resets that happened while the app was closed count.
                    Notifier.notifyRenewal(
                        session: ResetDetector.renewed(previous: previous.session, current: fresh.session, now: fresh.fetchedAt),
                        weekly: ResetDetector.renewed(previous: previous.weekly, current: fresh.weekly, now: fresh.fetchedAt))
                }
                snapshot = fresh
                recordHistory(fresh)
                UserDefaults.standard.set(try? JSONEncoder().encode(fresh), forKey: Self.cacheKey)
                errorMessage = nil
                retryAt = nil
                backoff = Self.initialBackoff
            } catch UsageError.rateLimited(let retryAfter) {
                let delay = max(retryAfter ?? 0, backoff)
                retryAt = Date().addingTimeInterval(delay)
                backoff = min(backoff * 2, Self.maxBackoff)
                errorMessage = UsageError.rateLimited(retryAfter: retryAfter).localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func recordHistory(_ snap: UsageSnapshot) {
        // Usage only ever grows within a session, so a drop means it was reset: start fresh.
        if let last = history.last, snap.session.utilization < last.percent { history = [] }
        let cutoff = snap.fetchedAt.addingTimeInterval(-Self.historyLength)
        history = (history + [UsagePoint(date: snap.fetchedAt, percent: snap.session.utilization)])
            .filter { $0.date >= cutoff }
        UserDefaults.standard.set(try? JSONEncoder().encode(history), forKey: Self.historyKey)
    }

    /// When the next automatic refresh will actually happen, including any backoff.
    func nextRefresh(now: Date) -> Date? {
        guard let nextRefreshAt else { return nil }
        if let retryAt, retryAt > nextRefreshAt { return retryAt }
        return nextRefreshAt
    }

    /// One-line status for the menu and popover, or nil when everything is fine.
    func statusNote(now: Date) -> String? {
        if let retryAt, retryAt > now {
            return "Rate limited by the usage API · retrying in \(Formatting.countdown(to: retryAt, now: now))"
        }
        return errorMessage
    }

    private func scheduleTimer(seconds: Int) {
        refreshInterval = max(5, seconds)
        timer?.invalidate()
        nextRefreshAt = Date().addingTimeInterval(TimeInterval(refreshInterval))
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.nextRefreshAt = Date().addingTimeInterval(TimeInterval(self.refreshInterval))
                self.refresh(scheduled: true)
            }
        }
    }
}

struct UsagePoint: Codable, Equatable, Identifiable {
    let date: Date
    let percent: Double
    var id: Date { date }
}
