import Foundation
import Observation

/// What the screens read: the current snapshot plus the actions. Owned per signed-in person, rebuilt on sign-out.
@MainActor @Observable
final class Life {
    private(set) var store = Store()
    private(set) var loaded = false
    var error: String?
    private let engine: LifeEngine

    init(engine: LifeEngine) { self.engine = engine }

    var today: Date { Planner.startOfDay(Date()) }
    var todayItems: [PlanItem] {
        store.plan.filter { $0.day == today }.sorted { ($0.start ?? .distantFuture, $0.title) < ($1.start ?? .distantFuture, $1.title) }
    }

    // MARK: Reminders. Always the Life Engine, through the same operations the agent calls; never a local invention.

    private(set) var reminders: [Wire.Reminder] = []
    private var reminderService: RemindersService?
    /// False when there is no workspace to talk to (developer mode, or no router configured).
    var remindersAvailable: Bool { reminderService != nil }

    func attachReminders(_ service: RemindersService?) { reminderService = service }

    func loadReminders() async {
        guard let service = reminderService else { return }
        do { reminders = try await service.pending(); await Notifier.sync(reminders) } catch { self.error = Self.reminderMessage(error) }
    }

    @discardableResult
    func addReminder(title: String, notes: String? = nil, due: Date?, recurrence: Wire.Recurrence? = nil) async -> Bool {
        await reminderAction { try await $0.create(title: title, notes: notes, due: due, recurrence: recurrence) }
    }
    func completeReminder(_ r: Wire.Reminder) async { await reminderAction { try await $0.complete(r) } }
    func snoozeReminder(_ r: Wire.Reminder, until: Date) async { await reminderAction { try await $0.snooze(r, until: until) } }
    func deleteReminder(_ r: Wire.Reminder) async { await reminderAction { try await $0.delete(r) } }

    /// Runs a change, then re-reads the list so the screen shows the server's truth (including a stale-version refusal).
    @discardableResult
    private func reminderAction<T>(_ body: (RemindersService) async throws -> T) async -> Bool {
        guard let service = reminderService else { error = "Reminders need your workspace, and it isn't reachable right now."; return false }
        var ok = true
        do { _ = try await body(service); error = nil } catch { self.error = Self.reminderMessage(error); ok = false }
        await loadReminders()
        return ok
    }

    private static func reminderMessage(_ e: Error) -> String {
        switch e as? LifeError {
        case .unauthorized: "Please sign in again."
        case .notProvisioned: "Your workspace isn't ready for reminders yet."
        case .engine(let code, let message): code == "conflict" ? "That reminder changed elsewhere. It has been refreshed." : message
        case .retry: "You're offline, or the service is busy. Try again in a moment."
        default: "Something went wrong with reminders."
        }
    }

    func load() async { await run { try await self.engine.snapshot() } }

    func addGoal(title: String, why: String, weeklyTarget: Int) async { await run { try await self.engine.addGoal(title: title, why: why, weeklyTarget: weeklyTarget) } }
    func deleteGoal(_ id: UUID) async { await run { try await self.engine.deleteGoal(id) } }
    func addStep(goal: UUID, title: String, minutes: Int) async { await run { try await self.engine.addStep(goal: goal, title: title, minutes: minutes) } }
    func setStep(goal: UUID, step: UUID, done: Bool) async { await run { try await self.engine.setStep(goal: goal, step: step, done: done) } }
    func shrink(goal: UUID, obstacle: Obstacle) async { await run { try await self.engine.shrink(goal: goal, obstacle: obstacle) } }
    func addPlanItem(_ item: PlanItem) async { await run { try await self.engine.addPlanItem(item) } }
    func setPlanItem(_ id: UUID, done: Bool) async { await run { try await self.engine.setPlanItem(id, done: done) } }
    func setPriority(_ id: UUID, _ on: Bool) async { await run { try await self.engine.setPriority(id, on) } }
    func deletePlanItem(_ id: UUID) async { await run { try await self.engine.deletePlanItem(id) } }
    func apply(_ change: PlanChange) async { await run { try await self.engine.apply(change) } }
    func addRoutine(_ r: Routine) async { await run { try await self.engine.addRoutine(r) } }
    func setRoutine(_ id: UUID, done: Bool) async { await run { try await self.engine.setRoutine(id, day: self.today, done: done) } }
    func addJournal(text: String, goals: [UUID] = [], tomorrow: String? = nil) async { await run { try await self.engine.addJournal(text: text, goals: goals, tomorrow: tomorrow) } }
    func addMemory(_ m: Memory) async { await run { try await self.engine.addMemory(m) } }

    func capture(_ text: String) async -> CaptureOutcome? {
        // A reminder is made by the Life Engine like any other: the words are read here, but creating it is the same
        // operation the agent calls, so there is one way for a reminder to exist.
        if case .reminder(let draft) = Planner.capture(text) {
            return await addReminder(title: draft.title, due: draft.due) ? .reminder(draft) : nil
        }
        do { let (o, s) = try await engine.capture(text); store = s; return o } catch { self.error = Self.message(error); return nil }
    }

    func closeDay(reflection: String?) async -> DayClose? {
        do { let (c, s) = try await engine.closeDay(today, reflection: reflection); store = s; return c } catch { self.error = Self.message(error); return nil }
    }

    func suggestion(minutes: Int) -> Suggestion? { Planner.suggestNext(minutes: minutes, store: store, today: Date()) }
    func replan(minutesLeft: Int) -> PlanChange { Planner.replan(items: todayItems, minutesLeft: minutesLeft) }
    func weeklyReview() -> WeeklyReview { Planner.weeklyReview(store: store, now: Date()) }

    /// Past memories and journal entries matching every word typed, newest first.
    func search(_ query: String) -> [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let hits = store.memories.map { SearchHit(id: $0.id, date: $0.date, text: $0.text, reason: $0.reason, symbol: $0.kind.symbol, label: $0.kind.label) }
            + store.journal.map { SearchHit(id: $0.id, date: $0.date, text: $0.text, reason: $0.tomorrow, symbol: "book", label: "Journal") }
        let sorted = hits.sorted { $0.date > $1.date }
        guard !q.isEmpty else { return sorted }
        let words = q.split(separator: " ").map(String.init)
        return sorted.filter { h in words.allSatisfy { (h.text + " " + (h.reason ?? "")).lowercased().contains($0) } }
    }

    private func run(_ op: @escaping () async throws -> Store) async {
        do { store = try await op(); loaded = true; error = nil } catch { self.error = Self.message(error) }
    }

    private static func message(_ e: Error) -> String { "Couldn't save that. \(e.localizedDescription)" }
}
