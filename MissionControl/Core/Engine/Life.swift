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

    // MARK: Workspace. The Life Engine's goals, tasks and events, the same records the assistant reads and changes.

    private(set) var workspaceLoaded = false
    private(set) var day: Wire.Day?
    /// Open tasks, soonest first, untimed last.
    private(set) var openTasks: [Wire.Item] = []
    /// Events from now on.
    private(set) var upcomingEvents: [Wire.Item] = []
    private(set) var goals: [Wire.Goal] = []
    private(set) var dayLoadError: String?
    private(set) var goalsLoadError: String?
    /// Items with a change in flight; a second tap on the same one waits.
    private(set) var busyItems: Set<String> = []
    private var itemService: ItemsService?
    private var dayService: DayService?
    private var goalService: GoalsService?
    var workspaceAvailable: Bool { itemService != nil }
    var goalsAvailable: Bool { goalService != nil }

    func attachWorkspace(items: ItemsService?, day: DayService?, goals: GoalsService?) {
        itemService = items; dayService = day; goalService = goals
    }

    func refreshWorkspace() async {
        error = nil
        await loadDay(); await loadGoals()
        workspaceLoaded = true
    }

    /// Today's entries, with the open tasks and upcoming events the other screens list.
    func loadDay() async {
        guard let days = dayService, let items = itemService else { return }
        do {
            day = try await days.today()
            openTasks = try await items.list(.task)
            upcomingEvents = try await items.list(.event, status: "open").filter { ($0.at ?? .distantFuture) >= Date().addingTimeInterval(-3600) || $0.repeats }
            dayLoadError = nil
        } catch { dayLoadError = Self.message(error, "your day"); self.error = dayLoadError }
    }

    func loadGoals() async {
        guard let service = goalService else { return }
        do { goals = try await service.list(); goalsLoadError = nil } catch { goalsLoadError = Self.message(error, "goals"); self.error = goalsLoadError }
    }

    /// The tasks and events serving a goal, for its screen: every one, done or not.
    func items(forGoal goalID: String) async -> [Wire.Item] {
        guard let service = itemService else { return [] }
        do { return try await service.list(.task, status: "all", goalID: goalID) + service.list(.event, status: "all", goalID: goalID) }
        catch { self.error = Self.message(error, "this goal"); return [] }
    }

    /// An item the screens know about, whichever list it came from.
    func item(_ id: String) -> Wire.Item? {
        openTasks.first { $0.id == id } ?? upcomingEvents.first { $0.id == id } ?? day?.entries.first { $0.item.id == id }?.item
    }

    @discardableResult
    func add(_ kind: ItemsService.Kind, _ draft: ItemsService.Draft) async -> Bool {
        guard let service = itemService else { error = "This needs your workspace, and it isn't reachable right now."; return false }
        do {
            _ = try await service.create(kind, draft); error = nil
            await loadDay(); await loadGoals()
            if draft.alertBeforeMinutes != nil { await PushRegistrar.shared.askToNotify() }
            return true
        } catch { self.error = Self.message(error, "that"); return false }
    }

    @discardableResult
    func save(_ item: Wire.Item, _ draft: ItemsService.Draft) async -> Bool {
        let saved = await act(item.id) { _ = try await $0.update(item, draft) } != nil
        if saved, draft.alertBeforeMinutes != nil { await PushRegistrar.shared.askToNotify() }
        return saved
    }

    /// Done, or (`done: false`) not done after all; the item as the engine now has it, or nil if that failed. For a repeating
    /// task, `at` names the occurrence.
    @discardableResult
    func complete(_ item: Wire.Item, at: Date? = nil, done: Bool = true) async -> Wire.Item? {
        await act(item.id) { try await $0.complete(item, at: at, done: done) }
    }

    @discardableResult
    func snooze(_ item: Wire.Item, until: Date) async -> Bool { await act(item.id) { _ = try await $0.snooze(item, until: until) } != nil }

    @discardableResult
    func delete(_ item: Wire.Item) async -> Bool { await act(item.id) { try await $0.delete(item) } != nil }

    func archive(_ goal: Wire.Goal) async {
        guard let service = goalService else { return }
        do { try await service.archive(goal); error = nil } catch { self.error = Self.message(error, "goals") }
        await loadGoals()
    }

    // MARK: Views. A view is its own construct, of a goal, a task or an event; its data is read through these.

    private var providerService: ProviderService?
    func attachProviders(_ service: ProviderService?) { providerService = service }

    func loadView(kind: String, id: String, catalog: String) async throws -> Wire.ViewState {
        guard let service = goalService else { throw LifeError.notProvisioned }
        return try await service.viewState(kind: kind, id: id, catalog: catalog)
    }
    /// A bound metric's recent values, read live from its data provider.
    func loadSeries(provider: String, series: String, granularity: String = "day") async throws -> Wire.SeriesData {
        guard let service = providerService else { throw LifeError.notProvisioned }
        let range = TrackerClient.seriesRange(days: 400)
        return try await service.series(provider: provider, series: series, from: range.from, to: range.to, granularity: granularity)
    }
    func saveMeasurement(_ input: GoalsService.MeasurementIn) async throws {
        guard let service = goalService else { throw LifeError.notProvisioned }
        try await service.saveMeasurement(input)
    }
    func deleteMeasurement(_ measurement: Wire.Measurement, key: String) async throws {
        guard let service = goalService else { throw LifeError.notProvisioned }
        try await service.deleteMeasurement(measurement, key: key)
    }
    static func trackerMessage(_ error: Error) -> String {
        if case LifeError.engine(let code, _) = error, code == "conflict" {
            return "This changed elsewhere. Review the latest view and ask for a refreshed one if needed."
        }
        return message(error, "this view")
    }

    /// A task by id: one the screens already hold, else read from the engine (a view may name a done or far-off one).
    private func task(_ id: String) async -> Wire.Item? {
        if let known = item(id) { return known }
        return try? await itemService?.list(.task, status: "all").first { $0.id == id }
    }

    /// How a repeating task is going: its recent days, for a view's grid and series.
    func taskHistory(_ id: String, days: Int) async -> Wire.TaskHistory? {
        guard let service = itemService, let task = await task(id) else { return nil }
        do { return try await service.history(task, days: days) } catch { self.error = Self.message(error, "this task"); return nil }
    }

    /// Records (or takes back) a repeating task's occurrence on a day: the same time of day, in the task's own zone.
    func logOccurrence(_ id: String, on day: Date, done: Bool) async {
        guard let task = await task(id), let anchor = task.at else { return }
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: task.timeZone) ?? .current
        let time = cal.dateComponents([.hour, .minute, .second], from: anchor)
        let dayParts = cal.dateComponents([.year, .month, .day], from: day)
        var parts = DateComponents(); parts.year = dayParts.year; parts.month = dayParts.month; parts.day = dayParts.day
        parts.hour = time.hour; parts.minute = time.minute; parts.second = time.second
        guard let at = cal.date(from: parts) else { return }
        _ = await complete(task, at: at, done: done)
    }

    private func act<T>(_ id: String, _ body: (ItemsService) async throws -> T) async -> T? {
        guard let service = itemService, !busyItems.contains(id) else { return nil }
        busyItems.insert(id); defer { busyItems.remove(id) }
        var result: T?
        do { result = try await body(service); error = nil } catch { self.error = Self.message(error, "that") }
        await loadDay(); await loadGoals()
        return result
    }

    private static func message(_ e: Error, _ what: String) -> String {
        switch e as? LifeError {
        case .unauthorized: "Please sign in again."
        case .notProvisioned: "Your workspace isn't ready for \(what) yet."
        case .engine(let code, let message): code == "conflict" ? "That changed elsewhere. It has been refreshed." : message
        case .retry: "You're offline, or the service is busy. Try again in a moment."
        default: "Something went wrong with \(what)."
        }
    }

    // MARK: Settings. The phone says where the person is.

    private var settingsService: SettingsService?
    func attachSettings(_ service: SettingsService?) { settingsService = service }

    /// Tell the engine the phone's time zone, so every "today" is today where you are. Quiet: a failure here must not block anything.
    func syncTimeZone() async { _ = try? await settingsService?.matchTimeZone() }

    func load() async { await run { try await self.engine.snapshot() } }

    func addGoal(title: String, why: String, weeklyTarget: Int) async { await run { try await self.engine.addGoal(title: title, why: why, weeklyTarget: weeklyTarget) } }
    func deleteGoal(_ id: UUID) async { await run { try await self.engine.deleteGoal(id) } }
    func addStep(goal: UUID, title: String, minutes: Int) async { await run { try await self.engine.addStep(goal: goal, title: title, minutes: minutes) } }
    func setStep(goal: UUID, step: UUID, done: Bool) async { await run { try await self.engine.setStep(goal: goal, step: step, done: done) } }
    func shrink(goal: UUID, obstacle: Obstacle) async { await run { try await self.engine.shrink(goal: goal, obstacle: obstacle) } }
    func addRoutine(_ r: Routine) async { await run { try await self.engine.addRoutine(r) } }
    func setRoutine(_ id: UUID, done: Bool) async { await run { try await self.engine.setRoutine(id, day: self.today, done: done) } }
    func addJournal(text: String, goals: [UUID] = [], tomorrow: String? = nil) async { await run { try await self.engine.addJournal(text: text, goals: goals, tomorrow: tomorrow) } }
    func addMemory(_ m: Memory) async -> Bool {
        do { store = try await engine.addMemory(m); error = nil; return true }
        catch { self.error = Self.message(error); return false }
    }

    func capture(_ text: String) async -> CaptureOutcome? {
        // Reminders never come through here: the capture sheet reviews them and saves them with addReminder, the Life Engine's
        // own operation. Everything else is still kept on this phone.
        do { let (o, s) = try await engine.capture(text); store = s; return o } catch { self.error = Self.message(error); return nil }
    }

    func weeklyReview() -> WeeklyReview { Planner.weeklyReview(store: store, now: Date()) }

    /// Saved memories matching every word typed, newest first. Historical journal records are retained but not surfaced.
    func search(_ query: String) -> [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let hits = store.memories.map { SearchHit(id: $0.id, date: $0.date, text: $0.text, reason: $0.reason, symbol: $0.kind.symbol, label: $0.kind.label) }
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

extension Life {
    var workspaceUpdates: [WorkspaceUpdate] {
        goals.map { WorkspaceUpdate(kind: .goal, entityID: $0.id, title: $0.title, detail: "Goal · \($0.progress.done) of \($0.progress.total) done", version: $0.version) }
        + openTasks.map { WorkspaceUpdate(kind: .task, entityID: $0.id, title: $0.title, detail: "Task" + ($0.at.map { " · " + $0.formatted(date: .abbreviated, time: .shortened) } ?? ""), version: $0.version) }
        + upcomingEvents.map { WorkspaceUpdate(kind: .event, entityID: $0.id, title: $0.title, detail: "Event" + ($0.at.map { " · " + $0.formatted(date: .abbreviated, time: .shortened) } ?? ""), version: $0.version) }
    }
}
