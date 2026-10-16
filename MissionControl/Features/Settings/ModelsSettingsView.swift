import SwiftUI

/// Settings > Models — the LLM behind each tier, and the redeploy that applying one starts. Mirrors
/// `agent-web/src/pages/settings/SettingsModels.tsx` against the router's `/llm` endpoints (`ModelsAPI`):
/// edit the tiers, poll the update, re-read once it settles.
struct ModelsSettingsView: View {
    @State private var mode = "custom"
    /// False against a router deployed before the platform/own split: it sends no mode, and would refuse the revert
    /// its PUT implies (unknown fields are ignored, and a tiers-less body then fails validation). No control, no
    /// dead end.
    @State private var supportsModes = false
    @State private var draft: [TierName: TierForm]?
    @State private var loading = true
    @State private var loadError: String?
    @State private var saving = false
    @State private var applying = false
    @State private var applied = false
    @State private var updateError: String?

    private let api = ModelsAPI(
        baseURL: Config.routerBaseURL,
        token: { try await ClerkGatewayAuthentication().sessionToken() }
    )

    /// One tier's edit in progress. `hasKey`/`platform` are the server's; `apiKey` is only ever what was typed
    /// here — the server never returns a key, so blank means "keep the saved one".
    private struct TierForm: Equatable {
        var enabled = false
        var provider = "openai"
        var model = ""
        var baseURL = ""
        var apiKey = ""
        var hasKey = false
        var platform = false

        init() {}

        init(_ view: ModelsAPI.TierView?) {
            provider = view.flatMap { $0.provider.isEmpty ? nil : $0.provider } ?? "openai"
            model = view?.model ?? ""
            baseURL = view?.baseURL ?? ""
            hasKey = view?.hasKey ?? false
            platform = view?.custom == false
            enabled = !model.isEmpty && !platform
        }
    }

