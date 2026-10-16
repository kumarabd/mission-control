import Foundation

@main
struct ScheduleWindowChecks {
    static func main() {
        let now = ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z")!
        func at(_ h: Int) -> Date { now.addingTimeInterval(Double(h) * 3600) }

        // Chronological, with a tie broken by id so the order never flickers between renders.
        let items = [(id: "t:b", at: at(2)), (id: "e:a", at: at(-2)), (id: "t:a", at: at(2))]
        let ordered = ScheduleWindow.placements(items: items, now: now)
        precondition(ordered.map(\.id) == ["e:a", ScheduleWindow.nowID, "t:a", "t:b"], "\(ordered.map(\.id))")

        // The Now rule sits before the first item still to come.
        precondition(ordered.first { $0.isNow }?.at == now)
        precondition(ordered.filter(\.isNow).count == 1)

        // Everything already past: Now goes last.
        let allPast = ScheduleWindow.placements(items: [(id: "e:a", at: at(-3)), (id: "e:b", at: at(-1))], now: now)
        precondition(allPast.map(\.id) == ["e:a", "e:b", ScheduleWindow.nowID])

        // Everything still to come: Now goes first.
        let allFuture = ScheduleWindow.placements(items: [(id: "e:a", at: at(1))], now: now)
        precondition(allFuture.map(\.id) == [ScheduleWindow.nowID, "e:a"])

        // An empty day still has a Now to centre on.
        let empty = ScheduleWindow.placements(items: [], now: now)
        precondition(empty.map(\.id) == [ScheduleWindow.nowID] && empty[0].isNow)

        // An item exactly at this instant counts as past, so Now does not sit above something already due.
        let exactly = ScheduleWindow.placements(items: [(id: "e:a", at: now)], now: now)
        precondition(exactly.map(\.id) == ["e:a", ScheduleWindow.nowID])

        // View-built ids are prefixed, so the Now row can never collide with one. (Guards the ForEach identity.)
        precondition(!ScheduleWindow.nowID.contains(":"))

        // The window is four rows tall at most, never taller than the rows that exist.
        precondition(ScheduleWindow.height(rowCount: 9, isAccessibilitySize: false) == 240)
        precondition(ScheduleWindow.height(rowCount: 4, isAccessibilitySize: false) == 240)
        precondition(ScheduleWindow.height(rowCount: 3, isAccessibilitySize: false) == 180)
        precondition(ScheduleWindow.height(rowCount: 1, isAccessibilitySize: false) == 60)
        precondition(ScheduleWindow.height(rowCount: 0, isAccessibilitySize: false) == 60, "never a hole where a row should be")
        // Rows are taller when the time stacks above the title.
        precondition(ScheduleWindow.height(rowCount: 4, isAccessibilitySize: true) == 352)
        precondition(ScheduleWindow.height(rowCount: 2, isAccessibilitySize: true) == 176)

        // Back to now appears only once the person has moved the window off it.
        precondition(ScheduleWindow.isAway(centered: nil) == false)
        precondition(ScheduleWindow.isAway(centered: ScheduleWindow.nowID) == false)
        precondition(ScheduleWindow.isAway(centered: "e:a"))

        print("ScheduleWindowChecks passed")
    }
}
