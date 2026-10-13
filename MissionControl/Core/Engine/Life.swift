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

    // MARK: Settings. The phone says where the person is.

    private var settingsService: SettingsService?
    func attachSettings(_ service: SettingsService?) { settingsService = service }

    /// Tell the engine the phone's time zone, so every "today" is today where you are. Quiet: a failure here must not block anything.
    func syncTimeZone() async { _ = try? await settingsService?.matchTimeZone() }

    // MARK: Goals. The Life Engine's, so a goal the assistant creates is the goal the screen shows.

    private(set) var goals: [Wire.Goal] = []
    private var goalService: GoalsService?
    /// Steps with a change in flight.
    private(set) var busySteps: Set<String> = []
    var goalsAvailable: Bool { goalService != nil }

    func attachGoals(_ service: GoalsService?) { goalService = service }

    func loadGoals() async {
        guard let service = goalService else { return }
        do { goals = try await service.list() } catch { self.error = Self.goalMessage(error) }
    }

    func setStepDone(_ step: Wire.Step, done: Bool) async {
        guard let service = goalService, !busySteps.contains(step.id) else { return }
        busySteps.insert(step.id); defer { busySteps.remove(step.id) }
        do { _ = try await service.setStep(step, done: done); error = nil } catch { self.error = Self.goalMessage(error) }
        await loadGoals()
    }

    func addGoalStep(goal: String, title: String, minutes: Int = 15) async {
        guard let service = goalService else { return }
        do { _ = try await service.addStep(goal: goal, title: title, minutes: minutes); error = nil } catch { self.error = Self.goalMessage(error) }
        await loadGoals()
    }

    func archiveGoal(_ goal: Wire.Goal) async {
        guard let service = goalService else { return }
        do { try await service.archive(goal); error = nil } catch { self.error = Self.goalMessage(error) }
        await loadGoals()
    }

    private static func goalMessage(_ e: Error) -> String {
        switch e as? LifeError {
        case .unauthorized: "Please sign in again."
        case .notProvisioned: "Your workspace isn't ready for goals yet."
        case .engine(let code, let message): code == "conflict" ? "That changed elsewhere. It has been refreshed." : message
        case .retry: "You're offline, or the service is busy. Try again in a moment."
        default: "Something went wrong with goals."
        }
    }

    // MARK: Routines. The Life Engine's, with today's count; the tracker reads history on demand.

    private(set) var routines: [Wire.RoutineStatus] = []
    private var routineService: RoutinesService?
    /// Routines with a change in flight; a second tap waits for the first.
    private(set) var busyRoutines: Set<String> = []
    var routinesAvailable: Bool { routineService != nil }

    func attachRoutines(_ service: RoutinesService?) { routineService = service }

    func loadRoutines() async {
        guard let service = routineService else { return }
        do { routines = try await service.status() } catch { self.error = Self.routineMessage(error) }
    }

    /// Adds one (or takes one back with `-1`) and shows the new count at once from the engine's answer.
    func logRoutine(_ id: String, delta: Int = 1, short: Bool = false) async {
        guard let service = routineService, !busyRoutines.contains(id) else { return }
        busyRoutines.insert(id); defer { busyRoutines.remove(id) }
        do {
            let updated = try await service.log(id, delta: delta, short: short)
            if let i = routines.firstIndex(where: { $0.id == id }) { routines[i] = updated }
            error = nil
        } catch { self.error = Self.routineMessage(error); await loadRoutines() }
    }

    func history(for id: String, days: Int = 30) async -> Wire.RoutineHistory? {
        guard let service = routineService else { return nil }
        do { return try await service.history(id, days: days) } catch { self.error = Self.routineMessage(error); return nil }
    }

    @discardableResult
    func addRoutine(title: String, targetPerDay: Int, cues: [String], weekdays: [Int], shortTitle: String, minutes: Int, shortMinutes: Int) async -> Bool {
        guard let service = routineService else { error = "Routines need your workspace, and it isn't reachable right now."; return false }
        do {
            _ = try await service.create(title: title, targetPerDay: targetPerDay, cues: cues, weekdays: weekdays,
                                         shortTitle: shortTitle.isEmpty ? "A smaller version" : shortTitle, minutes: minutes, shortMinutes: shortMinutes)
            error = nil; await loadRoutines(); return true
        } catch { self.error = Self.routineMessage(error); return false }
    }

    func deleteRoutine(_ r: Wire.Routine) async {
        guard let service = routineService else { return }
        do { try await service.delete(r); error = nil } catch { self.error = Self.routineMessage(error) }
        await loadRoutines()
    }

    private static func routineMessage(_ e: Error) -> String {
        switch e as? LifeError {
        case .unauthorized: "Please sign in again."
        case .notProvisioned: "Your workspace isn't ready for routines yet."
        case .engine(_, let message): message
        case .retry: "You're offline, or the service is busy. Try again in a moment."
        default: "Something went wrong with routines."
        }
    }

    // MARK: Reminders. Always the Life Engine, through the same operations the agent calls; never a local invention.

    private(set) var reminders: [Wire.Reminder] = []
    /// Today's cues, one per occurrence; what the Today screen shows and counts.
    private(set) var agenda: [Wire.AgendaItem] = []
    private var reminderService: RemindersService?
    /// False when there is no workspace to talk to (developer mode, or no router configured).
    var remindersAvailable: Bool { reminderService != nil }

    func attachReminders(_ service: RemindersService?) { reminderService = service }

    func loadReminders() async {
        guard let service = reminderService else { return }
        do {
            reminders = try await service.list().filter { $0.isShown() }
            agenda = try await service.agenda()
            await Notifier.sync(reminders)
        } catch { self.error = Self.reminderMessage(error) }
    }

    @discardableResult
    func addReminder(title: String, notes: String? = nil, due: Date?, recurrence: Wire.Recurrence? = nil) async -> Bool {
        await reminderAction { try await $0.create(title: title, notes: notes, due: due, recurrence: recurrence) }
    }
    /// Reminders with a change in flight. A second tap on the same one waits, so it cannot collide with its own first.
    private(set) var busyReminders: Set<String> = []

    /// "Got it" for one occurrence.
    func ackCue(_ item: Wire.AgendaItem) async {
        guard let service = reminderService, !busyReminders.contains(item.reminder.id) else { return }
        busyReminders.insert(item.reminder.id); defer { busyReminders.remove(item.reminder.id) }
        do { _ = try await service.ack(item); error = nil } catch { self.error = Self.reminderMessage(error) }
        await loadReminders()
    }
    func snoozeReminder(_ r: Wire.Reminder, until: Date) async {
        guard !busyReminders.contains(r.id) else { return }
        busyReminders.insert(r.id); defer { busyReminders.remove(r.id) }
        await reminderAction { try await $0.snooze(r, until: until) }
    }
    func deleteReminder(_ r: Wire.Reminder) async {
        guard !busyReminders.contains(r.id) else { return }
        busyReminders.insert(r.id); defer { busyReminders.remove(r.id) }
        await reminderAction { try await $0.delete(r) }
    }

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
        // Reminders never come through here: the capture sheet reviews them and saves them with addReminder, the Life Engine's
        // own operation. Everything else is still kept on this phone.
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
