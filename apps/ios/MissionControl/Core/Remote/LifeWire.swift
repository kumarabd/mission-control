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

    /// A task or an event: one record, told apart by `kind` (project-hub life-engine ADR 0008). A task waits for someone to do
    /// it, so a time on it is a deadline or a cue; an event happens at its time. Either may repeat and either may alert; a
    /// reminder is an alert, and a routine is a task that repeats.
    struct Item: Codable, Equatable, Identifiable {
        var id: String
        var kind: String             // task | event
        var subject: String          // person | agent
        var title: String
        var notes: String
        var goalId: String?
        var at: Date?
        var minutes: Int?
        var timeZone: String
        var recurrence: Recurrence?
        var alertBeforeMinutes: Int?
        var isPriority: Bool
        var snoozedUntil: Date?
        var doneAt: Date?
        var version: Int
        var deletedAt: Date?
        var createdAt: Date
        var updatedAt: Date
        var isTask: Bool { kind == "task" }
        var isEvent: Bool { kind == "event" }
        var isDone: Bool { doneAt != nil }
        var repeats: Bool { recurrence != nil }
    }

    struct Goal: Codable, Equatable, Identifiable {
        struct Progress: Codable, Equatable { var done: Int; var total: Int }
        var id: String
        var subject: String
        var title: String
        var notes: String
        var endsOn: String?          // YYYY-MM-DD
        var progress: Progress
        var next: Item?
        var version: Int
        var deletedAt: Date?
    }

    /// One occurrence of a task or event on a day. A repeating item appears once for each time it falls.
    struct DayEntry: Codable, Equatable, Identifiable {
        var item: Item
        var at: Date
        var state: String            // tasks: open | done. Events: upcoming | past
        var overdue: Bool            // an open one-off task from an earlier day, carried onto today
        var id: String { item.id + "@" + String(Int(at.timeIntervalSince1970)) }
        var isDone: Bool { state == "done" }
    }

    struct Day: Codable, Equatable {
        var day: String
        var entries: [DayEntry]
    }

    struct Page<T: Codable & Equatable>: Codable, Equatable {
        var items: [T]
        var total: Int
        var nextOffset: Int?
    }

    struct Settings: Codable, Equatable {
        var id: String; var timeZone: String; var workStart: String; var workEnd: String; var version: Int
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


extension Wire.Item {
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

    /// "At the time", "15 minutes before", "1 hour before", or nil when there is no alert.
    var alertDescription: String? {
        guard let m = alertBeforeMinutes else { return nil }
        switch m {
        case 0: return "At the time"
        case 1..<60: return "\(m) minutes before"
        case 60: return "1 hour before"
        case let m where m % 1440 == 0: return m == 1440 ? "1 day before" : "\(m / 1440) days before"
        case let m where m % 60 == 0: return "\(m / 60) hours before"
        default: return "\(m) minutes before"
        }
    }
}

extension Wire.Goal {
    /// "By Jun 10" for a goal with an end date.
    var endsOnText: String? {
        guard let endsOn else { return nil }
        let parser = DateFormatter(); parser.locale = Locale(identifier: "en_US_POSIX"); parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: endsOn).map { "By " + $0.formatted(.dateTime.month(.abbreviated).day()) }
    }
}

