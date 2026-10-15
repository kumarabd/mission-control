import SwiftUI

/// Settings > Connections — the apps and accounts this person's assistant can use. Mirrors
/// `agent-web/src/pages/ExternalConnections.tsx`'s catalog (grouped by status, connect/authorize/disconnect)
/// against the same router `/connections` prefix (`GatewayConnectionsAPI`), reusing the signed-in session token
/// the rest of Settings already authenticates with.
struct ConnectionsSettingsView: View {
    @State private var items: [GatewayConnectionsAPI.CatalogItem] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var detail: GatewayConnectionsAPI.CatalogItem?
    @Environment(\.scenePhase) private var scenePhase

    private let api = GatewayConnectionsAPI(
        baseURL: Config.routerBaseURL + "/connections",
        token: { try await ClerkGatewayAuthentication().sessionToken() }
    )

    fileprivate enum Status: String, CaseIterable, Hashable { case needsAttention = "Needs attention", processing = "Processing", connected = "Connected", available = "Available" }

    private func status(for item: GatewayConnectionsAPI.CatalogItem) -> Status {
        if item.state == "failed" { return .needsAttention }
        if item.state == "needs_authorization" { return .needsAttention }
        if item.connected && item.state == "ready" { return .connected }
        return (item.connected || item.state == "indexing") ? .processing : .available
    }

    private var groups: [(Status, [GatewayConnectionsAPI.CatalogItem])] {
        Status.allCases.compactMap { s in
            let matching = items.filter { status(for: $0) == s }
            return matching.isEmpty ? nil : (s, matching)
        }
    }

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading connections…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, items.isEmpty {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load connections", message: loadError,
                           actionTitle: "Try again") { Task { await load() } }
            } else if items.isEmpty {
                EmptyState(symbol: "link", title: "No connections available yet",
                            message: "Reviewed integrations will appear here when they are enabled for your workspace.")
            } else {
                List {
                    ForEach(groups, id: \.0) { status, groupItems in
                        Section {
                            ForEach(groupItems) { item in
                                Button { detail = item } label: { ConnectionRow(item: item, status: status) }
                                    .buttonStyle(.plain)
                            }
                        } header: { Text(status.rawValue).font(.mission(.subheadline, .medium)) }
                        .listRowBackground(Tok.surface)
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .screenBackground()
        .navigationTitle("Connections").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task { await pollWhileVisible() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
        .sheet(item: $detail) { item in
            ConnectionDetailSheet(api: api, item: item, status: status(for: item)) { await load() }
        }
    }

    private func load() async {
        loading = items.isEmpty
        do {
            items = try await api.listCatalog()
            loadError = nil
        } catch let error as GatewayConnectionsError {
            loadError = Self.message(for: error)
        } catch {
            loadError = "The server couldn't list connections."
        }
        loading = false
    }

    /// Mirrors the web page's `refetchInterval: 5000` — connecting/authorizing is asynchronous server-side
    /// (mcp-hub indexes a new backend, or an OAuth callback lands out of band), so the list needs to notice on
    /// its own rather than wait for a pull-to-refresh.
    private func pollWhileVisible() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { return }
            await load()
        }
    }

    fileprivate static func message(for error: GatewayConnectionsError) -> String {
        switch error {
        case .unauthorized: return "Sign in again to continue."
        case .server(_, let message): return message.isEmpty ? "The server couldn't complete this request." : message
        }
    }
}

private struct ConnectionRow: View {
    let item: GatewayConnectionsAPI.CatalogItem
    let status: ConnectionsSettingsView.Status

    private var symbol: String {
        let name = (item.name + " " + item.displayName).lowercased()
        if name.contains("github") { return "chevron.left.forwardslash.chevron.right" }
        if name.contains("calendar") { return "calendar" }
        if name.contains("notion") || name.contains("docs") { return "doc.text" }
        if name.contains("database") || name.contains("snowflake") { return "cylinder" }
        if name.contains("grafana") || name.contains("metric") { return "chart.line.uptrend.xyaxis" }
        if name.contains("cloud") || name.contains("drive") { return "cloud" }
        if item.authKind == "oauth" { return "checkmark.shield" }
        if item.authKind == "header" { return "key" }
        return "puzzlepiece.extension"
    }

    private var tone: Color {
        switch status {
        case .available: return Tok.muted
        case .processing: return Tok.accent
        case .connected: return Tok.live
        case .needsAttention: return item.state == "failed" ? Tok.critical : Tok.warn
        }
    }

    private var label: String {
        switch status {
        case .available: return "Not connected"
        case .processing: return "Processing"
        case .connected: return "\(item.toolCount ?? 0) tools"
        case .needsAttention: return item.state == "failed" ? "Needs attention" : "Authorization needed"
        }
    }

