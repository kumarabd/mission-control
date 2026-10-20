import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                // Clerk takes a moment on a cold start; show the mark rather than an empty screen.
                Image(systemName: "scope").font(.system(size: 44)).foregroundStyle(Tok.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Tok.background.ignoresSafeArea())
            case .signedOut: WelcomeView()
            case .signedIn(let id, _): ProvisionGate(userId: id).id(id)   // a different user is a different shell, never a reused one
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.state)
    }
}

struct WelcomeView: View {
    @Environment(AuthService.self) private var auth
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "scope").font(.system(size: 44)).foregroundStyle(Tok.accent)
            Text("Mission Control").font(.largeTitle.bold()).padding(.top, 20)
            Text("Make progress on what matters, one day at a time.").font(.body).foregroundStyle(Tok.muted).padding(.top, 8)
            Spacer()
            if let error { Text(error).font(.callout).foregroundStyle(Tok.critical).padding(.bottom, 12) }
            Button {
                busy = true
                Task { error = await auth.signInWithGoogle(); busy = false }
            } label: {
                if busy { ProgressView().tint(Tok.onAccent) } else { Text("Continue with Google") }
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(busy)
        }
        .padding(24)
        .background(Tok.background.ignoresSafeArea())
    }
}

/// Signed-in shell: Today, Goals and Memory; Classic is available from Settings. Owns the per-person model so it is
/// rebuilt on sign-out. Capture floats over the productivity tabs.
struct MainTabs: View {
    let userId: String
    @Environment(AuthService.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var life: Life?
    @State private var notifications = NotificationsModel()
    @State private var chat: ChatModel
    @State private var agents = AgentsDirectory()
    @State private var tab = Tab.today
    @State private var memoryRefreshToken = 0
    @State private var settings = false

    init(userId: String) {
        self.userId = userId
        _chat = State(initialValue: ChatModel(owner: userId))
        #if DEBUG
        // `-start-tab chat` opens a developer build on that tab, so a screen can be run and looked at without tapping to it.
        if let name = UserDefaults.standard.string(forKey: "start-tab") {
            _tab = State(initialValue: ["today": Tab.today, "goals": .goals, "memory": .memory, "chat": .chat][name] ?? .today)
        }
        #endif
    }

    enum Tab: Hashable { case today, goals, memory, chat }

    var body: some View {
        Group {
            if let life {
                TabView(selection: $tab) {
                    TodayView(onSettings: { settings = true }).tabItem { Label("Today", systemImage: "sun.max") }.tag(Tab.today)
                    ProgressTab(onSettings: { settings = true }).tabItem { Label("Goals", systemImage: "chart.line.uptrend.xyaxis") }.tag(Tab.goals)
                    ChatView(onSettings: { settings = true }).tabItem { Label("Chat", systemImage: "bubble.left") }.badge(chat.unread).tag(Tab.chat)
                    MemoryView(onSettings: { settings = true }, refreshToken: memoryRefreshToken).tabItem { Label("Memory", systemImage: "brain.head.profile") }.tag(Tab.memory)
                }
                .environment(life)
                .environment(notifications)
                .environment(chat)
                .environment(agents)
                .task { await agents.load() }
                .sheet(isPresented: $settings) { SettingsView() }
                .task { await life.syncTimeZone(); await life.load(); await notifications.refresh() }
                .onAppear { chat.setForeground(scenePhase == .active) }
                .onChange(of: scenePhase) { _, phase in
                    chat.setForeground(phase == .active)
                    if phase == .active { Task { await life.syncTimeZone(); await life.refreshWorkspace(); await notifications.refresh() } }
                }
                .task { PushRegistrar.shared.attach(auth) }
                .onChange(of: DeepLink.shared.pending) { _, target in
                    guard let target else { return }
                    tab = switch target.section { case .today: .today; case .goals: .goals; case .memory: .memory }
                    // A reminder, routine or goal is opened by its own screen, which clears the link; anything else stops at its tab.
                    if !["reminder", "routine", "goal", "plan_item"].contains(target.entity) { DeepLink.shared.pending = nil }
                }
                // A finished turn may have changed the workspace, and Memory is the one tab that does not re-read on its own.
                .onChange(of: chat.completedTurns) { _, _ in memoryRefreshToken += 1 }
                // Another screen (a new goal, a memory to correct) starts the conversation: show it, with the draft in place.
                .onChange(of: chat.draftToken) { _, _ in tab = .chat }
            } else {
                Tok.background.ignoresSafeArea()
            }
        }
        .task {
            let l = Life(engine: LocalEngine(owner: userId))
            // Reminders live in the Life Engine; without a router (developer mode) there is nowhere to keep them.
            if !Config.devEngine, !Config.routerBaseURL.isEmpty {
                let api = LifeAPI(baseURL: Config.routerBaseURL + "/life/api/v1", token: { [auth] in await auth.token() })
                l.attachReminders(RemindersService(api: api))
                l.attachRoutines(RoutinesService(api: api))
                l.attachGoals(GoalsService(api: api))
                l.attachProviders(ProviderService(routerBaseURL: Config.routerBaseURL, token: { [auth] in await auth.token() }))
                l.attachPlan(PlanService(api: api))
                l.attachSettings(SettingsService(api: api))
                // The notification inbox is the gateway's, not the Life Engine's: it holds what the assistant sent.
                notifications.attach(NotificationsAPI(baseURL: Config.routerBaseURL + "/gateway", token: { [auth] in await auth.token() }))
            }
            #if DEBUG
            if Config.devEngine {
                // Developer mode serves sample data in place of a workspace, so every screen can be run and looked at.
                let api = DevWorld().api()
                l.attachReminders(RemindersService(api: api)); l.attachRoutines(RoutinesService(api: api)); l.attachGoals(GoalsService(api: api))
                l.attachPlan(PlanService(api: api)); l.attachSettings(SettingsService(api: api))
            }
            #endif
            life = l
        }
    }
}
