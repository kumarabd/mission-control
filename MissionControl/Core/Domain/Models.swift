import Foundation

struct Step: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var minutes: Int
    var doneAt: Date?
    var isDone: Bool { doneAt != nil }
}

struct Goal: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var why: String
    var steps: [Step]
    /// Steps the person commits to finish each week.
    var weeklyTarget: Int
    var createdAt = Date()

    var nextStep: Step? { steps.first { !$0.isDone } }
    var fraction: Double { steps.isEmpty ? 0 : Double(steps.filter(\.isDone).count) / Double(steps.count) }
}

enum PlanKind: String, Codable { case task, event, prep, rest }

struct PlanItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var kind: PlanKind = .task
    var minutes: Int = 25
    /// Start of the day this belongs to.
    var day: Date
    var start: Date?
    var isPriority = false
    var goalID: UUID?
    var doneAt: Date?
    var isDone: Bool { doneAt != nil }
}

struct Routine: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var minutes: Int
    /// The version for a busy day.
    var shortTitle: String
    var shortMinutes: Int
    var doneOn: [Date] = []   // start-of-day dates

    func isDone(on day: Date) -> Bool { doneOn.contains(day) }
}

struct JournalEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var text: String
    var goalIDs: [UUID] = []
    var tomorrow: String?
}

enum MemoryKind: String, Codable, CaseIterable { case note, decision, moment }

struct Memory: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var text: String
    /// Why it was decided, for decisions.
    var reason: String?
    var kind: MemoryKind = .note
}

extension MemoryKind {
    var label: String { switch self { case .note: "Note"; case .decision: "Decision"; case .moment: "Moment" } }
    var symbol: String { switch self { case .note: "note.text"; case .decision: "signpost.right"; case .moment: "sparkles" } }
}

struct SearchHit: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var text: String
    var reason: String?
    var symbol: String
    var label: String
}

struct Reminder: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var due: Date?
    var doneAt: Date?
}

/// Everything one person owns. The engine hands this out whole; screens read it and ask the engine to change it.
struct Store: Codable, Equatable {
    var goals: [Goal] = []
    var plan: [PlanItem] = []
    var routines: [Routine] = []
    var journal: [JournalEntry] = []
    var memories: [Memory] = []
    var reminders: [Reminder] = []
}

/// What one quick capture became, so the person can see it and change it.
enum CaptureOutcome: Equatable {
    case task(PlanItem), reminder(Reminder), journal(JournalEntry), memory(Memory)

    var label: String {
        switch self {
        case .task: "Added to your day"
        case .reminder: "Reminder set"
        case .journal: "Saved to your journal"
        case .memory: "Saved to memory"
        }
    }
    var symbol: String {
        switch self {
        case .task: "checklist"
        case .reminder: "bell"
        case .journal: "book"
        case .memory: "brain.head.profile"
        }
    }
}

struct Suggestion: Equatable {
    var title: String
    var minutes: Int
    var reason: String
    var planItemID: UUID?
    var goalID: UUID?
    var stepID: UUID?
}

struct PlanChange: Equatable {
    var keep: [PlanItem]
    var moveToTomorrow: [PlanItem]
}

struct DayClose: Equatable {
    var done: Int
    var carried: [PlanItem]
    var summary: String
    var tomorrowNote: String
}

struct WeeklyReview: Equatable {
    var planned: Int
    var done: Int
    var stepsDone: Int
    var entries: Int
    var routineDays: Int
    var change: String
}
