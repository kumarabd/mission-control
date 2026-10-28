import SwiftUI

/// Settings > Connections — the apps and accounts this person's assistant can use. Mirrors
/// `agent-web/src/pages/ExternalConnections.tsx`'s catalog (grouped by status, connect/authorize/disconnect)
/// against the same router `/connections` prefix (`GatewayConnectionsAPI`), reusing the signed-in session token
/// the rest of Settings already authenticates with.
struct ConnectionsSettingsView: View {
    @State private var items: [GatewayConnectionsAPI.CatalogItem] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var detailName: String?
    private var detail: Binding<GatewayConnectionsAPI.CatalogItem?> {
        Binding(get: { items.first { $0.name == detailName } }, set: { detailName = $0?.name })
    }
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
                                Button { detailName = item.name } label: { ConnectionRow(item: item, status: status) }
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
        .navigationTitle("Connections").inlineNavigationTitle()
        .task { await load() }
        .task { await pollWhileVisible() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
        .sheet(item: detail) { item in
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

/// Backends that ship their own iOS app reuse that app's name and icon (asset `Conn*`).
private extension GatewayConnectionsAPI.CatalogItem {
    var brand: (name: String, asset: String)? {
        switch name {
        case "maps-engine": return ("Garage", "ConnGarage")
        case "finance": return ("Treasure", "ConnTreasure")
        case "retro": return ("Retro", "ConnRetro")
        default: return nil
        }
    }
    var shownName: String { brand?.name ?? displayName }
}

private struct ConnectionIcon: View {
    let item: GatewayConnectionsAPI.CatalogItem
    let symbol: String
    var body: some View {
        if let asset = item.brand?.asset {
            Image(asset).resizable().frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(systemName: symbol).font(.mission(.body)).foregroundStyle(Tok.accent)
                .frame(width: 32, height: 32).background(Tok.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
                ConnectionIcon(item: item, symbol: symbol)
                if item.origin == "in-house" {
                    Image(systemName: "house.fill").font(.system(size: 8)).foregroundStyle(Tok.muted)
                        .padding(2).background(Tok.surface, in: Circle()).offset(x: 3, y: 3)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.shownName).font(.mission(.headline, .medium)).foregroundStyle(Tok.text)
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
                            .disabled(busy).plainTextInput()
                        SecureField(item.connected ? "Client secret (leave blank to reuse saved)" : "Client secret", text: $clientSecret)
                            .disabled(busy)
                        TextField("Scopes (optional, space-separated)", text: $scopes)
                            .disabled(busy).plainTextInput()
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
            .navigationTitle(item.shownName).inlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .confirmationDialog("Disconnect \(item.shownName)? Your assistant will lose access to its tools. Provider access is not revoked.",
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
            try await api.connect(name: item.name, secrets: secrets)
            if item.authKind == "oauth" && !isMachineOAuth {
                // Browser OAuth: hand off right away instead of leaving the item in "Needs attention".
                // mcp-hub flips to needs_authorization asynchronously, so retry briefly.
                var url: URL?
                for _ in 0..<6 where url == nil {
                    url = try? await api.authorize(name: item.name)
                    if url == nil { try? await Task.sleep(for: .seconds(1)) }
                }
                await onChanged()
                if let url { openURL(url); dismiss() }
                else { error = "Connected, but authorization isn't ready yet. Tap Authorize in a moment." }
                return
            }
            await onChanged()
            dismiss()
        } catch let gatewayError as GatewayConnectionsError {
            error = ConnectionsSettingsView.message(for: gatewayError)
        } catch {
            self.error = "The connection could not be saved. Check your access and try again."; await onChanged()
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
            self.error = "Authorization is not available yet. Try again."; await onChanged()
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
            self.error = "The connection could not be removed. Try again."; await onChanged()
        }
    }
}