    var body: some View {
        HStack(spacing: Space.m) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: symbol).font(.mission(.body)).foregroundStyle(Tok.accent)
                    .frame(width: 32, height: 32).background(Tok.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                if item.origin == "in-house" {
                    Image(systemName: "house.fill").font(.system(size: 8)).foregroundStyle(Tok.muted)
                        .padding(2).background(Tok.surface, in: Circle()).offset(x: 3, y: 3)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.mission(.headline, .medium)).foregroundStyle(Tok.text)
                HStack(spacing: Space.xs) {
                    Circle().fill(tone).frame(width: 6, height: 6)
                    Text(label).font(.mission(.caption)).foregroundStyle(Tok.muted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.mission(.caption)).foregroundStyle(Tok.muted)
        }
        .padding(.vertical, Space.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Connect/authorize/disconnect one catalog entry. OAuth `authorization_code` backends hand off to the system
/// browser (`openURL`) — same as the web page's popup — and the list's own 5s poll notices once mcp-hub's
/// callback has run; there is no in-app redirect to catch.
private struct ConnectionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let api: GatewayConnectionsAPI
    let item: GatewayConnectionsAPI.CatalogItem
    let status: ConnectionsSettingsView.Status
    let onChanged: () async -> Void

    @State private var token = ""
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var scopes = ""
    @State private var busy = false
    @State private var error: String?
    @State private var confirmingDisconnect = false

    private var isMachineOAuth: Bool { item.authKind == "oauth" && item.oauthGrantType == "client_credentials" }
    private var needsToken: Bool { item.authKind == "header" && (status == .available || (status == .needsAttention && item.state == "failed")) }
    private var needsClientCredentials: Bool { isMachineOAuth && (status == .available || (status == .needsAttention && item.state == "failed")) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Status") { Text(statusText) }
                    Text(statusCopy).font(.mission(.caption)).foregroundStyle(Tok.muted)
                } header: { Text(item.description.isEmpty ? "" : item.description) }

                if needsToken {
                    Section("Access token") {
                        SecureField(item.connected ? "Leave blank to reuse the saved value" : "Required", text: $token)
                            .disabled(busy)
                        Text("Use a token restricted to only what your assistant needs.").font(.mission(.caption)).foregroundStyle(Tok.muted)
                    }
                }
                if needsClientCredentials {
                    Section("Client credentials") {
                        TextField(item.connected ? "Client ID (leave blank to reuse saved)" : "Client ID", text: $clientID)
                            .disabled(busy).autocorrectionDisabled().textInputAutocapitalization(.never)
                        SecureField(item.connected ? "Client secret (leave blank to reuse saved)" : "Client secret", text: $clientSecret)
                            .disabled(busy)
                        TextField("Scopes (optional, space-separated)", text: $scopes)
                            .disabled(busy).autocorrectionDisabled().textInputAutocapitalization(.never)
                    }
                }
                if let error { Section { Text(error).foregroundStyle(Tok.critical) } }

                Section {
                    switch status {
                    case .needsAttention where item.state == "needs_authorization":
                        Button(busy ? "Opening…" : "Authorize") { Task { await authorize() } }.disabled(busy)
                    case .needsAttention, .available:
                        let disabled = busy || (needsToken && !item.connected && token.isEmpty) || (needsClientCredentials && !item.connected && (clientID.isEmpty || clientSecret.isEmpty))
                        Button(status == .needsAttention ? "Retry connection" : "Connect") { Task { await connect() } }.disabled(disabled)
                    case .processing, .connected:
                        EmptyView()
                    }
                    if item.connected {
                        Button("Disconnect", role: .destructive) { confirmingDisconnect = true }.disabled(busy)
                    }
                }
            }
            .navigationTitle(item.displayName).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .confirmationDialog("Disconnect \(item.displayName)? Your assistant will lose access to its tools. Provider access is not revoked.",
                                 isPresented: $confirmingDisconnect, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) { Task { await disconnect() } }
            }
        }
    }

    private var statusText: String {
        switch status {
        case .available: return "Not connected"
        case .processing: return "Processing"
        case .connected: return "Connected"
        case .needsAttention: return item.state == "failed" ? "Needs attention" : "Authorization needed"
        }
    }

    private var statusCopy: String {
        switch status {
        case .connected: return "\(item.toolCount ?? 0) tools are ready for your assistant."
        case .processing: return "We are establishing the connection and discovering its available tools. This may take a moment."
        case .needsAttention: return item.state == "failed"
            ? "We could not reach this system. Check access, then retry the connection."
            : "Finish authorization in your browser. This connection will update automatically when access is ready."
        case .available: return item.authKind == "none"
            ? "Connect it when you are ready to let your assistant use it."
            : "Connect it securely. Credentials stay scoped to your workspace."
        }
    }

    private func connect() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            let secrets = GatewayConnectionsAPI.ConnectSecrets(
                token: token.trimmingCharacters(in: .whitespaces),
                oauthClientID: isMachineOAuth ? clientID.trimmingCharacters(in: .whitespaces) : nil,
                oauthClientSecret: isMachineOAuth ? clientSecret.trimmingCharacters(in: .whitespaces) : nil,
                oauthScopes: isMachineOAuth ? scopes.trimmingCharacters(in: .whitespaces) : nil
            )
            _ = try await api.connect(name: item.name, secrets: secrets)
            await onChanged()
            dismiss()
        } catch let gatewayError as GatewayConnectionsError {
            error = ConnectionsSettingsView.message(for: gatewayError)
        } catch {
            self.error = "The connection could not be saved. Check your access and try again."
        }
    }

    private func authorize() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            let url = try await api.authorize(name: item.name)
            openURL(url)
            dismiss()
        } catch let gatewayError as GatewayConnectionsError {
            error = ConnectionsSettingsView.message(for: gatewayError)
        } catch {
            self.error = "Authorization is not available yet. Try again."
        }
    }

    private func disconnect() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            try await api.disconnect(name: item.name)
            await onChanged()
            dismiss()
        } catch let gatewayError as GatewayConnectionsError {
            error = ConnectionsSettingsView.message(for: gatewayError)
        } catch {
            self.error = "The connection could not be removed. Try again."
        }
    }
}
