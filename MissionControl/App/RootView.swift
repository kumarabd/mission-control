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

/// Signed-in shell: four productivity tabs plus the original dashboard as Classic. Owns the per-person model so it is
/// rebuilt on sign-out. Capture floats over the productivity tabs.
struct MainTabs: View {
    let userId: String
    @Environment(AuthService.self) private var auth
    @State private var life: Life?
    @State private var tab = Tab.today
    @State private var capturing = false

    enum Tab: Hashable { case today, goals, journal, memory, classic }

    var body: some View {
        Group {
            if let life {
                TabView(selection: $tab) {
                    TodayView().tabItem { Label("Today", systemImage: "sun.max") }.tag(Tab.today)
                    GoalsView().tabItem { Label("Goals", systemImage: "flag") }.tag(Tab.goals)
                    JournalView().tabItem { Label("Journal", systemImage: "book") }.tag(Tab.journal)
                    MemoryView().tabItem { Label("Memory", systemImage: "brain.head.profile") }.tag(Tab.memory)
                    DashboardView().tabItem { Label("Classic", systemImage: "square.grid.2x2") }.tag(Tab.classic)
                }
                .environment(life)
                .overlay(alignment: .bottomTrailing) {
                    if tab != .classic { CaptureButton { capturing = true }.padding(.trailing, Space.l).padding(.bottom, 64) }
                }
                .sheet(isPresented: $capturing) { CaptureSheet().environment(life) }
                .task { await life.load() }
                .task { PushRegistrar.shared.attach(auth) }
                .onChange(of: DeepLink.shared.pending) { _, target in
                    guard let target else { return }
                    tab = switch target.section { case .today: .today; case .goals: .goals; case .journal: .journal; case .memory: .memory }
                    DeepLink.shared.pending = nil
                }
            } else {
                Tok.background.ignoresSafeArea()
            }
        }
        .task { life = Life(engine: LocalEngine(owner: userId)) }
    }
}
