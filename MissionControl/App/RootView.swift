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
    @State private var tab = Tab.today
    @State private var capturing = false
    @State private var memoryRefreshToken = 0
    @State private var settings = false

    enum Tab: Hashable { case today, goals, memory }

    var body: some View {
        Group {
            if let life {
                TabView(selection: $tab) {
                    TodayView(onSettings: { settings = true }).tabItem { Label("Today", systemImage: "sun.max") }.tag(Tab.today)
                    ProgressTab(onSettings: { settings = true }).tabItem { Label("Goals", systemImage: "chart.line.uptrend.xyaxis") }.tag(Tab.goals)
                    MemoryView(onSettings: { settings = true }, refreshToken: memoryRefreshToken).tabItem { Label("Memory", systemImage: "brain.head.profile") }.tag(Tab.memory)
                }
                .environment(life)
                .overlay(alignment: .bottomTrailing) {
                    CaptureButton { capturing = true }.disabled(!life.workspaceLoaded).padding(.trailing, Space.l).padding(.bottom, 64)
                }
                .sheet(isPresented: $capturing, onDismiss: { memoryRefreshToken += 1 }) { CaptureSheet().environment(life) }
                .sheet(isPresented: $settings) { SettingsView() }
                .task { await life.syncTimeZone(); await life.load() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await life.syncTimeZone(); await life.refreshWorkspace() } } }
                .task { PushRegistrar.shared.attach(auth) }
                .onChange(of: DeepLink.shared.pending) { _, target in
                    guard let target else { return }
                    tab = switch target.section { case .today: .today; case .goals: .goals; case .memory: .memory }
                    // A reminder, routine or goal is opened by its own screen, which clears the link; anything else stops at its tab.
                    if !["reminder", "routine", "goal", "plan_item"].contains(target.entity) { DeepLink.shared.pending = nil }
                }
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
                l.attachPlan(PlanService(api: api))
                l.attachSettings(SettingsService(api: api))
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
