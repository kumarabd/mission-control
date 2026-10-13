import Foundation

/// What a day is made of. The ring on Today has a segment for each kind that has something in it.
enum DayKind: String, CaseIterable, Identifiable {
    case tasks = "Tasks", cues = "Reminders"
    var id: Self { self }
}

struct DaySegment: Identifiable, Equatable {
    let kind: DayKind
    let done: Int
    let total: Int
    var id: DayKind { kind }
}

enum DayProgress {
    /// Tasks are the routines due today (in units of their daily target, capped at the target: drink water 3 times is three units) and the
    /// one-off tasks, one each. A reminder counts once it has fired: its job is that you were told. A kind with nothing today has no segment.
    static func segments(routines: [Wire.RoutineStatus], tasksDone: Int, tasksTotal: Int, cues: [Wire.AgendaItem]) -> [DaySegment] {
        let scheduled = routines.filter(\.scheduled)
        let all = [
            DaySegment(kind: .tasks, done: tasksDone + scheduled.reduce(0) { $0 + min($1.count, $1.target) }, total: tasksTotal + scheduled.reduce(0) { $0 + $1.target }),
            DaySegment(kind: .cues, done: cues.filter(\.hasFired).count, total: cues.count),
        ]
        return all.filter { $0.total > 0 }
    }
}
