import Foundation

enum CheckError: Error { case unavailable }
// This test checks workspace refresh, not operating-system notification delivery.
final class PushRegistrar { static let shared = PushRegistrar(); func askToNotify() async {} }

struct UnavailableLocalEngine: LifeEngine {
    func snapshot() async throws -> Store {
        var store = Store()
        store.journal = [JournalEntry(text: "Historical journal entry", goalIDs: [], tomorrow: nil)]
        return store
    }
    func addGoal(title: String, why: String, weeklyTarget: Int) async throws -> Store { throw CheckError.unavailable }
    func deleteGoal(_ id: UUID) async throws -> Store { throw CheckError.unavailable }
    func addStep(goal: UUID, title: String, minutes: Int) async throws -> Store { throw CheckError.unavailable }
    func setStep(goal: UUID, step: UUID, done: Bool) async throws -> Store { throw CheckError.unavailable }
    func shrink(goal: UUID, obstacle: Obstacle) async throws -> Store { throw CheckError.unavailable }
    func addPlanItem(_ item: PlanItem) async throws -> Store { throw CheckError.unavailable }
    func setPlanItem(_ id: UUID, done: Bool) async throws -> Store { throw CheckError.unavailable }
    func setPriority(_ id: UUID, _ on: Bool) async throws -> Store { throw CheckError.unavailable }
    func deletePlanItem(_ id: UUID) async throws -> Store { throw CheckError.unavailable }
    func apply(_ change: PlanChange) async throws -> Store { throw CheckError.unavailable }
    func closeDay(_ day: Date, reflection: String?) async throws -> (DayClose, Store) { throw CheckError.unavailable }
    func capture(_ text: String) async throws -> (CaptureOutcome, Store) { throw CheckError.unavailable }
    func addRoutine(_ routine: Routine) async throws -> Store { throw CheckError.unavailable }
    func setRoutine(_ id: UUID, day: Date, done: Bool) async throws -> Store { throw CheckError.unavailable }
    func addJournal(text: String, goals: [UUID], tomorrow: String?) async throws -> Store { throw CheckError.unavailable }
    func addMemory(_ memory: Memory) async throws -> Store { throw CheckError.unavailable }
    func setReminder(_ id: UUID, done: Bool) async throws -> Store { throw CheckError.unavailable }
}

actor FixtureTransport {
    let directory: URL
    var calls: [String] = []
    var edited = false
    var offline = false
    init(directory: URL) { self.directory = directory }
    func reset(edited: Bool = false, offline: Bool = false) { calls = []; self.edited = edited; self.offline = offline }
    func send(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let operation = request.url!.lastPathComponent
        calls.append(operation)
        if offline { throw URLError(.notConnectedToInternet) }
        let names = ["day_get": "day", "tasks_list": "tasks_page", "calendar_events_list": "events_page", "goals_list": "goals_page", "tasks_complete": "task_done",
                     "tasks_create": "task", "calendar_events_create": "event"]
        var data = try Data(contentsOf: directory.appendingPathComponent(names[operation]! + ".json"))
        if edited, operation == "goals_list" {
            var page = try Wire.decoder.decode(Wire.Page<Wire.Goal>.self, from: data)
            page.items[0].version += 1
            data = try Wire.encoder.encode(page)
        }
        return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@main
struct WorkspaceRefreshChecks {
    @MainActor static func main() async throws {
        let transport = FixtureTransport(directory: URL(fileURLWithPath: CommandLine.arguments[1]))
        let api = LifeAPI(baseURL: "https://test.invalid", token: { "test" }, transport: { try await transport.send($0) })
        let life = Life(engine: UnavailableLocalEngine())
        life.attachWorkspace(items: ItemsService(api: api), day: DayService(api: api), goals: GoalsService(api: api))
        precondition(!life.workspaceLoaded && life.workspaceAvailable && life.goalsAvailable)
        await life.refreshWorkspace()
        precondition(life.workspaceLoaded && life.day != nil && !life.day!.entries.isEmpty && !life.goals.isEmpty && !life.openTasks.isEmpty && !life.upcomingEvents.isEmpty)
        let calls = await transport.calls
        precondition(Set(calls) == Set(["day_get", "tasks_list", "calendar_events_list", "goals_list"]), "\(calls)")
        precondition(life.item(life.openTasks[0].id) == life.openTasks[0] && life.item(life.upcomingEvents[0].id) != nil, "an item is found whichever list it came from")

        // Doing something sends it and re-reads what the screens show.
        await transport.reset()
        let done = await life.complete(life.openTasks[0])
        precondition(done?.isDone == true)
        let afterComplete = await transport.calls
        precondition(Set(afterComplete) == Set(["tasks_complete", "day_get", "tasks_list", "calendar_events_list", "goals_list"]))
        await transport.reset()
        var draft = ItemsService.Draft(); draft.title = "Call Sam"
        let added = await life.add(.task, draft)
        let afterAdd = await transport.calls
        precondition(added && afterAdd.first == "tasks_create")

        let before = life.workspaceUpdates
        await transport.reset(edited: true)
        await life.refreshWorkspace()
        let changes = life.workspaceUpdates.filter { item in before.first(where: { $0.id == item.id }) != item }
        precondition(changes.count == 1 && changes[0].kind == .goal, "An edited goal must refresh and yield a receipt")
        await life.load()
        precondition(!life.store.journal.isEmpty && life.search("").isEmpty, "Retain history without surfacing a journal")
        let saved = await life.addMemory(Memory(text: "Must not claim success", reason: nil, kind: .note))
        precondition(!saved && life.error != nil)
        let goalID = life.goals[0].id
        await transport.reset(offline: true)
        await life.refreshWorkspace()
        precondition(life.dayLoadError != nil && life.goalsLoadError != nil)
        precondition(life.goals[0].id == goalID && !life.openTasks.isEmpty, "A failed refresh must keep previous data")
        print("WorkspaceRefreshChecks passed")
    }
}
