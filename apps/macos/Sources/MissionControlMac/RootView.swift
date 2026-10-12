import SwiftUI
import ClerkKit

struct RootView: View {
    @Environment(Clerk.self) private var clerk

    var body: some View {
        Group {
            if clerk.user == nil {
                SignInView()
            } else {
                ConversationWorkspace()
            }
        }
        .foregroundStyle(MissionTheme.ink)
        .background(MissionTheme.canvas)
    }
}

private struct SignInView: View {
    @Environment(Clerk.self) private var clerk
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            MissionTheme.canvas
            .ignoresSafeArea()

            MissionCard {
                VStack(spacing: 24) {
                    AssistantGlyph(size: 116)
                    VStack(spacing: 8) {
                        Text("Mission Control")
                            .font(.mission(.largeTitle, .semibold))
                            .foregroundStyle(MissionTheme.ink)
                        Text("Your personal assistant, built for the Mac.")
                            .font(.mission(.title3))
                            .foregroundStyle(MissionTheme.quietText)
                    }
                    Button {
                        signIn()
                    } label: {
                        Label("Continue with Google", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(minWidth: 230, minHeight: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSigningIn)
                    if isSigningIn { ProgressView().controlSize(.small) }
                }
                .padding(30)
            }
            .frame(maxWidth: 470)
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

    private func signIn() {
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do { try await clerk.auth.signInWithOAuth(provider: .google) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

private struct ConversationWorkspace: View {
    @State private var store = ChatStore()
    @Environment(Clerk.self) private var clerk

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SessionSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 360)
        } detail: {
            ChatView(store: store)
        }
        .background(MissionTheme.canvas)
        .task { store.start() }
        .onDisappear { store.stop() }
        .alert("Mission Control", isPresented: .init(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Something went wrong.")
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Sign out", role: .destructive) {
                        Task { try? await clerk.auth.signOut() }
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                }
                .help("Account")
            }
        }
    }
}

struct SettingsView: View {
    @Environment(Clerk.self) private var clerk

    var body: some View {
        Form {
            Section("Connection") {
                LabeledContent("Gateway", value: AppConfiguration.gatewayBaseURL.host ?? "")
                LabeledContent("History scope", value: "macOS")
            }
            Section("Account") {
                if let user = clerk.user {
                    LabeledContent("Signed in as", value: user.primaryEmailAddress?.emailAddress ?? user.id)
                } else {
                    Text("Not signed in")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(MissionTheme.canvas)
        .frame(width: 480, height: 260)
        .padding()
    }
}
