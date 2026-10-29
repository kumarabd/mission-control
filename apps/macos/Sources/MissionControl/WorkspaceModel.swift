import ClerkKit
import Foundation
import Observation

/// A task or event to open; `at` names the occurrence of a repeating item.
struct ItemRef: Identifiable, Hashable {
    let id: String
    var at: Date?
}

/// The signed-in desktop workspace. It owns the same Life, memory, notification
/// and agent state as the other clients, so every surface reads and writes the
/// same records through the same services.
@MainActor @Observable
final class WorkspaceModel {
    enum Destination: String, CaseIterable, Identifiable {
        case today, goals, chat, memory, notifications, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .today: "Today"
            case .goals: "Goals"
            case .chat: "Chat"
            case .memory: "Memory"
            case .notifications: "Notifications"
            case .settings: "Settings"
            }
        }
        var symbol: String {
            switch self {
            case .today: "sun.max"
            case .goals: "chart.line.uptrend.xyaxis"
            case .chat: "bubble.left"
            case .memory: "brain.head.profile"
            case .notifications: "tray"
            case .settings: "person.crop.circle"
            }
        }
    }

    enum Provisioning: Equatable {
        case checking, missing, ready
    }

    enum MemoryLens: String, CaseIterable, Identifiable {
        case world, aboutYou
        var id: String { rawValue }
        var title: String {
            switch self {
            case .world: "World"
            case .aboutYou: "About you"
            }
        }
        var symbol: String {
            switch self {
            case .world: "point.3.connected.trianglepath.dotted"
            case .aboutYou: "person.text.rectangle"
            }
        }
    }

    let userId: String
    let life: Life
    let chat: ChatStore
    let chatModel: ChatModel
    let notifications = NotificationsModel()
    let memory = MemoryModel()
    let agents = AgentsDirectory()

    var destination: Destination = .today
    var memoryLens: MemoryLens = .world
    private(set) var provisioning: Provisioning = .checking
    private(set) var started = false

    /// A record a notification or another screen asked to open. The owning
    /// screen consumes it and clears it.
    var pendingItem: ItemRef?
    var pendingGoalID: String?
    /// A new record requested from outside the owning screen, e.g. the command palette.
    var pendingNewItem: ItemsService.Kind?
    /// What the finished turn changed, read from returned records. Never
    /// parsed from the assistant's wording.
    private(set) var receipts: [WorkspaceUpdate] = []

    private let token: () async -> String?
    private var servicesAttached = false

    init(userId: String) {
        self.userId = userId
        life = Life(engine: LocalEngine(owner: userId))
        let chat = ChatStore()
        self.chat = chat
        chatModel = ChatModel(store: chat)
        token = { try? await Clerk.shared.auth.getToken() }
        chatModel.workspace = self
        #if DEBUG
        // `-start-page chat` opens a developer build on that surface, like `-start-tab` on the phone.
        if let name = UserDefaults.standard.string(forKey: "start-page"),
           let page = Destination(rawValue: name.lowercased()) { destination = page }
        #endif
    }

    var routerBase: String { Config.routerBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

    var memoryService: MemoryService {
        #if DEBUG
        if Config.devEngine { return .devSample }
        #endif
        return MemoryService(baseURL: routerBase + "/brain", token: token)
    }

    var agentsAPI: GatewayAgentsAPI {
        GatewayAgentsAPI(baseURL: routerBase + "/gateway", token: { try await ClerkGatewayAuthentication().sessionToken() })
    }

    func start() async {
        if started {
            if provisioning == .ready { chat.start() }
            return
        }
        started = true
        #if DEBUG
        if Config.devEngine { await attachDevWorkspace(); return }
        #endif
        guard !routerBase.isEmpty else { provisioning = .ready; return }

        if await Self.workspaceMissing() {
            provisioning = .missing
            return
        }
        await attachAndLoad()
    }

    #if DEBUG
    /// Developer mode serves sample data in place of a workspace, so every
    /// screen can be run and looked at without an account. Never ships.
    private func attachDevWorkspace() async {
        let api = DevWorld().api()
        life.attachWorkspace(items: ItemsService(api: api), day: DayService(api: api), goals: GoalsService(api: api))
        life.attachSettings(SettingsService(api: api))
        servicesAttached = true
        chat.start()
        await life.load()
        await life.refreshWorkspace()
        provisioning = .ready
    }
    #endif

    /// Called by the setup screen once provisioning reports completed.
    func finishOnboarding() async {
        await attachAndLoad()
    }

    func refresh() async {
        guard provisioning == .ready else { return }
        await life.syncTimeZone()
        await life.refreshWorkspace()
        await notifications.refresh()
        await agents.load()
    }

    /// Refresh after a chat turn and turn the returned records into receipts.
    /// `before` is the client's last snapshot, so the diff is real workspace
    /// state rather than a guess at what the assistant said it did.
    func refreshAfterTurn() async {
        let before = currentUpdates
        await refresh()
        receipts = Array(currentUpdates.filter { item in
            before.first(where: { $0.id == item.id }) != item
        }.prefix(6))
    }

    func open(_ update: WorkspaceUpdate) {
        switch update.kind {
        case .goal:
            destination = .goals
            pendingGoalID = update.entityID
        case .task, .event:
            destination = .today
            pendingItem = ItemRef(id: update.entityID)
        }
    }

    func clearReceipts() { receipts = [] }

    private var currentUpdates: [WorkspaceUpdate] {
        let completed = (life.day?.entries ?? []).filter(\.isDone).map { entry in
            WorkspaceUpdate(kind: entry.item.isEvent ? .event : .task,
                            entityID: entry.item.id,
                            title: entry.item.title,
                            detail: entry.item.isEvent ? "Event · done" : "Task · done",
                            version: entry.item.version)
        }
        var seen = Set<String>()
        return (life.workspaceUpdates + completed).filter { update in
            seen.insert(update.id).inserted
        }
    }

    func discuss(_ text: String) {
        chat.request(draft: text)
        destination = .chat
    }

    func showNotifications() {
        destination = .notifications
    }

    func requestNewItem(_ kind: ItemsService.Kind) {
        pendingNewItem = kind
        destination = .today
    }

    func open(_ target: PushLink.Target) {
        switch target.entity {
        case "task", "event", "plan_item":
            destination = .today
            pendingItem = ItemRef(id: target.id)
        case "goal":
            destination = .goals
            pendingGoalID = target.id
        case "routine", "reminder":
            destination = .goals
            pendingItem = ItemRef(id: target.id)
        case "journal_entry", "note", "capture":
            destination = .memory
        default:
            destination = .notifications
        }
    }

    private func attachAndLoad() async {
        chat.start()
        if !servicesAttached {
            let api = LifeAPI(baseURL: routerBase + "/life/api/v1", token: token)
            life.attachWorkspace(items: ItemsService(api: api), day: DayService(api: api), goals: GoalsService(api: api))
            life.attachProviders(ProviderService(routerBaseURL: routerBase, token: token))
            life.attachSettings(SettingsService(api: api))
            notifications.attach(NotificationsAPI(baseURL: routerBase + "/gateway", token: { try await ClerkGatewayAuthentication().sessionToken() }))
            servicesAttached = true
        }
        await life.syncTimeZone()
        await life.load()
        await life.refreshWorkspace()
        await notifications.refresh()
        await agents.load()
        provisioning = .ready
    }

    /// The router answers 404 `no_tenant` to `/brain/v1/explorer/me` (the
    /// same probe the web console uses) when the signed-in person has no
    /// workspace. Anything else — offline, a hiccup, an existing account —
    /// goes straight in, so setup never blocks a working workspace.
    private static func workspaceMissing() async -> Bool {
        guard let token = try? await Clerk.shared.auth.getToken(), !token.isEmpty,
              let url = URL(string: Config.routerBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                            + "/brain/v1/explorer/me") else { return false }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 404 && String(decoding: data, as: UTF8.self).contains("no_tenant")
    }
}
