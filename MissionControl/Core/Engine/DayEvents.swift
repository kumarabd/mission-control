import EventKit
import Foundation

struct DayEvent: Identifiable, Equatable {
    var id: String
    var title: String
    var start: Date
    var minutes: Int
}

/// Today's calendar appointments, read-only, so the plan sits next to what is already fixed.
enum DayEvents {
    static func today() async -> [DayEvent] {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToEvents()) == true else { return [] }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .filter { !$0.isAllDay }
            .map { DayEvent(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Event", start: $0.startDate,
                            minutes: max(5, Int($0.endDate.timeIntervalSince($0.startDate) / 60))) }
            .sorted { $0.start < $1.start }
    }
}
