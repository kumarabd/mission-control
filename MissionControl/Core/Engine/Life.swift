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

    // MARK: Plan. Today's tasks are the Life Engine's, the same items the assistant adds, moves and completes.

    private(set) var plan: Wire.PlanDay?
    /// The one thing to do next: a task, or the next step of a goal.
    private(set) var nextSuggestion: Wire.Suggestion?
    private var planService: PlanService?
    private(set) var busyTasks: Set<String> = []
    var planAvailable: Bool { planService != nil }
    /// Today's tasks and events in order.
    var tasks: [Wire.PlanItem] { (plan?.items ?? []).filter { $0.deletedAt == nil } }

    func attachPlan(_ service: PlanService?) { planService = service }

    func loadPlan() async {
        guard let service = planService else { return }
        do {
            plan = try await service.today()
            nextSuggestion = try await service.nextAction(minutes: 480)
        } catch { self.error = Self.planMessage(error) }
    }

    func completeTask(_ item: Wire.PlanItem, done: Bool) async {
        await taskAction(item.id) { try await $0.complete(item, done: done) }
    }
    func setTaskPriority(_ item: Wire.PlanItem, _ on: Bool) async { await taskAction(item.id) { _ = try await $0.setPriority(item, on) } }
    func deleteTask(_ item: Wire.PlanItem) async { await taskAction(item.id) { try await $0.delete(item) } }

    @discardableResult
    func addTask(title: String, minutes: Int, priority: Bool) async -> Bool {
        guard let service = planService else { error = "Tasks need your workspace, and it isn't reachable right now."; return false }
        do { _ = try await service.add(title: title, minutes: minutes, priority: priority); error = nil; await loadPlan(); return true }
        catch { self.error = Self.planMessage(error); return false }
    }

    /// Finishes what a suggestion points at: the task, or the goal step. A step is only ever finished here, never on the goal.
    func completeSuggestion(_ s: Wire.Suggestion) async {
        if let id = s.planItemId, let item = tasks.first(where: { $0.id == id }) {
            await completeTask(item, done: true)
        } else if let goal = s.goalId, let stepId = s.stepId, let step = goals.first(where: { $0.id == goal })?.steps.first(where: { $0.id == stepId }),
                  let service = goalService, !busySteps.contains(stepId) {
            busySteps.insert(stepId); defer { busySteps.remove(stepId) }
            do { try await service.completeStep(id: step.id, version: step.version); error = nil } catch { self.error = Self.goalMessage(error) }
            await loadGoals(); await loadPlan()
        }
    }
    private var busySteps: Set<String> = []

    /// The one thing to do with this many minutes.
    func suggestion(minutes: Int) async -> Wire.Suggestion? {
        guard let service = planService else { return nil }
        do { return try await service.nextAction(minutes: minutes) } catch { self.error = Self.planMessage(error); return nil }
    }

    func replanPreview(minutesLeft: Int) async -> Wire.Replan? {
        guard let service = planService else { return nil }
        do { return try await service.replan(minutesLeft: minutesLeft) } catch { self.error = Self.planMessage(error); return nil }
    }

    /// Moves what no longer fits to tomorrow.
    func applyReplan(_ replan: Wire.Replan) async {
        guard let service = planService, let tomorrow = PlanService.dayAfter(plan?.day) else { return }
        do { for item in replan.moveToTomorrow { try await service.move(item, to: tomorrow) }; error = nil } catch { self.error = Self.planMessage(error) }
        await loadPlan()
    }

    func closeDay(reflection: String?) async -> Wire.DayCloseResult? {
        guard let service = planService else { return nil }
        do { let r = try await service.closeDay(reflection: reflection); error = nil; await loadPlan(); return r } catch { self.error = Self.planMessage(error); return nil }
    }

    private func taskAction(_ id: String, _ body: (PlanService) async throws -> Void) async {
        guard let service = planService, !busyTasks.contains(id) else { return }
        busyTasks.insert(id); defer { busyTasks.remove(id) }
        do { try await body(service); error = nil } catch { self.error = Self.planMessage(error) }
        await loadPlan()
    }

    private static func planMessage(_ e: Error) -> String {
        switch e as? LifeError {
        case .unauthorized: "Please sign in again."
        case .notProvisioned: "Your workspace isn't ready for tasks yet."
        case .engine(let code, let message): code == "conflict" ? "That changed elsewhere. It has been refreshed." : message
        case .retry: "You're offline, or the service is busy. Try again in a moment."
        default: "Something went wrong with today's tasks."
        }
    }

    // MARK: Settings. The phone says where the person is.

    private var settingsService: SettingsService?
    func attachSettings(_ service: SettingsService?) { settingsService = service }

    /// Tell the engine the phone's time zone, so every "today" is today where you are. Quiet: a failure here must not block anything.
    func syncTimeZone() async { _ = try? await settingsService?.matchTimeZone() }

    // MARK: Goals. The Life Engine's, so a goal the assistant creates is the goal the screen shows.

    private(set) var goals: [Wire.Goal] = []
    private var goalService: GoalsService?
    var goalsAvailable: Bool { goalService != nil }

    func attachGoals(_ service: GoalsService?) { goalService = service }

    func loadGoals() async {
        guard let service = goalService else { return }
        do { goals = try await service.list() } catch { self.error = Self.goalMessage(error) }
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
    func addRoutine(_ r: Routine) async { await run { try await self.engine.addRoutine(r) } }
    func setRoutine(_ id: UUID, done: Bool) async { await run { try await self.engine.setRoutine(id, day: self.today, done: done) } }
    func addJournal(text: String, goals: [UUID] = [], tomorrow: String? = nil) async { await run { try await self.engine.addJournal(text: text, goals: goals, tomorrow: tomorrow) } }
    func addMemory(_ m: Memory) async { await run { try await self.engine.addMemory(m) } }

    func capture(_ text: String) async -> CaptureOutcome? {
        // Reminders never come through here: the capture sheet reviews them and saves them with addReminder, the Life Engine's
        // own operation. Everything else is still kept on this phone.
        do { let (o, s) = try await engine.capture(text); store = s; return o } catch { self.error = Self.message(error); return nil }
    }

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
