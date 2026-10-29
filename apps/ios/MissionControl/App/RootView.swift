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
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var pending: Step?

    private enum Step { case email, google, apple }
    private var busy: Bool { pending != nil }

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "scope").font(.system(size: 44)).foregroundStyle(Tok.accent)
            Text("Mission Control").font(.largeTitle.bold()).padding(.top, 20)
            Text("Make progress on what matters, one day at a time.").font(.body).foregroundStyle(Tok.muted).padding(.top, 8)
            Spacer()
            if let error { Text(error).font(.callout).foregroundStyle(Tok.critical).padding(.bottom, 12) }
            PlainInput(label: "Email", text: $email, placeholder: "you@example.com", keyboard: .emailAddress)
            SecretInput(label: "Password", text: $password).padding(.top, 10)
                .submitLabel(.go)
                .onSubmit { signIn() }
            Button { signIn() } label: {
                if pending == .email { ProgressView().tint(Tok.onAccent) } else { Text("Sign in") }
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(busy || !canSignIn).padding(.top, 14)
            HStack(spacing: 12) {
                Rectangle().fill(Tok.hairline).frame(height: 1)
                Text("or").font(.footnote).foregroundStyle(Tok.muted)
                Rectangle().fill(Tok.hairline).frame(height: 1)
            }.padding(.vertical, 16)
            Button {
                pending = .google
                Task { error = await auth.signInWithGoogle(); pending = nil }
            } label: {
                ZStack {
                    HStack {
                        Image("GoogleG").resizable().scaledToFit().frame(width: 20, height: 20).padding(.leading, 18)
                        Spacer()
                    }
                    if pending == .google {
                        ProgressView().tint(Tok.accent)
                    } else {
                        Text("Continue with Google").font(.mission(.headline, .medium)).foregroundStyle(Color(light: 0x3C4043, dark: 0x3C4043))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(.white, in: Capsule())
                .overlay(Capsule().strokeBorder(Tok.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain).disabled(busy).opacity(busy && pending != .google ? 0.4 : 1)
            Button {
                pending = .apple
                Task { error = await auth.signInWithApple(); pending = nil }
            } label: {
                Group {
                    if pending == .apple {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium))
                            Text("Continue with Apple").font(.mission(.headline, .medium))
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(.black, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain).disabled(busy).opacity(busy && pending != .apple ? 0.4 : 1).padding(.top, 10)
        }
        .padding(24)
        .background(Tok.background.ignoresSafeArea())
    }

    private func signIn() {
        guard canSignIn, !busy else { return }
        pending = .email
        Task { error = await auth.signIn(email: email, password: password); pending = nil }
    }
}

/// Signed-in shell: Today, Goals, Chat and Memory. Owns the per-person model so it is
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
                TabView(selection: Binding(get: { tab }, set: { new in
                    if new == tab, new == .chat { chat.showLatest() }
                    tab = new
                })) {
                    TodayView(onSettings: { settings = true }).tabItem { Label("Today", systemImage: "sun.max") }.tag(Tab.today)
                    ProgressTab(onSettings: { settings = true }).tabItem { Label("Goals", systemImage: "chart.line.uptrend.xyaxis") }.tag(Tab.goals)
                    ChatView(onSettings: { settings = true }).tabItem { Label("Chat", systemImage: "bubble.left") }.badge(chat.unread).tag(Tab.chat)
                    MemoryView(onSettings: { settings = true }, refreshToken: memoryRefreshToken).tabItem { Label("Memory", systemImage: "brain.head.profile") }.tag(Tab.memory)
                }
                // iPad gets the tab bar with a toggle to a sidebar; iPhone is unchanged.
                .tabViewStyle(.sidebarAdaptable)
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
                    // A task, event or goal is opened by its own screen, which clears the link; anything else stops at its tab.
                    if !["task", "event", "goal"].contains(target.entity) { DeepLink.shared.pending = nil }
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
            // Goals, tasks and events live in the Life Engine; without a router (developer mode) there is nowhere to keep them.
            if !Config.devEngine, !Config.routerBaseURL.isEmpty {
                let api = LifeAPI(baseURL: Config.routerBaseURL + "/life/api/v1", token: { [auth] in await auth.token() })
                l.attachWorkspace(items: ItemsService(api: api), day: DayService(api: api), goals: GoalsService(api: api))
                l.attachProviders(ProviderService(routerBaseURL: Config.routerBaseURL, token: { [auth] in await auth.token() }))
                l.attachSettings(SettingsService(api: api))
                // The notification inbox is the gateway's, not the Life Engine's: it holds what the assistant sent.
                notifications.attach(NotificationsAPI(baseURL: Config.routerBaseURL + "/gateway", token: { [auth] in await auth.token() }))
            }
            #if DEBUG
            if Config.devEngine {
                // Developer mode serves sample data in place of a workspace, so every screen can be run and looked at.
                let api = DevWorld().api()
                l.attachWorkspace(items: ItemsService(api: api), day: DayService(api: api), goals: GoalsService(api: api))
                l.attachSettings(SettingsService(api: api))
            }
            #endif
            life = l
        }
    }
}
