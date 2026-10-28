import SwiftUI

/// The gateway's agent registry, with the desktop client's selected agent.
/// The choice is sent in the chat socket's auth frame, the same as the other
/// native clients.
struct AgentsSettingsScreen: View {
    @Environment(WorkspaceModel.self) private var workspace

    @State private var agents: [GatewayAgentsAPI.Agent] = []
    @State private var loading = true
    @State private var failure: String?
    @State private var editing: GatewayAgentsAPI.Agent?
    @State private var creating = false
    @State private var confirmDisable: GatewayAgentsAPI.Agent?

    private var defaultAgentID: String { ChatStore.defaultAgent }
    private var selectedID: String { workspace.chat.selectedAgentID.isEmpty ? defaultAgentID : workspace.chat.selectedAgentID }

    var body: some View {
        Group {
            if loading && agents.isEmpty {
                ProgressView("Loading agents…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let failure, agents.isEmpty {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load agents",
                           message: failure, actionTitle: "Try again") { Task { await load() } }
            } else if agents.isEmpty {
                EmptyState(symbol: "person.2", title: "No agents yet",
                           message: "Create one to give the assistant a name and persona.",
                           actionTitle: "New agent") { creating = true }
            } else {
                List {
                    if let failure {
                        Section {
                            Text(failure).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                            Button("Try again") { Task { await load() } }
                        }
                        .listRowBackground(Tok.surface)
                    }
                    Section {
                        ForEach(agents) { agent in row(agent) }
                    } header: {
                        Text("Agents").font(.mission(.subheadline, .medium))
                    } footer: {
                        Text("Chat uses the selected agent. The default agent can't be disabled.")
                            .font(.mission(.footnote))
                    }
                    .listRowBackground(Tok.surface)

                    Section {
                        Button("New agent", systemImage: "plus") { creating = true }
                    }
                    .listRowBackground(Tok.surface)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .background(Tok.background)
        .navigationTitle("Agents")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await load() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task { await load() }
        .sheet(item: $editing) { agent in
            AgentEditorSheet(api: workspace.agentsAPI, agent: agent, isDefault: agent.agentID == defaultAgentID) {
                await load()
            }
        }
        .sheet(isPresented: $creating) {
            AgentEditorSheet(api: workspace.agentsAPI, agent: nil, isDefault: false) {
                await load()
            }
        }
        .confirmationDialog("Disable \(confirmDisable?.displayName ?? "this agent")?",
                            isPresented: Binding(get: { confirmDisable != nil },
                                                 set: { if !$0 { confirmDisable = nil } }),
                            titleVisibility: .visible) {
            if let agent = confirmDisable {
                Button("Disable", role: .destructive) { setStatus(agent, "disabled") }
            }
        } message: {
            Text("Its conversations stay; it no longer appears as an agent to talk to.")
        }
    }

    private func row(_ agent: GatewayAgentsAPI.Agent) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            AvatarBadge(agent: agent)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Space.s) {
                    Text(agent.displayName).font(.mission(.headline, .medium))
                    if agent.agentID == defaultAgentID {
                        Text("Default").font(.missionMono(.caption2)).foregroundStyle(Tok.muted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Tok.raised, in: Capsule())
                    }
                    if agent.status != "active" {
                        Text("Disabled").font(.missionMono(.caption2)).foregroundStyle(Tok.warn)
                    }
                }
                if !agent.description.isEmpty {
                    Text(agent.description).font(.mission(.subheadline)).foregroundStyle(Tok.muted).lineLimit(2)
                }
                if !agent.persona.isEmpty {
                    Text(agent.persona).font(.mission(.caption)).foregroundStyle(Tok.muted).lineLimit(2)
                }
            }
            Spacer(minLength: Space.s)
            if agent.agentID == selectedID {
                Label("In use", systemImage: "checkmark.circle.fill")
                    .font(.mission(.caption, .medium))
                    .foregroundStyle(Tok.accent)
            }
        }
        .padding(.vertical, Space.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            if agent.status == "active" { workspace.chat.setAgent(agent.agentID) }
        }
        .accessibilityAddTraits(agent.status == "active" ? .isButton : [])
        .accessibilityAction {
            if agent.status == "active" { workspace.chat.setAgent(agent.agentID) }
        }
        .contextMenu {
            Button("Use") { workspace.chat.setAgent(agent.agentID) }
                .disabled(agent.status != "active")
            Button("Edit") { editing = agent }
            if agent.agentID != defaultAgentID {
                if agent.status == "active" {
                    Button("Disable", role: .destructive) { confirmDisable = agent }
                } else {
                    Button("Enable") { setStatus(agent, "active") }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(agent.agentID == selectedID ? "In use" : "")
    }

    private func load() async {
        loading = agents.isEmpty
        do {
            agents = try await workspace.agentsAPI.listAgents()
            failure = nil
            await workspace.agents.load()
        } catch let error as GatewayAgentsError {
            failure = Self.message(error)
        } catch {
            failure = "The server couldn't list agents."
        }
        loading = false
    }

    private func setStatus(_ agent: GatewayAgentsAPI.Agent, _ status: String) {
        confirmDisable = nil
        Task {
            do {
                _ = try await workspace.agentsAPI.updateAgent(agent.agentID, status: status)
                if status != "active", agent.agentID == selectedID {
                    workspace.chat.setAgent(ChatStore.defaultAgent)
                }
                await load()
            } catch let error as GatewayAgentsError {
                failure = Self.message(error)
            } catch {
                failure = "The server couldn't update this agent."
            }
        }
    }

    private static func message(_ error: GatewayAgentsError) -> String {
        switch error {
        case .unauthorized: "Sign in again to continue."
        case .server(_, let message): message.isEmpty ? "The server couldn't list agents." : message
        }
    }
}

private struct AvatarBadge: View {
    let agent: GatewayAgentsAPI.Agent

    var body: some View {
        ZStack {
            Circle().fill(Tok.accent.opacity(0.14))
            if let raw = agent.avatarURL, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            } else {
                Text(initials).font(.mission(.callout, .semibold)).foregroundStyle(Tok.accent)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Tok.hairline))
        .accessibilityHidden(true)
    }

    private var initials: String {
        agent.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

private struct AgentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let api: GatewayAgentsAPI
    let agent: GatewayAgentsAPI.Agent?
    let isDefault: Bool
    let onSaved: () async -> Void

    @State private var displayName: String
    @State private var persona: String
    @State private var description: String
    @State private var avatarURL: String
    @State private var status: String
    @State private var saving = false
    @State private var failure: String?

    init(api: GatewayAgentsAPI, agent: GatewayAgentsAPI.Agent?, isDefault: Bool,
         onSaved: @escaping () async -> Void) {
        self.api = api
        self.agent = agent
        self.isDefault = isDefault
        self.onSaved = onSaved
        _displayName = State(initialValue: agent?.displayName ?? "")
        _persona = State(initialValue: agent?.persona ?? "")
        _description = State(initialValue: agent?.description ?? "")
        _avatarURL = State(initialValue: agent?.avatarURL ?? "")
        _status = State(initialValue: agent?.status ?? "active")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent == nil ? "New agent" : "Edit agent")
                        .font(.mission(.title3, .semibold))
                    Text("The display name is what Chat calls it.")
                        .font(.mission(.caption)).foregroundStyle(Tok.muted)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(saving ? "Saving…" : "Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || saving)
            }
            .padding(Space.l)
            Divider()
            Form {
                Section("Name") {
                    TextField("Display name", text: $displayName)
                }
                Section("Persona") {
                    TextEditor(text: $persona)
                        .frame(minHeight: 110)
                    Text("How this agent should sound and what it should care about.")
                        .font(.mission(.caption)).foregroundStyle(Tok.muted)
                }
                Section("Description") {
                    TextField("Shown in the agent list", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Avatar") {
                    TextField("Image URL (optional)", text: $avatarURL)
                }
                if agent != nil {
                    Section("Status") {
                        Toggle("Active", isOn: Binding(
                            get: { status == "active" },
                            set: { status = $0 ? "active" : "disabled" }))
                            .disabled(isDefault)
                        if isDefault {
                            Text("The default agent can't be disabled.")
                                .font(.mission(.caption)).foregroundStyle(Tok.muted)
                        }
                    }
                }
                if let failure {
                    Section {
                        Text(failure).font(.mission(.subheadline)).foregroundStyle(Tok.critical)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(Tok.background)
        .frame(width: 520, height: 580)
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            do {
                if let agent {
                    _ = try await api.updateAgent(
                        agent.agentID, displayName: displayName, persona: persona,
                        description: description,
                        avatarURL: avatarURL.isEmpty ? nil : avatarURL, status: status)
                } else {
                    _ = try await api.createAgent(
                        displayName: displayName, persona: persona, description: description,
                        avatarURL: avatarURL.isEmpty ? nil : avatarURL)
                }
                await onSaved()
                dismiss()
            } catch let error as GatewayAgentsError {
                switch error {
                case .unauthorized: failure = "Sign in again to continue."
                case .server(_, let message): failure = message.isEmpty ? "The server couldn't save this agent." : message
                }
            } catch {
                failure = "The server couldn't save this agent."
            }
        }
    }
}
