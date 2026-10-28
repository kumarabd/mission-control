import ClerkKit
import SwiftUI

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Follow the system"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

/// Desktop settings: the same agents, models and connections the assistant
/// uses, with the account and appearance controls a Mac window expects.
struct SettingsScreen: View {
    enum Pane: String, CaseIterable, Identifiable {
        case account, agents, models, connections, appearance, about
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var symbol: String {
            switch self {
            case .account: "person.crop.circle"
            case .agents: "person.2"
            case .models: "cpu"
            case .connections: "link"
            case .appearance: "paintbrush"
            case .about: "info.circle"
            }
        }
    }

    @State private var pane: Pane = .account

    var body: some View {
        HSplitView {
            List(Pane.allCases, selection: $pane) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
            .background(Tok.surface)

            NavigationStack {
                Group {
                    switch pane {
                    case .account: AccountSettings()
                    case .agents: AgentsSettingsScreen()
                    case .models: ModelsSettingsView()
                    case .connections: ConnectionsSettingsView()
                    case .appearance: AppearanceSettings()
                    case .about: AboutSettings()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 460)
        }
        .background(Tok.background)
        .navigationTitle("Settings")
    }
}

private struct AccountSettings: View {
    @Environment(Clerk.self) private var clerk
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(AppLock.self) private var lock
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var lockBusy = false
    @State private var lockError: String?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Signed in") {
                if let user = clerk.user {
                    LabeledContent("Email", value: user.primaryEmailAddress?.emailAddress ?? "—")
                    LabeledContent("User ID", value: user.id)
                } else {
                    Text("Not signed in").foregroundStyle(Tok.muted)
                }
                LabeledContent("Gateway", value: AppConfiguration.routerBaseURL.host ?? "")
            }
            Section("Privacy") {
                Toggle("Require Touch ID or password", isOn: Binding(
                    get: { lock.enabled },
                    set: { on in
                        lockBusy = true
                        Task {
                            lockError = await lock.setEnabled(on)
                            lockBusy = false
                        }
                    }))
                    .disabled(lockBusy)
                if let lockError {
                    Text(lockError).font(.mission(.caption)).foregroundStyle(Tok.critical)
                }
                Text("Covers the workspace when Mission Control is not active. The same intent as the phone's Face ID lock.")
                    .font(.mission(.caption)).foregroundStyle(Tok.muted)
            }
            Section("Session") {
                Button("Sign out", role: .destructive) { confirmSignOut = true }
            }
            Section("Account") {
                Button(deleting ? "Deleting…" : "Delete account", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(deleting)
                if let error {
                    Text(error).font(.mission(.caption)).foregroundStyle(Tok.critical)
                }
            }
            Section {
                Text("Your workspace, goals and memory belong to this account. The Mac app reads and changes the same records as the web and phone.")
                    .font(.mission(.caption)).foregroundStyle(Tok.muted)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Account")
        .confirmationDialog("Sign out of Mission Control?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { try? await clerk.auth.signOut() } }
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { deleteAccount() }
        } message: {
            Text("This permanently deletes your sign-in. It can't be undone.")
        }
    }

    private func deleteAccount() {
        guard let user = clerk.user else { return }
        deleting = true
        Task {
            do {
                _ = try await user.delete()
                try? await clerk.auth.signOut()
            } catch {
                self.error = "Couldn't delete your account: \(error.localizedDescription)"
            }
            deleting = false
        }
    }
}

private struct AppearanceSettings: View {
    @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.system.rawValue

    private var choice: Binding<AppearanceChoice> {
        Binding(get: { AppearanceChoice(rawValue: appearanceRaw) ?? .system },
                set: { appearanceRaw = $0.rawValue })
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: choice) {
                    ForEach(AppearanceChoice.allCases) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                .pickerStyle(.inline)
            }
            Section {
                Text("Mission Control uses the same sage, warm-neutral palette everywhere. Following the system switches with your Mac; Light and Dark pin the app.")
                    .font(.mission(.caption)).foregroundStyle(Tok.muted)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Appearance")
    }
}

private struct AboutSettings: View {
    @Environment(\.openURL) private var openURL

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section("Mission Control") {
                LabeledContent("Version", value: version)
                LabeledContent("Gateway", value: AppConfiguration.routerBaseURL.host ?? "")
            }
            Section("Companion clients") {
                Button("Open the web console") {
                    if let url = URL(string: "https://mission-control.nighthawklabs.org") { openURL(url) }
                }
                Button("Docs") {
                    if let url = URL(string: "https://mission-control.nighthawklabs.org/docs") { openURL(url) }
                }
                Button("Support") {
                    if let url = URL(string: "https://mission-control.nighthawklabs.org/support") { openURL(url) }
                }
            }
            Section {
                Text("One workspace, shared by the web, macOS, iPhone, iPad, CarPlay and Watch clients. Desktop shows the most detail; smaller clients keep the focused view.")
                    .font(.mission(.caption)).foregroundStyle(Tok.muted)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("About")
    }
}
