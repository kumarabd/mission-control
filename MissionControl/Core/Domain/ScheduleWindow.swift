import Foundation

/// Where the Now rule falls among the schedule's rows and how tall its window is. Pure, so the check can pin both
/// down; the scrolling and the motion are the view's business.
enum ScheduleWindow {
    /// The row id of the Now rule. View-built ids are prefixed ("e:", "t:"), so this cannot collide with one.
    static let nowID = "now"
    /// The rows the window shows before it starts scrolling inside itself.
    static let visibleRows = 4

    struct Placement: Identifiable, Equatable {
        let id: String
        let at: Date
        let isNow: Bool
    }

    /// The timed items in time order, ties broken by id, with the Now rule among them: before the first item still to
    /// come, or last when everything is already past.
    static func placements(items: [(id: String, at: Date)], now: Date) -> [Placement] {
        let sorted = items.sorted { $0.at == $1.at ? $0.id < $1.id : $0.at < $1.at }
        var out = sorted.map { Placement(id: $0.id, at: $0.at, isNow: false) }
        out.insert(Placement(id: nowID, at: now, isNow: true), at: out.firstIndex { $0.at > now } ?? out.count)
        return out
    }

    /// Four rows of room, or as many as there are — a one-item day must not reserve four rows of hole. Rows are
    /// taller at accessibility text sizes, where the time moves above the title.
    static func height(rowCount: Int, isAccessibilitySize: Bool) -> CGFloat {
        let row: CGFloat = isAccessibilitySize ? 88 : 60
        return row * CGFloat(min(max(rowCount, 1), visibleRows))
    }

    /// True once the person has scrolled the window off the Now rule, which is when it offers a way back.
    static func isAway(centered: String?) -> Bool {
        centered != nil && centered != nowID
    }
}
