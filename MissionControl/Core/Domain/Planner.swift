import Foundation

/// The decisions behind the "moments": what a capture becomes, what fits in 20 minutes, how to shrink a day.
/// Pure and rule-based so the same rules can be checked without a server; the engine may later replace them with the service's own.
enum Planner {
    static func startOfDay(_ d: Date, _ cal: Calendar = .current) -> Date { cal.startOfDay(for: d) }

    // MARK: Capture

    static func capture(_ raw: String, now: Date = Date(), cal: Calendar = .current) -> CaptureOutcome {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = text.lowercased()
        let when = detectDate(in: text, now: now, cal: cal)
        if l.hasPrefix("remind") || l.contains("don't forget") || l.contains("dont forget") || l.contains("deadline") {
            let title = stripped(without(when?.range, in: text), prefixes: ["remind me to ", "remind me ", "don't forget to ", "dont forget to "])
            return .reminder(Reminder(title: title.isEmpty ? text : title, due: when?.date))
        }
        if l.hasPrefix("decided") || l.hasPrefix("i decided") || l.hasPrefix("remember") || l.hasPrefix("learned") || l.hasPrefix("i learned") {
            let kind: MemoryKind = l.contains("decid") ? .decision : .note
            let parts = text.components(separatedBy: " because ")
            return .memory(Memory(date: now, text: parts[0], reason: parts.count > 1 ? parts[1...].joined(separator: " because ") : nil, kind: kind))
        }
        if ["today i", "i felt", "i feel", "grateful", "i'm tired", "i am tired", "journal"].contains(where: l.contains) {
            return .journal(JournalEntry(date: now, text: text))
        }
        // Something with a time on it ("call Mum at 5pm") is a reminder whether or not it says so.
        if let when {
            let title = stripped(without(when.range, in: text), prefixes: ["to "])
            return .reminder(Reminder(title: title.isEmpty ? text : title, due: when.date))
        }
        return .task(PlanItem(title: text, minutes: 25, day: startOfDay(now, cal)))
    }