    private var busy: Bool { applying || saving }

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading models…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, draft == nil {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load model settings", message: loadError,
                           actionTitle: "Try again") { Task { await load() } }
            } else {
                form
            }
        }
        .screenBackground()
        .navigationTitle("Models").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder private var form: some View {
        Form {
            Section {
                if supportsModes {
                    Picker("Models", selection: $mode) {
                        Text("Use platform models").tag("platform")
                        Text("My own").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(busy)
                }
            } header: {
                Text("Models").font(.mission(.subheadline, .medium))
            } footer: {
                Text(supportsModes
                     ? "The LLM behind each tier. Saving redeploys your workspace's services, which takes about a minute. Leave an API key blank to keep the saved one."
                     : "The LLM behind each tier. Saving redeploys your workspace's services, which takes about a minute. Leave an API key blank to keep the saved one. This server is too old to switch back to the platform's models.")
            }

            if mode == "custom" {
                ForEach(TierName.allCases) { name in tierSection(name) }
            } else {
                Section {
                    ForEach(TierName.allCases) { name in
                        let t = tierForm(name)
                        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(name.title).font(.mission(.headline, .medium)).foregroundStyle(Tok.text)
                                Text(t.model.isEmpty ? name.modelsBlurb : t.model).font(.mission(.caption)).foregroundStyle(Tok.muted)
                            }
                            Spacer(minLength: 0)
                            PlatformBadge()
                        }
                    }
                } header: {
                    Text("Tiers").font(.mission(.subheadline, .medium))
                } footer: {
                    Text("Your workspace uses Mission Control's models. Choose My own to bring your own provider and key.")
                }
            }

            Section {
                Button { Task { await save() } } label: { Text(busy ? "Applying…" : "Save changes") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy || !complete)
                if applying {
                    HStack(spacing: Space.s) {
                        ProgressView().controlSize(.small)
                        Text("Redeploying").font(.missionMono(.caption, .medium)).foregroundStyle(Tok.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
                if let updateError {
                    Label(updateError, systemImage: "xmark.circle").font(.mission(.footnote)).foregroundStyle(Tok.critical)
                } else if applied {
                    Label("Applied", systemImage: "checkmark.circle").font(.mission(.footnote)).foregroundStyle(Tok.muted)
                }
                if let incompleteReason {
                    Text(incompleteReason).font(.mission(.caption)).foregroundStyle(Tok.muted)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder private func tierSection(_ name: TierName) -> some View {
        let t = tierForm(name)
        Section {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.s) {
                        Text(name.title).font(.mission(.headline, .medium)).foregroundStyle(Tok.text)
                        if t.platform { PlatformBadge() }
                    }
                    Text(name.modelsBlurb).font(.mission(.caption)).foregroundStyle(Tok.muted)
                }
                Spacer(minLength: 0)
                Toggle("Use \(name.title)", isOn: field(name, \.enabled, or: false)).labelsHidden().tint(Tok.accent)
            }
            if t.enabled {
                Picker("Provider", selection: field(name, \.provider, or: "openai")) {
                    Text("OpenAI-compatible").tag("openai")
                    Text("Anthropic").tag("anthropic")
                }
                .pickerStyle(.segmented)
                PlainInput(label: "Model", text: field(name, \.model, or: ""),
                           placeholder: t.provider == "anthropic" ? "claude-sonnet-4-5" : "gpt-4o-mini")
                PlainInput(label: "Base URL", text: field(name, \.baseURL, or: ""),
                           placeholder: "https://api.example.com/v1", keyboard: .URL)
                SecretInput(label: "API key", text: field(name, \.apiKey, or: ""))
                if t.hasKey {
                    Text("A key is saved — leave blank to keep it.").font(.mission(.caption)).foregroundStyle(Tok.muted)
                }
            }
        }
        .disabled(busy)
    }

    /// A tier still served by the platform rather than by the person's own provider.
    private struct PlatformBadge: View {
        var body: some View {
            Text("Platform")
                .font(.missionMono(.caption, .medium)).foregroundStyle(Tok.muted)
                .padding(.horizontal, Space.s).frame(minHeight: 24)
                .background(Tok.raised, in: Capsule()).overlay(Capsule().strokeBorder(Tok.hairline))
        }
    }

    private func tierForm(_ name: TierName) -> TierForm { draft?[name] ?? TierForm() }

    /// One tier's field, written back into the loaded draft. Nothing renders before `load()` has filled it.
    private func field<V>(_ name: TierName, _ keyPath: WritableKeyPath<TierForm, V>, or fallback: V) -> Binding<V> {
        Binding(get: { draft?[name]?[keyPath: keyPath] ?? fallback },
                set: { draft?[name]?[keyPath: keyPath] = $0 })
    }

    private var enabledTiers: [(TierName, TierForm)] {
        TierName.allCases.compactMap { name in tierForm(name).enabled ? (name, tierForm(name)) : nil }
    }

    /// What is stopping Save, in the same words the rule is written in — `nil` when the form is ready. The API
    /// rejects the same things with a 400, so this is a courtesy, not the guard.
    private var incompleteReason: String? {
        guard mode == "custom" else { return nil }
        let on = enabledTiers
        if on.isEmpty { return "Enable at least one tier." }
        if on.contains(where: { $0.1.model.trimmed.isEmpty }) { return "Every tier you use needs a model." }
        if on.contains(where: { $0.1.provider == "openai" && $0.1.baseURL.trimmed.isEmpty }) { return "OpenAI-compatible tiers also need a base URL." }
        return nil
    }

    private var complete: Bool { incompleteReason == nil }

    private func load() async {
        loading = draft == nil
        do {
            let models = try await api.tiers()
            supportsModes = models.mode != nil
            mode = models.mode ?? "custom"
            draft = TierName.allCases.reduce(into: [:]) { out, name in out[name] = TierForm(models.tiers[name.rawValue]) }
            loadError = nil
        } catch let error as ModelsError {
            loadError = Self.message(for: error)
        } catch {
            loadError = "The server couldn't read your model settings."
        }
        loading = false
    }

    private func save() async {
        guard draft != nil else { return }
        saving = true
        applied = false
        updateError = nil
        defer { saving = false }
        do {
            let runID = mode == "platform" ? try await api.usePlatform() : try await api.update(tiers: inputs())
            applying = true
            await poll(runID: runID)
        } catch let error as ModelsError {
            updateError = Self.message(for: error)
            applying = false
        } catch {
            updateError = "The server couldn't start the update."
            applying = false
        }
    }

    private func inputs() -> [String: ModelsAPI.TierInput] {
        var out: [String: ModelsAPI.TierInput] = [:]
        for (name, t) in enabledTiers {
            out[name.rawValue] = ModelsAPI.TierInput(provider: t.provider, model: t.model.trimmed, apiKey: t.apiKey.trimmed, baseURL: t.baseURL.trimmed)
        }
        return out
    }

    /// Applying is a helm upgrade (~a minute), so the run's own workflow is polled until it settles — every 3 s,
    /// like the web page's `refetchInterval`, and by the run id the PUT returned so another run's result is never
    /// mistaken for this one. A 404 means nothing has run yet, and no run id at all falls back to the latest run.
    private func poll(runID: String?) async {
        defer { applying = false }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            do {
                guard let status = try await api.updateStatus(runID: runID) else { return }
                switch status.status {
                case "completed":
                    applied = true
                    await load()
                    return
                case "failed":
                    updateError = status.error.flatMap { $0.isEmpty ? nil : $0 } ?? "The update failed"
                    await load()
                    return
                default:
                    continue
                }
            } catch let error as ModelsError {
                // A redeploy restarts the workspace's own services, so a request can drop mid-run: keep polling.
                if case .unauthorized = error { updateError = Self.message(for: error); return }
            } catch {
                continue
            }
        }
    }

    private static func message(for error: ModelsError) -> String {
        switch error {
        case .unauthorized: return "Sign in again to continue."
        case .server(_, let message): return message.isEmpty ? "The server couldn't complete this request." : message
        }
    }
}

private extension TierName {
    /// This screen's own blurbs — the onboarding step phrases the same tiers differently.
    var modelsBlurb: String {
        switch self {
        case .fast: "Quick, cheap calls — routing and short replies."
        case .medium: "The everyday workhorse. Memory retain/reflect also uses this one."
        case .expert: "Hard reasoning and long, multi-step work."
        }
    }
}
