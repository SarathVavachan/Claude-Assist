import Foundation

struct UsageWindow: Equatable, Codable {
    /// Percent used, 0...100.
    let utilization: Double
    let resetsAt: Date?

    var remaining: Double { max(0, min(100, 100 - utilization)) }
}

struct UsageSnapshot: Equatable, Codable {
    let session: UsageWindow
    let weekly: UsageWindow
    let fetchedAt: Date
}

enum UsageError: LocalizedError {
    case claudeNotFound
    case cliFailed(String)
    case rateLimited(retryAfter: TimeInterval?)
    case unparseable(String)

    var errorDescription: String? {
        switch self {
        case .claudeNotFound: return "Claude CLI not found. Install Claude Code first."
        case .cliFailed(let message): return "Claude CLI error: \(message)"
        case .rateLimited: return "The usage API is rate limiting requests."
        case .unparseable(let output): return "Couldn't read usage from the Claude CLI: \(output)"
        }
    }
}

/// Gets usage by running the locally installed Claude CLI's `/usage` command
/// (`claude -p /usage`), which is answered locally without a model call.
enum UsageService {
    static func fetch() async throws -> UsageSnapshot {
        guard let claude = claudeExecutable() else { throw UsageError.claudeNotFound }
        let output = try run(claude, ["-p", "/usage", "--no-session-persistence"])
        return try parse(output, now: Date())
    }

    // MARK: - Parsing

    /// Parses lines such as:
    ///   Current session: 10% used · resets Oct 4 at 11:10am (Asia/Dubai)
    ///   Current week (all models): 14% used · resets Oct 4 at 4pm (Asia/Dubai)
    static func parse(_ output: String, now: Date) throws -> UsageSnapshot {
        let lines = output.components(separatedBy: .newlines)
        let sessionLine = lines.first { $0.hasPrefix("Current session") }
        let weeklyLine = lines.first { $0.hasPrefix("Current week (all models)") }
            ?? lines.first { $0.hasPrefix("Current week") }

        guard let sessionLine, let weeklyLine,
              let session = parseWindow(sessionLine, now: now),
              let weekly = parseWindow(weeklyLine, now: now)
        else {
            if output.localizedCaseInsensitiveContains("rate limit") {
                throw UsageError.rateLimited(retryAfter: nil)
            }
            let summary = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "empty output"
            throw UsageError.unparseable(summary)
        }
        return UsageSnapshot(session: session, weekly: weekly, fetchedAt: now)
    }

    private static let percentPattern = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)%\s*used"#)
    private static let resetPattern = try! NSRegularExpression(
        pattern: #"resets\s+(?:([A-Za-z]{3,9})\s+(\d{1,2})(?:,?\s+(\d{4}))?\s+at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)(?:\s*\(([^)]+)\))?"#,
        options: [.caseInsensitive]
    )

    private static func parseWindow(_ line: String, now: Date) -> UsageWindow? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = percentPattern.firstMatch(in: line, range: range),
              let percent = Double(substring(line, match.range(at: 1)) ?? "")
        else { return nil }
        return UsageWindow(utilization: percent, resetsAt: parseReset(line, now: now))
    }

    private static func parseReset(_ line: String, now: Date) -> Date? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = resetPattern.firstMatch(in: line, range: range),
              var hour = Int(substring(line, match.range(at: 4)) ?? "")
        else { return nil }

        let minute = Int(substring(line, match.range(at: 5)) ?? "") ?? 0
        let isPM = substring(line, match.range(at: 6))?.lowercased() == "pm"
        hour = hour % 12 + (isPM ? 12 : 0)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = substring(line, match.range(at: 7)).flatMap(TimeZone.init(identifier:)) ?? .current

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute

        let monthName = substring(line, match.range(at: 1))
        if let monthName {
            guard let month = monthNumber(monthName),
                  let day = Int(substring(line, match.range(at: 2)) ?? "")
            else { return nil }
            components.month = month
            components.day = day
            if let year = substring(line, match.range(at: 3)).flatMap(Int.init) {
                components.year = year
            }
        }

        guard var date = calendar.date(from: components) else { return nil }
        // Resets are always in the future; roll over a missing day or year.
        if monthName == nil, date < now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        } else if monthName != nil, date < now.addingTimeInterval(-30 * 86_400) {
            date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
        return date
    }

    private static func monthNumber(_ name: String) -> Int? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return months.firstIndex(of: name.prefix(3).lowercased()).map { $0 + 1 }
    }

    private static func substring(_ string: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound, let r = Range(range, in: string) else { return nil }
        return String(string[r])
    }

    // MARK: - Claude CLI

    private static func claudeExecutable() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func run(_ path: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        // Run outside any project so no project settings, hooks or trust prompts apply.
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        // Drain stderr concurrently so a chatty CLI can't fill the pipe and block.
        var errData = Data()
        let errReader = Thread { errData = err.fileHandleForReading.readDataToEndOfFile() }
        errReader.start()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        while !errReader.isFinished { Thread.sleep(forTimeInterval: 0.01) }

        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if (message + output).localizedCaseInsensitiveContains("rate limit") {
                throw UsageError.rateLimited(retryAfter: nil)
            }
            throw UsageError.cliFailed(message.isEmpty ? "exit code \(process.terminationStatus)" : message)
        }
        return output
    }
}
