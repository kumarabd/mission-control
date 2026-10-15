import SwiftUI

/// Settings > Agents — lists the gateway's agent registry (`gateway/internal/agents`), lets a person pick which
/// agent this device's conversation addresses (`MobileGateway`'s auth frame), and create/edit one's profile.
struct AgentsSettingsView: View {
    @AppStorage("gateway.ios.selectedAgentID") private var selectedAgentID = ""
    @State private var agents: [GatewayAgentsAPI.Agent] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var editing: GatewayAgentsAPI.Agent?
    @State private var creating = false

    /// The id every pre-existing conversation already addresses (`core.DefaultAgentID` on the server) — not
    /// discoverable from the API, so mirrored here as the one literal this app and the gateway must agree on.
    private let defaultAgentID = "main"

    private let api = GatewayAgentsAPI(
        baseURL: Config.routerBaseURL + "/gateway",
        token: { try await ClerkGatewayAuthentication().sessionToken() }
    )

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading agents…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, agents.isEmpty {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load agents", message: loadError,
                           actionTitle: "Try again") { Task { await load() } }
            } else {
                List {
                    Section {
                        ForEach(agents) { agent in
                            let isSelected = agent.agentID == selectedAgentID || (selectedAgentID.isEmpty && agent.agentID == defaultAgentID)
                            AgentRow(agent: agent, isSelected: isSelected) {
                                selectedAgentID = agent.agentID == defaultAgentID ? "" : agent.agentID
                            }
                            .swipeActions { Button("Edit") { editing = agent } }
                        }
                    } header: { Text("Agents").font(.mission(.subheadline, .medium)) }
                    .listRowBackground(Tok.surface)

                    Section {
                        Button("New Agent") { creating = true }
                    }
                    .listRowBackground(Tok.surface)
                }
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .screenBackground()
        .navigationTitle("Agents").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $editing) { agent in AgentEditSheet(api: api, agent: agent, isDefault: agent.agentID == defaultAgentID) { await load() } }
        .sheet(isPresented: $creating) { AgentEditSheet(api: api, agent: nil, isDefault: false) { await load() } }
    }

    private func load() async {
        loading = agents.isEmpty
        do {
            agents = try await api.listAgents()
            loadError = nil
        } catch let gatewayError as GatewayAgentsError {
            loadError = Self.message(for: gatewayError, fallback: "The server couldn't list agents.")
        } catch {
            loadError = "The server couldn't list agents."
        }
        loading = false
    }

    fileprivate static func message(for error: GatewayAgentsError, fallback: String) -> String {
        switch error {
        case .unauthorized: return "Sign in again to continue."
        case .server(_, let message): return message.isEmpty ? fallback : message
        }
    }
}

private struct AgentRow: View {
    let agent: GatewayAgentsAPI.Agent
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(agent.displayName).font(.mission(.headline, .medium)).foregroundStyle(Tok.text)
                    Text(agent.status == "active" ? "Active" : "Disabled")
                        .font(.mission(.caption)).foregroundStyle(agent.status == "active" ? Tok.accent : Tok.muted)
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark").foregroundStyle(Tok.accent) }
            }
            .padding(.vertical, Space.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// Create (agent == nil) or edit (agent != nil) one agent's profile.
private struct AgentEditSheet: View {
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
    @State private var error: String?

    init(api: GatewayAgentsAPI, agent: GatewayAgentsAPI.Agent?, isDefault: Bool, onSaved: @escaping () async -> Void) {
        self.api = api; self.agent = agent; self.isDefault = isDefault; self.onSaved = onSaved
        _displayName = State(initialValue: agent?.displayName ?? "")
        _persona = State(initialValue: agent?.persona ?? "")
        _description = State(initialValue: agent?.description ?? "")
        _avatarURL = State(initialValue: agent?.avatarURL ?? "")
        _status = State(initialValue: agent?.status ?? "active")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Display name", text: $displayName) }
                Section("Persona") {
                    TextEditor(text: $persona).frame(minHeight: 120)
                }
                Section("Description") { TextField("Shown in the agent list", text: $description, axis: .vertical) }
                Section("Avatar") { TextField("Image URL (optional)", text: $avatarURL) }
                if agent != nil {
                    Section {
                        Toggle("Active", isOn: Binding(get: { status == "active" }, set: { status = $0 ? "active" : "disabled" }))
                            .disabled(isDefault)
                        if isDefault { Text("The default agent can't be disabled.").font(.mission(.caption)).foregroundStyle(Tok.muted) }
                    }
                }
                if let error { Text(error).foregroundStyle(Tok.critical) }
            }
            .navigationTitle(agent == nil ? "New Agent" : "Edit Agent").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            if let agent {
                _ = try await api.updateAgent(
                    agent.agentID, displayName: displayName, persona: persona, description: description,
                    avatarURL: avatarURL.isEmpty ? nil : avatarURL, status: status
                )
            } else {
                _ = try await api.createAgent(displayName: displayName, persona: persona, description: description, avatarURL: avatarURL.isEmpty ? nil : avatarURL)
            }
            await onSaved()
            dismiss()
        } catch let gatewayError as GatewayAgentsError {
            self.error = AgentsSettingsView.message(for: gatewayError, fallback: "The server couldn't save this agent.")
        } catch {
            self.error = "The server couldn't save this agent."
        }
    }
}
