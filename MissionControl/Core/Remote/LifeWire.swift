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
