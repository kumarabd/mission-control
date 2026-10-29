import ClerkKit
import SwiftUI

/// The signed-in desktop shell. The sidebar is the console's information
/// architecture; every detail is a verbose view over the shared workspace.
struct WorkspaceView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.system.rawValue
    @State private var workspace: WorkspaceModel
    @State private var paletteOpen = false

    init(userId: String) {
        _workspace = State(initialValue: WorkspaceModel(userId: userId))
    }

    var body: some View {
        @Bindable var workspace = workspace
        Group {
            switch workspace.provisioning {
            case .checking:
                VStack(spacing: Space.m) {
                    AssistantGlyph(size: 74, active: true)
                    Text("Opening your workspace…").font(.mission(.body)).foregroundStyle(Tok.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tok.background)

            case .missing:
                OnboardingScreen(userId: workspace.userId) {
                    await workspace.finishOnboarding()
                }

            case .ready:
                NavigationSplitView {
                    sidebar(workspace: workspace)
                        .navigationSplitViewColumnWidth(min: 210, ideal: 236, max: 290)
                } detail: {
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .environment(workspace)
        .environment(workspace.life)
        .environment(workspace.chat)
        .environment(workspace.chatModel)
        .environment(workspace.notifications)
        .environment(workspace.memory)
        .environment(workspace.agents)
        .task { await workspace.start() }
        .onDisappear { workspace.chat.stop() }
        // A finished turn may have written goals, tasks or notifications;
        // Memory is the one surface that also re-reads its world.
        .onChange(of: workspace.chat.completedTurns) { _, _ in
            Task {
                await workspace.refreshAfterTurn()
                await workspace.memory.loadWorld(service: workspace.memoryService, force: true)
            }
        }
        .onChange(of: workspace.chat.isRunning) { _, running in
            if running { workspace.clearReceipts() }
        }
        .onChange(of: scenePhase) { _, phase in
            workspace.chat.isVisible = workspace.destination == .chat && phase == .active
            if phase == .active { Task { await workspace.refresh() } }
        }
        .onChange(of: workspace.destination) { _, destination in
            workspace.chat.isVisible = destination == .chat && scenePhase == .active
        }
        .onAppear {
            workspace.chat.isVisible = workspace.destination == .chat && scenePhase == .active
        }
        // The inbox is a server-owned feed; poll quietly like the web console.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { return }
                await workspace.notifications.refresh()
            }
        }
        .alert("Mission Control", isPresented: Binding(
            get: { workspace.chat.errorMessage != nil },
            set: { if !$0 { workspace.chat.errorMessage = nil } })) {
            Button("OK") { workspace.chat.errorMessage = nil }
        } message: {
            Text(workspace.chat.errorMessage ?? "Something went wrong.")
        }
        .sheet(isPresented: $paletteOpen) {
            CommandPaletteView()
                .environment(workspace)
        }
        // Section shortcuts live on invisible buttons so they work from every
        // screen without taking a toolbar slot.
        .background {
            VStack(spacing: 0) {
                Button("Today") { workspace.destination = .today }.keyboardShortcut("1", modifiers: .command)
                Button("Goals") { workspace.destination = .goals }.keyboardShortcut("2", modifiers: .command)
                Button("Chat") { workspace.destination = .chat }.keyboardShortcut("3", modifiers: .command)
                Button("Memory") { workspace.destination = .memory }.keyboardShortcut("4", modifiers: .command)
                Button("Notifications") { workspace.destination = .notifications }.keyboardShortcut("5", modifiers: .command)
                Button("Settings") { workspace.destination = .settings }.keyboardShortcut("6", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    /// Developer mode has no account to name, so it never shows the signed-in address.
    private var accountLabel: String {
        #if DEBUG
        if Config.devEngine { return "Your workspace" }
        #endif
        return clerk.user?.primaryEmailAddress?.emailAddress ?? "Your workspace"
    }

    private func sidebar(workspace: WorkspaceModel) -> some View {
        @Bindable var workspace = workspace
        return VStack(spacing: 0) {
            HStack(spacing: Space.s) {
                AssistantGlyph(size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mission Control")
                        .font(.mission(.headline, .semibold))
                    Text(accountLabel)
                        .font(.mission(.caption))
                        .foregroundStyle(Tok.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    appearanceRaw = colorScheme == .dark ? AppearanceChoice.light.rawValue : AppearanceChoice.dark.rawValue
                } label: {
                    Image(systemName: colorScheme == .dark ? "sun.max" : "moon")
                        .foregroundStyle(Tok.muted)
                }
                .buttonStyle(.plain)
                .help(colorScheme == .dark ? "Switch to light" : "Switch to dark")
                .accessibilityLabel(colorScheme == .dark ? "Switch to light" : "Switch to dark")
                Menu {
                    Button("Settings", systemImage: "person.crop.circle") {
                        workspace.destination = .settings
                    }
                    Button("Open web console", systemImage: "safari") {
                        if let url = URL(string: "https://mission-control.nighthawklabs.org") { openURL(url) }
                    }
                    Divider()
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { try? await clerk.auth.signOut() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Tok.muted)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Account")
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.m)

            Button { paletteOpen = true } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "magnifyingglass")
                        .font(.mission(.caption))
                    Text("Search or ask…")
                        .font(.mission(.subheadline))
                    Spacer(minLength: 0)
                    Text("⌘K")
                        .font(.missionMono(.caption2))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Tok.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                }
                .foregroundStyle(Tok.muted)
                .padding(.horizontal, Space.s)
                .frame(minHeight: 32)
                .background(Tok.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Tok.hairline)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.s)
            .accessibilityLabel("Search or command palette, Command K")

            List(selection: $workspace.destination) {
                Section("Workspace") {
                    ForEach([WorkspaceModel.Destination.today, .goals, .chat]) { destination in
                        if destination == .chat {
                            if workspace.chat.unread > 0 {
                                Label(destination.title, systemImage: destination.symbol)
                                    .badge(workspace.chat.unread)
                                    .tag(destination)
                            } else {
                                Label(destination.title, systemImage: destination.symbol)
                                    .tag(destination)
                            }
                        } else {
                            Label(destination.title, systemImage: destination.symbol)
                                .tag(destination)
                        }
                    }
                    memoryRow(workspace)
                    if workspace.destination == .memory {
                        ForEach(WorkspaceModel.MemoryLens.allCases) { lens in
                            memoryLensRow(lens, workspace: workspace)
                        }
                    }
                }
                Section("Inbox") {
                    if workspace.notifications.unread > 0 {
                        Label("Notifications", systemImage: "tray.full")
                            .badge(workspace.notifications.unread)
                            .tag(WorkspaceModel.Destination.notifications)
                    } else {
                        Label("Notifications", systemImage: "tray")
                            .tag(WorkspaceModel.Destination.notifications)
                    }
                }
                Section {
                    Label("Settings", systemImage: "person.crop.circle")
                        .tag(WorkspaceModel.Destination.settings)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()
            HStack(spacing: Space.s) {
                Circle()
                    .fill(chatColour(workspace.chat.connectionState))
                    .frame(width: 7, height: 7)
                Text(chatStatus(workspace.chat.connectionState))
                    .font(.missionMono(.caption2))
                    .foregroundStyle(Tok.muted)
                Spacer()
                if workspace.chat.isRunning {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
        }
        .background(Tok.surface)
    }

    @ViewBuilder private func memoryRow(_ workspace: WorkspaceModel) -> some View {
        HStack(spacing: Space.s) {
            Label(WorkspaceModel.Destination.memory.title, systemImage: WorkspaceModel.Destination.memory.symbol)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.mission(.caption2, .semibold))
                .foregroundStyle(Tok.muted)
                .rotationEffect(.degrees(workspace.destination == .memory ? 90 : 0))
                .animation(.easeOut(duration: 0.16), value: workspace.destination)
        }
        .tag(WorkspaceModel.Destination.memory)
    }

    @ViewBuilder private func memoryLensRow(_ lens: WorkspaceModel.MemoryLens, workspace: WorkspaceModel) -> some View {
        let active = workspace.destination == .memory && workspace.memoryLens == lens
        Button {
            workspace.memoryLens = lens
        } label: {
            HStack(spacing: Space.s) {
                Image(systemName: lens.symbol)
                    .font(.mission(.caption))
                    .frame(width: 16)
                Text(lens.title)
                    .font(.mission(.subheadline, active ? .medium : .regular))
                Spacer(minLength: 0)
                if lens == .aboutYou {
                    Text("Soon")
                        .font(.missionMono(.caption2))
                        .foregroundStyle(Tok.muted)
                } else if let count = worldCount(workspace) {
                    Text("\(count)")
                        .font(.missionMono(.caption2))
                        .foregroundStyle(Tok.muted)
                }
            }
            .foregroundStyle(active ? Tok.accent : Tok.text)
            .padding(.leading, 24)
            .padding(.trailing, Space.s)
            .frame(minHeight: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
        .listRowBackground(active ? Tok.accent.opacity(0.1) : Color.clear)
        .accessibilityAddTraits(active ? .isSelected : [])
        .help("Show \(lens.title)")
    }

    private func worldCount(_ workspace: WorkspaceModel) -> Int? {
        if case .ready(let graph) = workspace.memory.world { return graph.nodes.count }
        return nil
    }

    @ViewBuilder private var detail: some View {
        switch workspace.destination {
        case .today:
            TodayScreen()
        case .goals:
            GoalsScreen()
        case .chat:
            ChatScreen()
        case .memory:
            MemoryScreen()
        case .notifications:
            NotificationsScreen()
        case .settings:
            SettingsScreen()
        }
    }

    private func chatColour(_ state: ConnectionState) -> Color {
        switch state {
        case .live: Tok.accent
        case .connecting, .reconnecting: Tok.warn
        case .offline: Tok.muted
        }
    }

    private func chatStatus(_ state: ConnectionState) -> String {
        switch state {
        case .live: "Assistant connected"
        case .connecting: "Connecting…"
        case .reconnecting: "Reconnecting…"
        case .offline(let reason): reason ?? "Offline · history recovery"
        }
    }
}
