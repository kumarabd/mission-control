import SwiftUI

// MARK: Shapes

/// The Mission Control gem, drawn as outline so it can trace itself in and fill as setup progresses.
struct GemShape: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x / 150, y: r.minY + r.height * y / 100) }
        var path = Path()
        path.move(to: p(30, 0)); path.addLine(to: p(120, 0)); path.addLine(to: p(150, 40)); path.addLine(to: p(75, 100)); path.addLine(to: p(0, 40)); path.closeSubpath()
        path.move(to: p(0, 40)); path.addLine(to: p(150, 40))
        path.move(to: p(60, 0)); path.addLine(to: p(45, 40)); path.addLine(to: p(75, 100))
        path.move(to: p(90, 0)); path.addLine(to: p(105, 40)); path.addLine(to: p(75, 100))
        path.move(to: p(45, 40)); path.addLine(to: p(105, 40))
        return path
    }
}

/// The gem as a filled, faceted solid. `fill` (0...1) rises from the bottom, like liquid, as setup advances.
struct GemView: View {
    var fill: Double = 1
    var trace: Double = 1
    var body: some View {
        ZStack {
            GemShape().stroke(Tok.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            GemShape().trim(from: 0, to: trace).stroke(Tok.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            LinearGradient(colors: [Color(light: 0x7C9A5F, dark: 0xD2E8B5), Tok.accent, Color(light: 0x34491F, dark: 0x7C9A5F)], startPoint: .top, endPoint: .bottom)
                .mask(GemSilhouette())
                .mask(alignment: .bottom) { GeometryReader { g in Rectangle().frame(height: g.size.height * fill).frame(maxHeight: .infinity, alignment: .bottom) } }
                .opacity(0.9)
        }
        .aspectRatio(1.5, contentMode: .fit)
    }
}
private struct GemSilhouette: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x / 150, y: r.minY + r.height * y / 100) }
        var path = Path(); path.move(to: p(30, 0)); path.addLine(to: p(120, 0)); path.addLine(to: p(150, 40)); path.addLine(to: p(75, 100)); path.addLine(to: p(0, 40)); path.closeSubpath()
        return path
    }
}

// MARK: Flow

/// Shown after sign-in when the account has no workspace yet. Everything is collected here, a step at a time, then built.
struct OnboardingFlow: View {
    @State var model: OnboardingModel
    var onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Tok.background.ignoresSafeArea()
            AmbientBackdrop().ignoresSafeArea()
            switch model.phase {
            case .form: FormShell(model: model)
            case .provisioning, .failed, .done: ProvisioningView(model: model, onFinished: onFinished)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: model.phase)
    }
}

