import Foundation

/// Partitions explicit times by the user's local day. Untimed work has no deadline.
struct DayTaskSchedule {
    let earlier: [MissionTask]
    let remainingToday: [MissionTask]
    let later: [MissionTask]
    let anytime: [MissionTask]
    let minuteStart: Date
    let minuteEnd: Date

    init(tasks: [MissionTask], now: Date, calendar: Calendar = .current) {
        let start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        minuteStart = start
        minuteEnd = calendar.date(byAdding: .minute, value: 1, to: start) ?? now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let open = tasks.filter { !$0.isCompleted }
        let timed = open.enumerated().filter { $0.element.scheduledAt != nil }.sorted {
            let left = $0.element.scheduledAt!
            let right = $1.element.scheduledAt!
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        earlier = timed.filter { $0.scheduledAt! < start }
        remainingToday = timed.filter { $0.scheduledAt! >= start && $0.scheduledAt! < tomorrow }
        later = timed.filter { $0.scheduledAt! >= tomorrow }
        anytime = open.filter { $0.scheduledAt == nil }
    }
}
