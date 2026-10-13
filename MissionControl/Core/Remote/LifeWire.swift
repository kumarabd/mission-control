import Foundation

/// The Life Engine's JSON as the server sends it. Kept apart from the app's own models (`Reminder`, `Goal`, ...) so the
/// wire format can change without touching screens; `Tests/LifeContractChecks.swift` decodes real recorded responses.
enum Wire {
    struct Link: Codable, Equatable { var entity: String; var id: String }

    struct Recurrence: Codable, Equatable {
        var freq: String
        var interval: Int?
        var weekdays: [Int]?
    }

    struct Reminder: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var notes: String
        var dueAt: Date?
        var snoozedUntil: Date?
        var timeZone: String
        var recurrence: Recurrence?
        var source: String
        var sessionId: String?
        var turnSeq: Int?
        var link: Link?
        var state: String            // pending | done
        var completedAt: Date?
        var lastCompletedAt: Date?
        var version: Int
        var deletedAt: Date?
        var createdAt: Date
        var updatedAt: Date
        var isDone: Bool { state == "done" }
    }

    struct Routine: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var minutes: Int
        var shortTitle: String
        var shortMinutes: Int
        var weekdays: [Int]          // 0 = Sunday ... 6; empty means every day
        var targetPerDay: Int
        var cues: [String]           // "HH:MM" local nudge times
        var timeZone: String
        var version: Int
        var deletedAt: Date?
        var createdAt: Date
        var updatedAt: Date
    }

    /// One routine on one day: how many times so far against its target, and how it is going.
    struct RoutineStatus: Codable, Equatable, Identifiable {
        var routine: Routine
        var scheduled: Bool
        var target: Int
        var count: Int
        var done: Bool
        var variant: String?
        var streak: Int
        var daysSinceLast: Int?
        var gap: Bool
        var hint: String
        var id: String { routine.id }
    }

    struct RoutinesStatus: Codable, Equatable {
        var day: String
        var items: [RoutineStatus]
    }

    struct HistoryDay: Codable, Equatable, Identifiable {
        var day: String
        var scheduled: Bool
        var count: Int
        var target: Int
        var done: Bool
        var id: String { day }
    }

    struct Consistency: Codable, Equatable {
        var done: Int
        var scheduled: Int
    }

    /// What a tracker draws: recent days (oldest first, ending today), a rate over 7 and 30 days, and the best run.
    struct RoutineHistory: Codable, Equatable {
        var routine: Routine
        var days: [HistoryDay]
        var last7: Consistency
        var last30: Consistency
        var streak: Int
        var bestStreak: Int
    }

    struct Page<T: Codable & Equatable>: Codable, Equatable {
        var items: [T]
        var total: Int
        var nextOffset: Int?
    }

    struct Step: Codable, Equatable, Identifiable {
        var id: String; var goalId: String; var title: String; var minutes: Int; var position: Int
        var doneAt: Date?; var version: Int
    }

    struct Goal: Codable, Equatable, Identifiable {
        struct Progress: Codable, Equatable { var done: Int; var total: Int }
        var id: String; var title: String; var why: String; var weeklyTarget: Int
        var archivedAt: Date?; var version: Int
        var steps: [Step]; var progress: Progress; var nextStep: Step?
    }

    struct PlanItem: Codable, Equatable, Identifiable {
        var id: String; var day: String; var title: String
        var kind: String          // task | event | prep | rest
        var minutes: Int; var startAt: Date?; var isPriority: Bool
        var goalId: String?; var stepId: String?
        var doneAt: Date?; var version: Int; var deletedAt: Date?
    }

    struct ProposalChange: Codable, Equatable {
        var action: String        // add | move | drop
        var itemId: String?; var title: String?; var minutes: Int?; var kind: String?; var isPriority: Bool?; var day: String?
    }

    struct PlanProposal: Codable, Equatable, Identifiable {
        var id: String; var day: String; var reason: String
        var changes: [ProposalChange]
        var state: String         // pending | applied | discarded
        var version: Int
    }

    struct PlanDay: Codable, Equatable {
        struct Summary: Codable, Equatable { var planned: Int; var done: Int; var minutesOpen: Int; var minutesDone: Int; var minutesEvents: Int }
        var day: String; var items: [PlanItem]; var proposals: [PlanProposal]; var summary: Summary
    }

    struct Suggestion: Codable, Equatable {
        var title: String; var minutes: Int; var reason: String
        var source: String        // plan_item | goal_step
        var planItemId: String?; var goalId: String?; var stepId: String?
    }
    struct NextAction: Codable, Equatable { var suggestion: Suggestion? }

    struct Replan: Codable, Equatable {
        var keep: [PlanItem]; var moveToTomorrow: [PlanItem]; var minutesKept: Int
    }

    struct Settings: Codable, Equatable {
        var id: String; var timeZone: String; var workStart: String; var workEnd: String; var version: Int
    }

    struct Capture: Codable, Equatable, Identifiable {
        var id: String; var text: String; var capturedAt: Date; var source: String
        var state: String         // open | resolved
        var resolvedAs: String?; var resolvedId: String?; var version: Int
    }

    struct APIError: Codable, Equatable { var code: String; var message: String }
    struct ErrorEnvelope: Codable { var error: APIError }

    /// One decoder for every response: snake_case keys, and timestamps with or without fractional seconds.
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: s) ?? plain.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not an RFC 3339 timestamp: \(s)"))
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(plain.string(from: date))
        }
        return e
    }()

    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
}


extension Wire.Reminder {
    /// Done, or a repeating reminder whose latest occurrence has been ticked off. It stays on screen, struck through, until
    /// the next occurrence is due (a repeating reminder is never "finished", so the engine keeps it pending).
    func doneForNow(now: Date = Date()) -> Bool {
        if isDone { return true }
        guard let rule = recurrence, let completed = lastCompletedAt, let due = snoozedUntil == nil ? dueAt : nil else { return false }
        return completed > due.addingTimeInterval(-rule.approximatePeriod)
    }

    /// Open reminders always; a finished one only for a day, so the list shows what you just did without keeping it forever.
    func isShown(now: Date = Date()) -> Bool {
        guard isDone else { return true }
        return (completedAt ?? updatedAt) > now.addingTimeInterval(-24 * 3600)
    }

    /// "Every day", "Every 2 weeks on Mon, Wed", for the detail screen.
    var repeatDescription: String? {
        guard let rule = recurrence else { return nil }
        let n = max(rule.interval ?? 1, 1)
        let unit = ["daily": "day", "weekly": "week", "monthly": "month"][rule.freq] ?? rule.freq
        var text = n == 1 ? "Every \(unit)" : "Every \(n) \(unit)s"
        if rule.freq == "weekly", let days = rule.weekdays, !days.isEmpty {
            let names = Calendar.current.shortWeekdaySymbols
            text += " on " + days.sorted().compactMap { names.indices.contains($0) ? names[$0] : nil }.joined(separator: ", ")
        }
        return text
    }
}

extension Wire.Recurrence {
    /// The shortest gap between two occurrences, for deciding whether the latest one has been completed.
    var approximatePeriod: TimeInterval {
        let n = TimeInterval(max(interval ?? 1, 1))
        switch freq {
        case "daily": return n * 86_400
        case "monthly": return n * 28 * 86_400
        default:
            guard let days = weekdays, days.count > 1 else { return n * 7 * 86_400 }
            let sorted = days.sorted()
            let gaps = zip(sorted, sorted.dropFirst() + [sorted[0] + 7]).map { $1 - $0 }
            return TimeInterval(gaps.min() ?? 7) * 86_400
        }
    }
}