    /// The first date or time the person wrote, using the system's own detector (so "tomorrow at 5pm", "in 2 hours",
    /// "next Friday" and "March 3" all work in the device's language). A day with no time means 09:00; a bare time that has
    /// already passed today means tomorrow.
    static func detectDate(in text: String, now: Date = Date(), cal: Calendar = .current) -> (date: Date, range: Range<String.Index>)? {
        // The system detector does not read durations, so "in 20 minutes" and "in an hour" are read here.
        if let m = text.range(of: #"\bin\s+(half an?|an?|\d+)\s*(minutes?|mins?|hours?|hrs?)\b"#, options: [.regularExpression, .caseInsensitive]) {
            let words = text[m].lowercased().split(separator: " ").dropFirst().map(String.init)
            let unitIsHours = words.last.map { $0.hasPrefix("h") } ?? false
            let count: Double = words.first == "half" ? 0.5 : (Double(words.first ?? "") ?? 1)
            return (now.addingTimeInterval(count * (unitIsHours ? 3600 : 60)), m)
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
              let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              var date = match.date, let range = Range(match.range, in: text) else { return nil }
        let phrase = text[range].lowercased()
        let hasTime = phrase.range(of: #"\d\s*(am|pm|a\.m\.|p\.m\.)|\d:\d\d|\bnoon\b|\bmidnight\b|\bat \d|o'clock|\bin \d+\s*(minutes?|mins?|hours?|hrs?)\b|\bhalf an hour\b|\ban hour\b|\btonight\b"#, options: .regularExpression) != nil
        if !hasTime, let nine = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date) { date = nine }
        let timeOnly = phrase.range(of: #"^(at\s+)?\d{1,2}(:\d{2})?\s*(am|pm)?$"#, options: .regularExpression) != nil
        if timeOnly, date <= now { date = cal.date(byAdding: .day, value: 1, to: date) ?? date }
        return (date, range)
    }

    /// The text with the date phrase taken out and the leftover connecting word ("at", "on", ...) tidied away.
    private static func without(_ range: Range<String.Index>?, in text: String) -> String {
        guard let range else { return text }
        var t = text; t.removeSubrange(range)
        t = t.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for tail in [" at", " on", " by", " in", " for", " around", " this"] where t.lowercased().hasSuffix(tail) { t = String(t.dropLast(tail.count)) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripped(_ text: String, prefixes: [String]) -> String {
        let l = text.lowercased()
        for p in prefixes where l.hasPrefix(p) { return String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespaces) }
        return text
    }

    // MARK: "I have 20 minutes"

    /// Priorities first, then the next step of a goal, then anything else that fits; within a tier the longest one that fits
    /// so the time is used. Nil when nothing fits.
    static func suggestNext(minutes: Int, store: Store, today: Date, cal: Calendar = .current) -> Suggestion? {
        let day = startOfDay(today, cal)
        let open = store.plan.filter { $0.day == day && !$0.isDone && $0.kind != .event && $0.minutes <= minutes }
        func pick(_ items: [PlanItem]) -> Suggestion? {
            guard let p = items.max(by: { $0.minutes < $1.minutes }) else { return nil }
            return Suggestion(title: p.title, minutes: p.minutes, reason: p.isPriority ? "One of today's priorities" : "Fits your time and is already on today's list", planItemID: p.id)
        }
        if let s = pick(open.filter(\.isPriority)) { return s }
        let steps = store.goals.compactMap { g in g.nextStep.map { (g, $0) } }.filter { $0.1.minutes <= minutes }
        if let (g, s) = steps.max(by: { $0.1.minutes < $1.1.minutes }) {
            return Suggestion(title: s.title, minutes: s.minutes, reason: "Next step toward \u{201C}\(g.title)\u{201D}", goalID: g.id, stepID: s.id)
        }
        return pick(open)
    }

    // MARK: "My day changed"

    /// Keep what is fixed (events, done work), then fill the time left with priorities first, shortest first within a tier.
    /// Everything that does not fit moves to tomorrow instead of being dropped.
    static func replan(items: [PlanItem], minutesLeft: Int) -> PlanChange {
        var budget = minutesLeft
        var keep = items.filter { $0.kind == .event || $0.isDone }
        var move: [PlanItem] = []
        let open = items.filter { $0.kind != .event && !$0.isDone }
            .sorted { ($0.isPriority ? 0 : 1, $0.minutes) < ($1.isPriority ? 0 : 1, $1.minutes) }
        for item in open {
            if item.minutes <= budget { keep.append(item); budget -= item.minutes } else { move.append(item) }
        }
        return PlanChange(keep: keep, moveToTomorrow: move)
    }

    // MARK: "Close the day"

    static func closeDay(items: [PlanItem], reflection: String?) -> DayClose {
        let done = items.filter(\.isDone).count
        let carried = items.filter { !$0.isDone && $0.kind != .event }
        let summary: String
        switch (done, carried.count) {
        case (0, 0): summary = "A quiet day. Nothing was planned."
        case (_, 0): summary = "You finished all \(done). Well done."
        case (0, _): summary = "Nothing got done today, and that's allowed. Tomorrow starts clean."
        default: summary = "You finished \(done) and \(carried.count) carry over."
        }
        let note: String
        if carried.count > 3 { note = "Tomorrow, choose only your top three. The rest can wait." }
        else if let p = carried.first(where: \.isPriority) { note = "Start tomorrow with \u{201C}\(p.title)\u{201D}." }
        else if done > 0 { note = "Repeat what worked today." }
        else { note = "Pick one small thing to start with." }
        return DayClose(done: done, carried: carried, summary: summary, tomorrowNote: note)
    }

    // MARK: "What should I change next week?"

    static func weeklyReview(store: Store, now: Date, cal: Calendar = .current) -> WeeklyReview {
        let end = startOfDay(now, cal)
        let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
        let week = store.plan.filter { $0.day >= start && $0.day <= end && $0.kind != .event }
        let done = week.filter(\.isDone).count
        let steps = store.goals.flatMap(\.steps).filter { ($0.doneAt ?? .distantPast) >= start }.count
        let entries = store.journal.filter { $0.date >= start }.count
        let routineDays = store.routines.reduce(0) { $0 + $1.doneOn.filter { $0 >= start && $0 <= end }.count }
        let change: String
        if week.isEmpty { change = "Nothing was planned this week. Start by choosing three things for Monday." }
        else if Double(done) / Double(week.count) < 0.5 { change = "You finished \(done) of \(week.count). Plan fewer, smaller things next week." }
        else if entries == 0 { change = "Your plan worked. Add a two-line journal entry at the end of the day to see why." }
        else { change = "Your plan worked. Keep the same shape next week." }
        return WeeklyReview(planned: week.count, done: done, stepsDone: steps, entries: entries, routineDays: routineDays, change: change)
    }

    // MARK: "I keep putting this off"

    /// A smaller first step matched to what is in the way.
    static func smallerStep(for goal: Goal, obstacle: Obstacle) -> Step {
        let next = goal.nextStep?.title ?? goal.title
        switch obstacle {
        case .tooBig: return Step(title: "Spend 5 minutes on the first piece of \u{201C}\(next)\u{201D}", minutes: 5)
        case .unclear: return Step(title: "Write down what done looks like for \u{201C}\(goal.title)\u{201D}", minutes: 10)
        case .noTime: return Step(title: "Open \u{201C}\(next)\u{201D} and do two minutes", minutes: 2)
        case .noEnergy: return Step(title: "Set up everything you need for \u{201C}\(next)\u{201D}", minutes: 5)
        }
    }
}

enum Obstacle: String, CaseIterable, Identifiable {
    case tooBig, unclear, noTime, noEnergy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tooBig: "It feels too big"
        case .unclear: "I'm not sure what to do"
        case .noTime: "I never have time"
        case .noEnergy: "I don't feel like it"
        }
    }
}
