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

/// Signed-in shell. The productivity tabs join Classic as they are built.
struct MainTabs: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Classic", systemImage: "square.grid.2x2") }
        }
    }
}
