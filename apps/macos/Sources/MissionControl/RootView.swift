import ClerkKit
import SwiftUI

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.system.rawValue
    @State private var lock = AppLock()

    private var appearance: AppearanceChoice {
        AppearanceChoice(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        Group {
            #if DEBUG
            if Config.devEngine {
                // Developer mode skips Clerk and the router, like the phone builds.
                WorkspaceView(userId: "dev-user")
            } else if let user = clerk.user {
                WorkspaceView(userId: user.id).id(user.id)
            } else {
                SignInView()
            }
            #else
            if let user = clerk.user {
                WorkspaceView(userId: user.id)
                    .id(user.id)
            } else {
                SignInView()
            }
            #endif
        }
        .environment(lock)
        .foregroundStyle(MissionTheme.ink)
        .background(MissionTheme.canvas)
        .preferredColorScheme(appearance.scheme)
        .overlay {
            if lock.locked && clerk.user != nil {
                LockCover()
                    .environment(lock)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && clerk.user != nil { lock.didLeave() }
        }
        .animation(.easeInOut(duration: 0.2), value: clerk.user?.id)
    }
}

/// Covers the workspace while locked, including in the window snapshot.
struct LockCover: View {
    @Environment(AppLock.self) private var lock
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Tok.background.ignoresSafeArea()
            MissionCard {
                VStack(spacing: Space.m) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 38))
                        .foregroundStyle(Tok.accent)
                    Text("Mission Control is locked")
                        .font(.mission(.title3, .semibold))
                    Text("Use Touch ID or your Mac password to open your workspace.")
                        .font(.mission(.subheadline))
                        .foregroundStyle(Tok.muted)
                        .multilineTextAlignment(.center)
                    if let error {
                        Text(error).font(.mission(.caption)).foregroundStyle(Tok.critical)
                    }
                    Button(busy ? "Unlocking…" : "Unlock") {
                        busy = true
                        Task {
                            error = await lock.unlock()
                            busy = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(busy)
                }
                .padding(Space.l)
                .frame(maxWidth: 380)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SignInView: View {
    @Environment(Clerk.self) private var clerk
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            MissionTheme.canvas.ignoresSafeArea()

            MissionCard {
                VStack(spacing: 24) {
                    AssistantGlyph(size: 116)
                    VStack(spacing: 8) {
                        Text("Mission Control")
                            .font(.mission(.largeTitle, .semibold))
                            .foregroundStyle(MissionTheme.ink)
                        Text("Your assistant, at full detail.")
                            .font(.mission(.title3))
                            .foregroundStyle(MissionTheme.quietText)
                        Text("The same workspace as the web, phone and watch.")
                            .font(.mission(.caption))
                            .foregroundStyle(MissionTheme.quietText)
                    }
                    Button {
                        signInWithApple()
                    } label: {
                        Label("Continue with Apple", systemImage: "apple.logo")
                            .frame(minWidth: 250, minHeight: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSigningIn)
                    Button {
                        signInWithGoogle()
                    } label: {
                        Label("Continue with Google", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(minWidth: 250, minHeight: 30)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isSigningIn)
                    if isSigningIn { ProgressView().controlSize(.small) }
                }
                .padding(30)
            }
            .frame(maxWidth: 480)
            .padding(44)
        }
        .alert("Couldn’t sign in", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func signInWithApple() {
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do { try await clerk.auth.signInWithApple() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func signInWithGoogle() {
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do { try await clerk.auth.signInWithOAuth(provider: .google) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

/// The system Settings scene. The in-app Settings surface carries the full
/// console; this window keeps the Mac conventions reachable from the app menu.
struct SettingsView: View {
    @Environment(Clerk.self) private var clerk
    @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.system.rawValue

    private var appearance: Binding<AppearanceChoice> {
        Binding(get: { AppearanceChoice(rawValue: appearanceRaw) ?? .system },
                set: { appearanceRaw = $0.rawValue })
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: appearance) {
                    ForEach(AppearanceChoice.allCases) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                .pickerStyle(.inline)
            }
            Section("Connection") {
                LabeledContent("Gateway", value: AppConfiguration.routerBaseURL.host ?? "")
                LabeledContent("History scope", value: "macOS")
            }
            Section("Account") {
                if let user = clerk.user {
                    LabeledContent("Signed in as", value: user.primaryEmailAddress?.emailAddress ?? user.id)
                    Button("Sign out", role: .destructive) {
                        Task { try? await clerk.auth.signOut() }
                    }
                } else {
                    Text("Not signed in").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(MissionTheme.canvas)
        .frame(width: 520, height: 360)
        .padding()
    }
}