/// Slow drifting brass light and a few outlines behind everything, so the setup feels like a place and not a form.
private struct AmbientBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle().fill(Tok.accent.opacity(0.16)).frame(width: 340).blur(radius: 70).offset(x: 120 + 22 * sin(t / 5), y: -240 + 18 * cos(t / 6))
                Circle().fill(Color.blue.opacity(0.08)).frame(width: 300).blur(radius: 70).offset(x: -140 + 20 * cos(t / 7), y: 260 + 16 * sin(t / 5))
                Circle().stroke(Tok.accent.opacity(0.18), lineWidth: 1).frame(width: 300).offset(x: 150, y: -160 + 10 * sin(t / 4))
                RoundedRectangle(cornerRadius: 10).stroke(Tok.accent.opacity(0.14), lineWidth: 1).frame(width: 70, height: 70)
                    .rotationEffect(.degrees(45 + 6 * sin(t / 6))).offset(x: -150, y: 150 + 12 * cos(t / 5))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FormShell: View {
    @Bindable var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if model.step != .welcome { ProgressHeader(model: model).transition(.opacity.combined(with: .move(edge: .top))) }
            ZStack {
                stepView
                    .id(model.step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: model.forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: model.forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            footer
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.12), value: model.step)
        .sensoryFeedback(.selection, trigger: model.step)
    }

    @ViewBuilder private var stepView: some View {
        switch model.step {
        case .welcome: WelcomeStep()
        case .intelligence: IntelligenceStep(model: model)
        case .security: SecurityStep(model: model)
        case .memory: MemoryStep(model: model)
        case .review: ReviewStep(model: model)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let e = model.submitError { Text(e).font(.callout).foregroundStyle(Tok.critical).multilineTextAlignment(.center) }
            HStack(spacing: 12) {
                if model.step != .welcome {
                    Button { model.back() } label: { Image(systemName: "chevron.left").font(.headline).frame(width: 52, height: 52) }
                        .background(Tok.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).foregroundStyle(Tok.text)
                        .accessibilityLabel("Back").transition(.scale.combined(with: .opacity))
                }
                Button {
                    if model.step == .review { Task { await model.submit() } } else { model.next() }
                } label: {
                    HStack(spacing: 8) {
                        if model.submitting { ProgressView().tint(Tok.onAccent) }
                        Text(model.step == .welcome ? "Get started" : model.step == .review ? "Create my workspace" : "Continue")
                        if model.step != .review && !model.submitting { Image(systemName: "arrow.right") }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.step == .review ? !model.canSubmit : !model.canContinue(model.step))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

private struct ProgressHeader: View {
    var model: OnboardingModel
    private var steps: [OnboardingStep] { OnboardingStep.allCases.filter { $0 != .welcome } }
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(steps) { s in
                    Button { if s.rawValue <= model.step.rawValue { model.jump(to: s) } } label: {
                        ZStack(alignment: .leading) {
                            Capsule().fill(Tok.raised)
                            Capsule().fill(Tok.accent).scaleEffect(x: s.rawValue <= model.step.rawValue ? 1 : 0, anchor: .leading)
                        }
                        .frame(height: 5).frame(minHeight: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(s.rawValue > model.step.rawValue)
                    .accessibilityLabel(s.title).accessibilityAddTraits(s == model.step ? .isSelected : [])
                }
            }
            .animation(.spring(duration: 0.5, bounce: 0.1), value: model.step)
            HStack {
                Image(systemName: model.step.symbol).foregroundStyle(Tok.accent).symbolEffect(.bounce, value: model.step)
                Text(model.step.title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(model.step.rawValue) of \(steps.count)").font(.footnote).foregroundStyle(Tok.muted).monospacedDigit()
            }
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }
}

// MARK: Step chrome

private struct StepScroll<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.system(size: 34, weight: .bold)).tracking(-0.8)
                    Text(subtitle).font(.body).foregroundStyle(Tok.muted).fixedSize(horizontal: false, vertical: true)
                }
                .opacity(shown || reduceMotion ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 14)
                content
                    .opacity(shown || reduceMotion ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 20)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.1).delay(0.08)) { shown = true } }
    }
}

private struct Card<Content: View>: View {
    var selected = false
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Tok.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(selected ? Tok.accent : Tok.hairline, lineWidth: selected ? 2 : 1))
            .shadow(color: selected ? Tok.accent.opacity(0.25) : .clear, radius: 16, y: 6)
            .animation(.spring(duration: 0.4, bounce: 0.15), value: selected)
    }
}

private struct SecretInput: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    @State private var reveal = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote.weight(.medium)).foregroundStyle(Tok.muted)
            HStack {
                Group { if reveal { TextField(placeholder, text: $text) } else { SecureField(placeholder, text: $text) } }
                    .textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.password)
                Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(Tok.muted).frame(width: 36, height: 36) }
                    .accessibilityLabel(reveal ? "Hide" : "Show")
            }.field()
        }
    }
}

private struct PlainInput: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote.weight(.medium)).foregroundStyle(Tok.muted)
            TextField(placeholder, text: $text).keyboardType(keyboard).textInputAutocapitalization(.never).autocorrectionDisabled().field()
        }
    }
}

// MARK: Steps

