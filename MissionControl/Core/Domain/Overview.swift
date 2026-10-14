import Foundation

/// The short description at the top of a routine or goal, written from its own record. It is composed here, not by a model:
/// every number in it comes straight from the data, so it can never state something the record does not. (Apple's on-device
/// model was tried for this and, given the facts, invented a streak and refused a weight goal; told to keep the facts, it
/// changed nothing.) The text is markdown; the key facts are bold.
enum Overview {
    /// "9:00 AM, 1:00 PM and 5:00 PM"
    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        default: items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }

    static func routine(_ r: Wire.Routine, count: Int, target: Int, history: Wire.RoutineHistory?, clock: (String) -> String, days: String) -> String {
        let times = target == 1 ? "once" : "\(target) times"
        var first = "**\(times) a day**, \(days.lowercased())"
        if !r.cues.isEmpty { first += ", with a nudge at \(list(r.cues.map(clock)))" }
        first += "."
        var lines = [first]
        if let h = history, h.last7.scheduled > 0 {
            var done = "Done on **\(h.last7.done) of the last \(h.last7.scheduled) days**"
            if h.last30.scheduled > h.last7.scheduled { done += " and \(h.last30.done) of the last \(h.last30.scheduled)" }
            done += "."
            if h.bestStreak > 1 { done += " Best run: \(h.bestStreak) days." }
            lines.append(done)
        }
        return lines.joined(separator: "\n\n")
    }

    /// Basic review for legacy goals: linked routine consistency and existing one-off steps.
    static func goal(_ g: Wire.Goal) -> String {
        var lines: [String] = []
        if !g.why.isEmpty { lines.append(g.why) }
        let routines = g.routineIds ?? []
        if let c = g.consistency, c.last30.scheduled > 0 {
            lines.append("**\(c.last30.done) of \(c.last30.scheduled) routine days** kept in the last 30 days, \(c.last7.done) of \(c.last7.scheduled) this week.")
        } else if !routines.isEmpty {
            lines.append("Its \(routines.count == 1 ? "routine has" : "routines have") only just started.")
        } else {
            lines.append("No routines serve it yet. Ask your assistant to set some up.")
        }
        if g.progress.total > 0 { lines.append("**\(g.progress.done) of \(g.progress.total)** one-off steps done.") }
        return lines.joined(separator: "\n\n")
    }
}
