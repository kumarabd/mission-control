import Foundation

/// The operations the app needs from the server-side productivity service. Every call returns the new snapshot so the
/// screens never guess at what changed. `LocalEngine` implements it on this phone until the router's service exists;
/// the remote implementation will map each call to `POST <router>/missioncontrol/api/v1/operations/<name>`.
protocol LifeEngine: Sendable {
    func snapshot() async throws -> Store
    func addGoal(title: String, why: String, weeklyTarget: Int) async throws -> Store
    func deleteGoal(_ id: UUID) async throws -> Store
    func addStep(goal: UUID, title: String, minutes: Int) async throws -> Store
    func setStep(goal: UUID, step: UUID, done: Bool) async throws -> Store
    func shrink(goal: UUID, obstacle: Obstacle) async throws -> Store
    func addPlanItem(_ item: PlanItem) async throws -> Store
    func setPlanItem(_ id: UUID, done: Bool) async throws -> Store
    func setPriority(_ id: UUID, _ on: Bool) async throws -> Store
    func deletePlanItem(_ id: UUID) async throws -> Store
    func apply(_ change: PlanChange) async throws -> Store
    func closeDay(_ day: Date, reflection: String?) async throws -> (DayClose, Store)
    func capture(_ text: String) async throws -> (CaptureOutcome, Store)
    func addRoutine(_ routine: Routine) async throws -> Store
    func setRoutine(_ id: UUID, day: Date, done: Bool) async throws -> Store
    func addJournal(text: String, goals: [UUID], tomorrow: String?) async throws -> Store
    func addMemory(_ memory: Memory) async throws -> Store
    func setReminder(_ id: UUID, done: Bool) async throws -> Store
}

/// On-device engine: one JSON file per person, the rules in `Planner`. Stands in for the service until it exists.
actor LocalEngine: LifeEngine {
    private var store: Store
    private let url: URL

    init(owner: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("missioncontrol", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("\(owner).json")
        store = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Store.self, from: $0) } ?? Store()
    }

    private func save() throws -> Store {
        try JSONEncoder().encode(store).write(to: url, options: .atomic)
        return store
    }

    func snapshot() async throws -> Store { store }

    func addGoal(title: String, why: String, weeklyTarget: Int) async throws -> Store {
        // ponytail: fixed three-step starter; the service will break the goal down from its text. Add steps by hand meanwhile.
        let steps = [Step(title: "Write down what done looks like", minutes: 10),
                     Step(title: "Do a first 25-minute session", minutes: 25),
                     Step(title: "Review what you learned and plan the next step", minutes: 10)]
        store.goals.append(Goal(title: title, why: why, steps: steps, weeklyTarget: weeklyTarget))
        return try save()
    }

    func deleteGoal(_ id: UUID) async throws -> Store { store.goals.removeAll { $0.id == id }; return try save() }

    func addStep(goal: UUID, title: String, minutes: Int) async throws -> Store {
        mutateGoal(goal) { $0.steps.append(Step(title: title, minutes: minutes)) }
        return try save()
    }

    func setStep(goal: UUID, step: UUID, done: Bool) async throws -> Store {
        mutateGoal(goal) { g in
            if let i = g.steps.firstIndex(where: { $0.id == step }) { g.steps[i].doneAt = done ? Date() : nil }
        }
        return try save()
    }

    func shrink(goal: UUID, obstacle: Obstacle) async throws -> Store {
        mutateGoal(goal) { g in
            let small = Planner.smallerStep(for: g, obstacle: obstacle)
            let at = g.steps.firstIndex { !$0.isDone } ?? g.steps.endIndex
            g.steps.insert(small, at: at)
        }
        return try save()
    }

    func addPlanItem(_ item: PlanItem) async throws -> Store { store.plan.append(item); return try save() }

    func setPlanItem(_ id: UUID, done: Bool) async throws -> Store {
        if let i = store.plan.firstIndex(where: { $0.id == id }) { store.plan[i].doneAt = done ? Date() : nil }
        return try save()
    }

    func setPriority(_ id: UUID, _ on: Bool) async throws -> Store {
        if let i = store.plan.firstIndex(where: { $0.id == id }) { store.plan[i].isPriority = on }
        return try save()
    }

    func deletePlanItem(_ id: UUID) async throws -> Store { store.plan.removeAll { $0.id == id }; return try save() }

    func apply(_ change: PlanChange) async throws -> Store {
        for item in change.moveToTomorrow { moveToTomorrow(item.id) }
        return try save()
    }

    func closeDay(_ day: Date, reflection: String?) async throws -> (DayClose, Store) {
        let items = store.plan.filter { $0.day == day }
        let close = Planner.closeDay(items: items, reflection: reflection)
        for item in close.carried { moveToTomorrow(item.id) }
        let text = reflection?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !text.isEmpty { store.journal.append(JournalEntry(text: text, tomorrow: close.tomorrowNote)) }
        return (close, try save())
    }

    func capture(_ text: String) async throws -> (CaptureOutcome, Store) {
        let outcome = Planner.capture(text)
        switch outcome {
        case .task(let t): store.plan.append(t)
        case .reminder(let r): store.reminders.append(r)
        case .journal(let j): store.journal.append(j)
        case .memory(let m): store.memories.append(m)
        }
        return (outcome, try save())
    }

    func addRoutine(_ routine: Routine) async throws -> Store { store.routines.append(routine); return try save() }

    func setRoutine(_ id: UUID, day: Date, done: Bool) async throws -> Store {
        if let i = store.routines.firstIndex(where: { $0.id == id }) {
            store.routines[i].doneOn.removeAll { $0 == day }
            if done { store.routines[i].doneOn.append(day) }
        }
        return try save()
    }

    func addJournal(text: String, goals: [UUID], tomorrow: String?) async throws -> Store {
        store.journal.append(JournalEntry(text: text, goalIDs: goals, tomorrow: tomorrow)); return try save()
    }

    func addMemory(_ memory: Memory) async throws -> Store { store.memories.append(memory); return try save() }

    func setReminder(_ id: UUID, done: Bool) async throws -> Store {
        if let i = store.reminders.firstIndex(where: { $0.id == id }) { store.reminders[i].doneAt = done ? Date() : nil }
        return try save()
    }

    private func mutateGoal(_ id: UUID, _ body: (inout Goal) -> Void) {
        if let i = store.goals.firstIndex(where: { $0.id == id }) { body(&store.goals[i]) }
    }

    private func moveToTomorrow(_ id: UUID) {
        guard let i = store.plan.firstIndex(where: { $0.id == id }) else { return }
        store.plan[i].day = Calendar.current.date(byAdding: .day, value: 1, to: store.plan[i].day) ?? store.plan[i].day
        store.plan[i].start = nil
    }
}