private struct WelcomeStep: View {
    @State private var trace = 0.0
    @State private var fill = 0.0
    @State private var rows = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let points = [("lock.shield", "Private by design", "Your workspace is yours alone, with its own database."),
                          ("slider.horizontal.3", "Set up once", "A few choices now, and Mission Control does the rest."),
                          ("clock", "About a minute", "We build it while you watch, then you're in.")]
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)
            GemView(fill: fill, trace: trace).frame(width: 190)
                .phaseAnimator([0.0, 1.0]) { v, p in v.offset(y: reduceMotion ? 0 : -6 * p) } animation: { _ in .easeInOut(duration: 2.4) }
            VStack(spacing: 10) {
                Text("Let's build your\nprivate workspace").font(.system(size: 34, weight: .bold)).tracking(-0.8).multilineTextAlignment(.center)
                Text("Mission Control keeps your goals, plans and journal in a space only you can open.").foregroundStyle(Tok.muted).multilineTextAlignment(.center).padding(.horizontal, 12)
            }
            .padding(.horizontal, 28)
            VStack(spacing: 12) {
                ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                    HStack(spacing: 14) {
                        Image(systemName: p.0).font(.title3).foregroundStyle(Tok.accent).frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) { Text(p.1).font(.subheadline.weight(.semibold)); Text(p.2).font(.footnote).foregroundStyle(Tok.muted) }
                        Spacer(minLength: 0)
                    }
                    .opacity(rows > i || reduceMotion ? 1 : 0).offset(x: rows > i || reduceMotion ? 0 : 24)
                }
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 0)
        }
        .onAppear {
            if reduceMotion { trace = 1; fill = 1; rows = 3; return }
            withAnimation(.easeOut(duration: 1.4)) { trace = 1 }
            withAnimation(.easeInOut(duration: 1.2).delay(1.0)) { fill = 1 }
            for i in 1...3 { withAnimation(.spring(duration: 0.6, bounce: 0.15).delay(0.9 + Double(i) * 0.18)) { rows = i } }
        }
    }
}

private struct ChoiceCard: View {
    let symbol: String
    let title: String
    let detail: String
    var badge: String?
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Card(selected: selected) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: symbol).font(.title2).foregroundStyle(selected ? Tok.accent : Tok.muted).frame(width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(title).font(.headline).foregroundStyle(Tok.text)
                            if let badge { Text(badge).font(.caption2.weight(.bold)).padding(.horizontal, 7).padding(.vertical, 3).background(Tok.accent.opacity(0.18), in: Capsule()).foregroundStyle(Tok.accent) }
                        }
                        Text(detail).font(.subheadline).foregroundStyle(Tok.muted).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(selected ? Tok.accent : Tok.hairline)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct IntelligenceStep: View {
    @Bindable var model: OnboardingModel
    var body: some View {
        StepScroll(title: "Intelligence", subtitle: "Choose the models that power your workspace's assistant features. Your receipts and statements are always read on this phone, never by a model.") {
            VStack(spacing: 12) {
                ChoiceCard(symbol: "sparkles", title: "Mission Control's models", detail: "Works out of the box. Nothing to set up.", badge: "RECOMMENDED", selected: model.intelligence == .platform) { model.intelligence = .platform }
                ChoiceCard(symbol: "key.horizontal", title: "Bring my own", detail: "Use your own provider and API key.", selected: model.intelligence == .own) { model.intelligence = .own }
            }
            if model.intelligence == .own {
                VStack(spacing: 12) {
                    ForEach(TierName.allCases) { name in TierCard(name: name, tier: Binding(get: { model.tiers[name] ?? .init() }, set: { model.tiers[name] = $0 })) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.12), value: model.intelligence)
    }
}

private struct TierCard: View {
    let name: TierName
    @Binding var tier: TierDraft
    var body: some View {
        Card(selected: tier.enabled && name != .medium) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) { Text(name.title).font(.headline); Text(name.blurb).font(.footnote).foregroundStyle(Tok.muted) }
                    Spacer()
                    if name == .medium { Text("Required").font(.caption.weight(.semibold)).foregroundStyle(Tok.accent) }
                    else { Toggle("", isOn: $tier.enabled).labelsHidden().tint(Tok.accent) }
                }
                if tier.enabled {
                    Picker("Provider", selection: $tier.anthropic) { Text("OpenAI-compatible").tag(false); Text("Anthropic").tag(true) }.pickerStyle(.segmented)
                    PlainInput(label: "Model", text: $tier.model, placeholder: tier.anthropic ? "claude-sonnet-5-5" : "gpt-4o-mini")
                    if tier.needsBaseURL { PlainInput(label: "Base URL", text: $tier.baseURL, placeholder: "https://api.example.com/v1", keyboard: .URL) }
                    SecretInput(label: "API key", text: $tier.apiKey)
                }
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.12), value: tier.enabled)
    }
}

