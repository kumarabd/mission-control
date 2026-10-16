import Foundation

/// Which shelf of the Reminders list a record belongs on, and the order inside it: what is overdue first, then what
/// is coming, then what has no time, with finished ones last. Pure, so the check can pin the rule down.
enum ReminderSections {
    enum Group: String, CaseIterable, Identifiable {
        case due = "Due", upcoming = "Upcoming", undated = "No time set", done = "Done"
        var id: Self { self }
    }

    /// The instant the person will actually be reminded at: a snooze replaces the due time.
    static func effectiveDate(_ r: Wire.Reminder) -> Date? { r.snoozedUntil ?? r.dueAt }

    static func group(_ r: Wire.Reminder, now: Date) -> Group {
        if r.isDone { return .done }
        guard let at = effectiveDate(r) else { return .undated }
        return at <= now ? .due : .upcoming
    }

    /// The shelves in reading order, empty ones left out. Finished records older than a day are dropped, the same
    /// rule every other reminder surface reads by (`isShown`).
    static func sections(_ items: [Wire.Reminder], now: Date = Date()) -> [(group: Group, items: [Wire.Reminder])] {
        let shown = items.filter { $0.isShown(now: now) }
        return Group.allCases.compactMap { group -> (group: Group, items: [Wire.Reminder])? in
            let shelf = shown.filter { self.group($0, now: now) == group }
            guard !shelf.isEmpty else { return nil }
            switch group {
            case .due, .upcoming: return (group, shelf.sorted(by: earlier))
            case .undated: return (group, shelf)                        // the order the engine sent
            case .done: return (group, shelf.sorted(by: moreRecentlyDone))
            }
        }
    }

    private static func earlier(_ a: Wire.Reminder, _ b: Wire.Reminder) -> Bool {
        let (x, y) = (effectiveDate(a) ?? .distantFuture, effectiveDate(b) ?? .distantFuture)
        return x == y ? a.id < b.id : x < y
    }

    private static func moreRecentlyDone(_ a: Wire.Reminder, _ b: Wire.Reminder) -> Bool {
        let (x, y) = (a.completedAt ?? a.lastCompletedAt ?? a.updatedAt, b.completedAt ?? b.lastCompletedAt ?? b.updatedAt)
        return x == y ? a.id < b.id : x > y
    }
}
