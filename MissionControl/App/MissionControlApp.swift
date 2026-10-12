import SwiftUI
import SwiftData
import ClerkKit

@main
struct MissionControlApp: App {
    @State private var auth = AuthService()
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var phase

    private let modelContainer: ModelContainer = {
        let schema = Schema([MissionTask.self])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(lock)
                .environment(Clerk.shared)
                .tint(Tok.accent)
                .onOpenURL { url in
                    Task { try? await Clerk.shared.handle(url) }
                }
                // Cover the content while locked and in the app switcher, so the journal never shows in the snapshot.
                .overlay { if lock.locked || (lock.enabled && phase != .active) { LockCover { Task { await lock.unlock() } } } }
                .animation(.easeOut(duration: 0.15), value: lock.locked)
                .onChange(of: phase) { _, new in
                    if new == .background { lock.didLeaveForeground() }
                    if new == .active { Task { await lock.unlock() } }
                }
        }
        .modelContainer(modelContainer)
    }
}

/// Shown by an overlay, which sits outside the environment injected above, so it takes its action as a closure.
struct LockCover: View {
    let onUnlock: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "scope").font(.system(size: 44)).foregroundStyle(Tok.accent)
            Text("Mission Control is locked").font(.headline)
            Button("Unlock", action: onUnlock).buttonStyle(.bordered).frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tok.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}