private struct SecurityStep: View {
    @Bindable var model: OnboardingModel
    @State private var sealed = false
    @State private var spin = 0
    var body: some View {
        StepScroll(title: "Security", subtitle: "Your workspace is locked with its own keys. We made them for you, they are used once to set it up, and you never have to remember them.") {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: sealed ? "lock.fill" : "lock.open").font(.title2).foregroundStyle(Tok.accent).contentTransition(.symbolEffect(.replace))
                        VStack(alignment: .leading, spacing: 2) { Text(sealed ? "Keys generated" : "Generating keys…").font(.headline); Text("Random, 256-bit, made on this phone.").font(.footnote).foregroundStyle(Tok.muted) }
                        Spacer()
                    }
                    ForEach(Array(model.secrets.all.enumerated()), id: \.offset) { i, s in
                        HStack {
                            Text(s.name).font(.subheadline)
                            Spacer()
                            Text(sealed ? String(repeating: "•", count: 10) : "").font(.subheadline).foregroundStyle(Tok.muted).tracking(2)
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tok.live).opacity(sealed ? 1 : 0).scaleEffect(sealed ? 1 : 0.3)
                                .animation(.spring(duration: 0.4, bounce: 0.4).delay(Double(i) * 0.12), value: sealed)
                        }
                        .padding(.vertical, 2)
                    }
                    Button { withAnimation(.spring(duration: 0.6, bounce: 0.2)) { model.secrets = SecretsDraft(); spin += 1 } } label: {
                        HStack(spacing: 8) { Image(systemName: "arrow.triangle.2.circlepath").rotationEffect(.degrees(Double(spin) * 360)); Text("Generate new keys") }
                    }
                    .font(.subheadline.weight(.medium)).foregroundStyle(Tok.accent).frame(minHeight: 44)
                    .sensoryFeedback(.impact(weight: .light), trigger: spin)
                }
            }
            DisclosureGroup(isExpanded: $model.customizeSecrets) {
                VStack(spacing: 14) {
                    SecretInput(label: "Database", text: $model.secrets.postgres)
                    SecretInput(label: "Memory database", text: $model.secrets.memoryDb)
                    SecretInput(label: "Memory key", text: $model.secrets.memoryApiKey)
                    SecretInput(label: "Memory signing", text: $model.secrets.memorySigning)
                    SecretInput(label: "Tools database", text: $model.secrets.toolsDb)
                }.padding(.top, 12)
            } label: { Text("Set them myself").font(.subheadline.weight(.medium)) }
            .tint(Tok.muted)
        }
        .onAppear { sealed = false; withAnimation(.easeInOut(duration: 0.6).delay(0.5)) { sealed = true } }
    }
}

private struct MemoryStep: View {
    @Bindable var model: OnboardingModel
    var body: some View {
        StepScroll(title: "Memory", subtitle: "Your workspace can search what it remembers. That needs an embedding model.") {
            VStack(spacing: 12) {
                ChoiceCard(symbol: "magnifyingglass", title: "Mission Control's embedding model", detail: "Shared and ready. No setup.", badge: "RECOMMENDED", selected: model.usePlatformEmbedding) { model.usePlatformEmbedding = true }
                ChoiceCard(symbol: "key.horizontal", title: "My own endpoint", detail: "Use a different embedding provider.", selected: !model.usePlatformEmbedding) { model.usePlatformEmbedding = false }
            }
            if !model.usePlatformEmbedding {
                SecretInput(label: "Embedding API key", text: $model.embeddingKey).transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.12), value: model.usePlatformEmbedding)
    }
}

