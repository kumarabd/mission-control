import Foundation

/// What the car shows of the workspace: today's occurrences and the open goals, read through the same Life Engine
/// operations the phone uses. Read-only apart from completing a task, which the engine accepts from any client.
@MainActor
final class CarPlayWorkspace: ObservableObject {
    @Published private(set) var day: Wire.Day?
    @Published private(set) var goals: [Wire.Goal] = []
    @Published private(set) var failure: String?
    @Published private(set) var refreshedAt: Date?
    private(set) var loading = false

    private var api: LifeAPI {
        LifeAPI(baseURL: Config.routerBaseURL + "/life/api/v1",
                token: { try? await ClerkGatewayAuthentication().sessionToken() })
    }

    // MARK: Today

    var openEntries: [Wire.DayEntry] {
        (day?.entries ?? []).filter { !$0.isDone }.sorted { $0.at < $1.at }
    }

    var overdueEntries: [Wire.DayEntry] {
        openEntries.filter { entry in
            entry.overdue || (entry.item.isTask && entry.at < Date().addingTimeInterval(-60))
        }
    }

    var timedEntries: [Wire.DayEntry] {
        let overdue = Set(overdueEntries.map(\.id))
        return openEntries.filter { $0.item.at != nil && !overdue.contains($0.id) }
    }

    var anytimeEntries: [Wire.DayEntry] {
        openEntries.filter { $0.item.at == nil }
    }

    var doneEntries: [Wire.DayEntry] {
        (day?.entries ?? []).filter(\.isDone).sorted { $0.at > $1.at }
    }

    /// The few the assistant's screen previews: what needs attention first, then what is coming.
    var nextEntries: [Wire.DayEntry] { Array(openEntries.prefix(3)) }

    var openGoals: [Wire.Goal] { goals.filter { $0.deletedAt == nil } }

    // MARK: Reading

    func refresh() async {
        guard !loading else { return }
        guard !Config.routerBaseURL.isEmpty else {
            failure = "No workspace is connected to this build."
            return
        }
        loading = true
        defer { loading = false }
        do {
            let api = self.api
            async let day = DayService(api: api).today()
            async let goals = GoalsService(api: api).list()
            let (loadedDay, loadedGoals) = try await (day, goals)
            self.day = loadedDay
            self.goals = loadedGoals
            failure = nil
            refreshedAt = Date()
        } catch {
            failure = Self.sentence(for: error)
        }
    }

    // MARK: Writing

    /// Marks a task done or open again. Returns whether the engine accepted it.
    @discardableResult
    func setDone(_ entry: Wire.DayEntry, done: Bool) async -> Bool {
        guard entry.item.isTask else { return false }
        do {
            _ = try await ItemsService(api: api).complete(entry.item, done: done)
            await refresh()
            return true
        } catch {
            failure = Self.sentence(for: error)
            return false
        }
    }

    @discardableResult
    func snooze(_ entry: Wire.DayEntry, minutes: Int) async -> Bool {
        guard entry.item.isTask else { return false }
        do {
            _ = try await ItemsService(api: api).snooze(entry.item, until: Date().addingTimeInterval(TimeInterval(minutes * 60)))
            await refresh()
            return true
        } catch {
            failure = Self.sentence(for: error)
            return false
        }
    }

    private static func sentence(for error: Error) -> String {
        guard let life = error as? LifeError else { return "The workspace didn’t answer. Try again." }
        switch life {
        case .unauthorized: return "Sign in on the phone to load your day."
        case .notProvisioned: return "No workspace yet — finish setting up on the phone."
        case .retry: return "Can’t reach the workspace right now."
        case .engine(_, let message): return message
        case .server: return "The workspace didn’t answer. Try again."
        }
    }
}
