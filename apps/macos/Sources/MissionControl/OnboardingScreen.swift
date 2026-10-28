import ClerkKit
import SwiftUI

/// A first sign-in with no workspace yet. Same router onboarding and the
/// same generated credentials as the phone; the desktop gets one dense form.
struct OnboardingScreen: View {
    let userId: String
    let onDone: () async -> Void

    @State private var model: OnboardingModel
    @State private var watching = false

    init(userId: String, onDone: @escaping () async -> Void) {
        self.userId = userId
        self.onDone = onDone
        _model = State(initialValue: OnboardingModel(
            api: LiveOnboardingAPI(token: { try? await Clerk.shared.auth.getToken() }),
            owner: userId))
    }

    var body: some View {
        @Bindable var model = model
        ZStack {
            Tok.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header
                    switch model.phase {
                    case .form:
                        form(model: model)
                    case .provisioning:
                        provisioning
                    case .done:
                        ProgressView("Opening your workspace…")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    case .failed(let message):
                        failure(message)
                    }
                }
                .padding(Space.xl)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: model.phase) { _, phase in
            guard phase == .provisioning, !watching else { return }
            watching = true
            Task {
                await model.watch()
                watching = false
                if model.phase == .done { await onDone() }
            }
        }
        .onAppear {
            if model.phase == .provisioning && !watching {
                watching = true
                Task {
                    await model.watch()
                    watching = false
                    if model.phase == .done { await onDone() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            AssistantGlyph(size: 64)
            Text("Set up your workspace").font(.mission(.largeTitle, .semibold))
            Text("Your assistant gets a private workspace of its own: a database, memory, and the services its tools run against. This takes about a minute.")
                .font(.mission(.body)).foregroundStyle(Tok.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func form(model: OnboardingModel) -> some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: Space.l) {
            MissionCard {
                VStack(alignment: .leading, spacing: Space.m) {
                    Text("Intelligence").font(.mission(.headline, .medium))
                    Picker("Models", selection: $model.intelligence) {
                        Text("Use Mission Control's models").tag(IntelligenceChoice.platform)
                        Text("Bring my own").tag(IntelligenceChoice.own)
                    }
                    .pickerStyle(.segmented)
                    if model.intelligence == .own {
                        ForEach(TierName.allCases) { name in
                            tierRow(model: model, name: name)
                        }
                    }
                }
            }

            MissionCard {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: Space.s) {
                        ForEach(model.secrets.all, id: \.name) { secret in
                            LabeledContent(secret.name) {
                                Text(secret.value)
                                    .font(.missionMono(.caption))
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Button("Generate new values") {
                            model.secrets = SecretsDraft()
                        }
                        Text("Generated on this Mac with the system's secure random source and sent once to your router. Keep them if you ever need to recover the workspace.")
                            .font(.mission(.caption)).foregroundStyle(Tok.muted)
                    }
                    .padding(.top, Space.s)
                } label: {
                    Label("Workspace credentials", systemImage: "key")
                        .font(.mission(.headline, .medium))
                }
            }

            if let error = model.submitError {
                Text(error).font(.mission(.subheadline)).foregroundStyle(Tok.critical)
            }

            HStack {
                Text("You can change models and connections later in Settings.")
                    .font(.mission(.caption)).foregroundStyle(Tok.muted)
                Spacer()
                Button(model.submitting ? "Starting…" : "Create my workspace") {
                    Task { await model.submit() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canSubmit)
            }
        }
    }

    private func tierRow(model: OnboardingModel, name: TierName) -> some View {
        let value = Binding<TierDraft>(
            get: { model.tiers[name] ?? TierDraft() },
            set: { model.tiers[name] = $0 })
        return VStack(alignment: .leading, spacing: Space.s) {
            Toggle(name.title, isOn: Binding(get: { value.wrappedValue.enabled },
                                             set: { value.wrappedValue.enabled = $0 }))
            Text(name.blurb).font(.mission(.caption)).foregroundStyle(Tok.muted)
            if value.wrappedValue.enabled {
                Picker("Provider", selection: Binding(
                    get: { value.wrappedValue.anthropic ? "anthropic" : "openai" },
                    set: { value.wrappedValue.anthropic = $0 == "anthropic" })) {
                    Text("OpenAI-compatible").tag("openai")
                    Text("Anthropic").tag("anthropic")
                }
                TextField("Model", text: Binding(get: { value.wrappedValue.model },
                                                 set: { value.wrappedValue.model = $0 }))
                    .textFieldStyle(.roundedBorder)
                SecretInput(label: "API key", text: Binding(get: { value.wrappedValue.apiKey },
                                                            set: { value.wrappedValue.apiKey = $0 }))
                if value.wrappedValue.needsBaseURL {
                    TextField("Base URL", text: Binding(get: { value.wrappedValue.baseURL },
                                                       set: { value.wrappedValue.baseURL = $0 }))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(.vertical, Space.s)
    }

    private var provisioning: some View {
        MissionCard {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.s) {
                    ProgressView().controlSize(.small)
                    Text("Building your workspace").font(.mission(.headline, .medium))
                }
                if let progress = model.progress {
                    ProgressView(value: progress.fraction)
                    ForEach(progress.steps) { step in
                        HStack(spacing: Space.s) {
                            Image(systemName: step.status == "done" ? "checkmark.circle.fill"
                                  : step.status == "failed" ? "xmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(step.status == "done" ? Tok.accent
                                                 : step.status == "failed" ? Tok.critical : Tok.muted)
                            Text(OnboardingProgress.labels[step.step] ?? step.step)
                                .font(.mission(.subheadline))
                            Spacer()
                            if let message = step.message, !message.isEmpty {
                                Text(message).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                            }
                        }
                    }
                } else {
                    Text("Waiting for the router to accept the request…")
                        .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                }
            }
        }
    }

    private func failure(_ message: String) -> some View {
        MissionCard {
            VStack(alignment: .leading, spacing: Space.m) {
                Label("Setup didn't finish", systemImage: "exclamationmark.triangle.fill")
                    .font(.mission(.headline, .medium))
                    .foregroundStyle(Tok.critical)
                Text(message).font(.mission(.body))
                Button("Start over") { model.startOver() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