private struct ReviewStep: View {
    @Bindable var model: OnboardingModel
    var body: some View {
        StepScroll(title: "Ready to build", subtitle: "Check your choices. Tap any row to change it.") {
            VStack(spacing: 12) {
                row(.intelligence, model.intelligence == .platform ? "Mission Control's models" : "\(model.tiers.values.filter(\.enabled).count) of your own model\(model.tiers.values.filter(\.enabled).count == 1 ? "" : "s")")
                row(.security, model.customizeSecrets ? "Keys you set yourself" : "Generated keys")
                row(.memory, model.usePlatformEmbedding ? "Mission Control's embedding model" : "Your own endpoint")
            }
            Text("Nothing is kept if setup fails. You would simply start the review again.").font(.footnote).foregroundStyle(Tok.muted)
        }
    }
    private func row(_ step: OnboardingStep, _ value: String) -> some View {
        Button { model.jump(to: step) } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: step.symbol).font(.title3).foregroundStyle(Tok.accent).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) { Text(step.title).font(.footnote).foregroundStyle(Tok.muted); Text(value).font(.body).foregroundStyle(Tok.text) }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Tok.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: Provisioning

private struct ProvisioningView: View {
    @Bindable var model: OnboardingModel
    var onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false

    private var fraction: Double { model.phase == .done ? 1 : model.progress?.fraction ?? 0.04 }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 16)
            ZStack {
                Circle().stroke(Tok.accent.opacity(0.25), lineWidth: 1).frame(width: 250).scaleEffect(burst ? 1.35 : 1).opacity(burst ? 0 : 1)
                Circle().stroke(Tok.accent.opacity(0.4), lineWidth: 1).frame(width: 210).scaleEffect(burst ? 1.5 : 1).opacity(burst ? 0 : 1)
                GemView(fill: fraction, trace: 1).frame(width: 180).scaleEffect(burst ? 1.08 : 1)
                    .shadow(color: Tok.accent.opacity(0.35 * fraction), radius: 30)
            }
            .animation(reduceMotion ? nil : .smooth(duration: 1.0), value: fraction)
            .animation(reduceMotion ? nil : .easeOut(duration: 1.1), value: burst)

            VStack(spacing: 8) {
                Text(headline).font(.system(size: 30, weight: .bold)).tracking(-0.6).multilineTextAlignment(.center).contentTransition(.opacity)
                Text(subhead).foregroundStyle(Tok.muted).multilineTextAlignment(.center).padding(.horizontal, 28)
            }

            if case .failed(let message) = model.phase {
                VStack(spacing: 14) {
                    Text(message).font(.callout).foregroundStyle(Tok.critical).multilineTextAlignment(.center)
                    Button("Back to review") { model.startOver() }.buttonStyle(PrimaryButtonStyle())
                }.padding(.horizontal, 24)
            } else {
                steps
            }
            Spacer(minLength: 0)
            if model.phase == .done {
                Button("Open Mission Control", action: onFinished).buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20).padding(.bottom, 14).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { if model.phase == .provisioning { await model.watch() } }
        .onChange(of: model.phase) { _, p in if p == .done { burst = true } }
        .sensoryFeedback(.success, trigger: model.phase == .done)
        .sensoryFeedback(.error, trigger: { if case .failed = model.phase { true } else { false } }())
    }

    private var headline: String {
        switch model.phase { case .done: "Your workspace is ready"; case .failed: "Setup didn't finish"; default: "Building your workspace" }
    }
    private var subhead: String {
        switch model.phase {
        case .done: "Everything is in place. Welcome to Mission Control."
        case .failed: "Nothing from this attempt is kept."
        default: model.progress?.status == "awaiting_approval" ? "One step needs an operator's approval. This continues by itself." : "This takes a minute or two. You can leave the app; it keeps going."
        }
    }

    private var steps: some View {
        let reported = model.progress?.steps ?? []
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(OnboardingProgress.stepKeys, id: \.self) { key in
                let status = reported.first { $0.step == key }?.status
                HStack(spacing: 12) {
                    ZStack {
                        if status == "done" || model.phase == .done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Tok.live).transition(.scale(scale: 0.3).combined(with: .opacity)) }
                        else if status == "running" { ProgressView().controlSize(.small).tint(Tok.accent) }
                        else { Circle().stroke(Tok.hairline, lineWidth: 1.5).frame(width: 16, height: 16) }
                    }.frame(width: 22, height: 22)
                    Text(OnboardingProgress.labels[key] ?? key).font(.subheadline)
                        .foregroundStyle(status == nil && model.phase != .done ? Tok.muted : Tok.text)
                    Spacer()
                }
            }
        }
        .padding(18).background(Tok.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Tok.hairline))
        .padding(.horizontal, 20)
        .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.2), value: reported)
    }
}
