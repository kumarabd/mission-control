import Foundation
import Observation
import Security

// MARK: Wire format (the router's POST/GET /onboard, shared with the web console)

struct OnboardTier: Encodable, Equatable {
    var provider: String
    var model: String
    var apiKey: String
    var baseURL: String
}

struct OnboardingRequest: Encodable {
    /// Only the tiers the person brought themselves. Empty means "use the platform's defaults": the automation worker then leaves
    /// the tenant chart's own llm tiers in place, and overrides just the tiers sent here.
    var llmTiers: [String: OnboardTier]
    var postgresPassword: String
    var agentBrainDbPassword: String
    var agentBrainApiKey: String
    var agentBrainJwtSecret: String
    var mcpHubDbPassword: String
    var litellmApiKey: String
    enum CodingKeys: String, CodingKey {
        case llmTiers = "llm_tiers"
        case postgresPassword = "postgres_password", agentBrainDbPassword = "agent_brain_db_password", agentBrainApiKey = "agent_brain_api_key"
        case agentBrainJwtSecret = "agent_brain_jwt_secret", mcpHubDbPassword = "mcp_hub_db_password", litellmApiKey = "litellm_api_key"
    }
}

struct OnboardingProgress: Decodable, Equatable {
    struct Step: Decodable, Equatable, Identifiable {
        var step: String
        var status: String            // running | done | failed
        var message: String?
        var id: String { step }
    }
    var status: String                // pending | running | awaiting_approval | completed | failed
    var error: String?
    var steps: [Step]
    var isFinished: Bool { status == "completed" || status == "failed" }

    /// 0...1 across the eight steps the workflow reports, so the gem can fill as it goes.
    var fraction: Double {
        if status == "completed" { return 1 }
        let done = steps.filter { $0.status == "done" }.count
        let running = steps.contains { $0.status == "running" } ? 0.5 : 0
        return min(0.97, (Double(done) + running) / Double(Self.stepKeys.count))
    }

    static let stepKeys = ["ValidateRequest", "RegisterTemporalNamespace", "CreateK8sNamespace", "StageTenantSecrets", "HelmInstallTenant",
                           "RegisterSharedPoolNamespace", "HealthCheck", "CleanupStagedSecret"]
    /// The workflow names each row after the activity that ran; these are the words for a person.
    static let labels: [String: String] = [
        "ValidateRequest": "Checking your details",
        "RegisterTemporalNamespace": "Reserving your space",
        "CreateK8sNamespace": "Building your private workspace",
        "StageTenantSecrets": "Sealing your credentials",
        "HelmInstallTenant": "Starting your services",
        "RegisterSharedPoolNamespace": "Connecting everything",
        "HealthCheck": "Making sure it's healthy",
        "CleanupStagedSecret": "Tidying up",
    ]
}

protocol OnboardingAPI {
    func submit(_ request: OnboardingRequest) async -> String?                 // an error to show, or nil
    func status() async -> Result<OnboardingProgress, OnboardingFailure>
}
struct OnboardingFailure: Error, Equatable { var message: String; var notFound = false }

/// The real thing: the router, with the signed-in user's Clerk token.
struct LiveOnboardingAPI: OnboardingAPI {
    let token: () async -> String?
    var base: String { Config.routerBaseURL + "/onboard" }

    /// The router answers errors as {"error": {"message": ...}} or {"message": ...}.
    static func errorMessage(_ data: Data) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return ((o["error"] as? [String: Any])?["message"] ?? o["message"] ?? o["error"]) as? String
    }

    func submit(_ request: OnboardingRequest) async -> String? {
        guard let url = URL(string: base), let body = try? JSONEncoder().encode(request), let t = await token() else { return "Please sign in again." }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"; req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse else { return "Couldn't reach Mission Control. Check your connection and try again." }
        if (200...299).contains(http.statusCode) { return nil }
        return Self.errorMessage(data) ?? "Couldn't start setup (\(http.statusCode)). Try again."
    }

    func status() async -> Result<OnboardingProgress, OnboardingFailure> {
        guard let url = URL(string: base), let t = await token() else { return .failure(.init(message: "Please sign in again.")) }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse else { return .failure(.init(message: "offline")) }
        if http.statusCode == 404 { return .failure(.init(message: "no onboarding request found", notFound: true)) }
        guard (200...299).contains(http.statusCode), let p = try? JSONDecoder().decode(OnboardingProgress.self, from: data) else { return .failure(.init(message: "Couldn't read setup progress.")) }
        return .success(p)
    }
}

#if DEBUG
/// For `-dev-onboarding`: walks through the eight steps on a timer so the screens can be seen and tested without a cluster.
final class FakeOnboardingAPI: OnboardingAPI {
    private var polls = 0
    private let fail: Bool
    init(fail: Bool = false) { self.fail = fail }
    func submit(_ request: OnboardingRequest) async -> String? { polls = 0; return nil }
    func status() async -> Result<OnboardingProgress, OnboardingFailure> {
        polls += 1
        let keys = OnboardingProgress.stepKeys
        let done = min(polls - 1, keys.count)
        if fail && done >= 4 {
            let steps = keys.prefix(4).map { OnboardingProgress.Step(step: $0, status: "done", message: nil) } + [.init(step: keys[4], status: "failed", message: "helm install failed")]
            return .success(.init(status: "failed", error: "Setup didn't finish.", steps: steps))
        }
        var steps = keys.prefix(done).map { OnboardingProgress.Step(step: $0, status: "done", message: nil) }
        if done < keys.count { steps.append(.init(step: keys[done], status: "running", message: nil)) }
        return .success(.init(status: done >= keys.count ? "completed" : "running", error: nil, steps: steps))
    }
}
#endif

// MARK: The form

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, intelligence, security, memory, review
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .welcome: "Welcome"; case .intelligence: "Intelligence"; case .security: "Security"
        case .memory: "Memory"; case .review: "Review"
        }
    }
    var symbol: String {
        switch self {
        case .welcome: "sparkles"; case .intelligence: "brain.head.profile"; case .security: "lock.shield"
        case .memory: "magnifyingglass"; case .review: "checkmark.seal"
        }
    }
}

enum IntelligenceChoice: String { case platform, own }
enum TierName: String, CaseIterable, Identifiable {
    case fast, medium, expert
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .fast: "Quick, cheap calls for simple steps."
        case .medium: "The everyday model. Required."
        case .expert: "Your most capable model, for the hardest steps."
        }
    }
}

struct TierDraft: Equatable {
    var enabled = false
    var anthropic = false
    var model = ""
    var apiKey = ""
    var baseURL = ""
    var needsBaseURL: Bool { !anthropic }
    var isComplete: Bool { !enabled || (!model.trimmed.isEmpty && !apiKey.trimmed.isEmpty && (!needsBaseURL || !baseURL.trimmed.isEmpty)) }
}

struct SecretsDraft: Equatable {
    var postgres = Self.random(), memoryDb = Self.random(), memoryApiKey = Self.random(), memorySigning = Self.random(), toolsDb = Self.random()
    /// 32 random bytes as hex, from the system's secure generator.
    static func random() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return UUID().uuidString + UUID().uuidString }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    var all: [(name: String, value: String)] {
        [("Database", postgres), ("Memory database", memoryDb), ("Memory key", memoryApiKey), ("Memory signing", memorySigning), ("Tools database", toolsDb)]
    }
    var isComplete: Bool { all.allSatisfy { !$0.value.trimmed.isEmpty } }
}

extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }

@MainActor @Observable
final class OnboardingModel {
    enum Phase: Equatable { case form, provisioning, done, failed(String) }

    var step: OnboardingStep = .welcome
    private(set) var forward = true
    var intelligence: IntelligenceChoice = .platform
    var tiers: [TierName: TierDraft] = [.fast: .init(), .medium: .init(enabled: true), .expert: .init()]
    var secrets = SecretsDraft()
    var customizeSecrets = false
    var usePlatformEmbedding = true
    var embeddingKey = ""
    var phase: Phase = .form
    var progress: OnboardingProgress?
    var submitting = false
    var submitError: String?

    private let api: OnboardingAPI
    private let defaultsKey: String
    private let defaults: UserDefaults
    private let pollInterval: Duration

    init(api: OnboardingAPI, owner: String, defaults: UserDefaults = .standard, pollInterval: Duration = .seconds(3)) {
        self.api = api; self.defaultsKey = "onboarding.submitted.\(owner)"; self.defaults = defaults; self.pollInterval = pollInterval
        if defaults.bool(forKey: defaultsKey) { phase = .provisioning }   // came back mid-setup: carry on watching it
    }

    // Navigation

    func canContinue(_ s: OnboardingStep) -> Bool {
        switch s {
        case .welcome, .review: return true
        case .security: return secrets.isComplete
        case .intelligence: return intelligence == .platform || (tiers[.medium]?.enabled == true && TierName.allCases.allSatisfy { tiers[$0]?.isComplete == true })
        case .memory: return usePlatformEmbedding || !embeddingKey.trimmed.isEmpty
        }
    }
    var canSubmit: Bool { OnboardingStep.allCases.allSatisfy(canContinue) && !submitting }

    func next() { guard step.rawValue < OnboardingStep.review.rawValue else { return }; forward = true; step = OnboardingStep(rawValue: step.rawValue + 1)! }
    func back() { guard step.rawValue > 0 else { return }; forward = false; step = OnboardingStep(rawValue: step.rawValue - 1)! }
    func jump(to s: OnboardingStep) { forward = s.rawValue > step.rawValue; step = s }

    // Submit and watch

    func request() -> OnboardingRequest {
        var out: [String: OnboardTier] = [:]
        if intelligence == .own {
            for name in TierName.allCases { if let t = tiers[name], t.enabled { out[name.rawValue] = OnboardTier(provider: t.anthropic ? "anthropic" : "openai", model: t.model.trimmed, apiKey: t.apiKey.trimmed, baseURL: t.baseURL.trimmed) } }
        }
        return OnboardingRequest(llmTiers: out, postgresPassword: secrets.postgres, agentBrainDbPassword: secrets.memoryDb, agentBrainApiKey: secrets.memoryApiKey,
                                 agentBrainJwtSecret: secrets.memorySigning, mcpHubDbPassword: secrets.toolsDb,
                                 litellmApiKey: usePlatformEmbedding ? "" : embeddingKey.trimmed)
    }

    func submit() async {
        guard canSubmit else { return }
        submitting = true; submitError = nil
        defer { submitting = false }
        if let error = await api.submit(request()) { submitError = error; return }
        defaults.set(true, forKey: defaultsKey)
        progress = nil; phase = .provisioning
    }

    /// Poll until it finishes. Cancelled with the view; safe to start again.
    func watch() async {
        var lost = 0
        while !Task.isCancelled {
            switch await api.status() {
            case .success(let p):
                progress = p; lost = 0
                if p.status == "completed" { defaults.removeObject(forKey: defaultsKey); phase = .done; return }
                if p.status == "failed" { phase = .failed(p.error?.isEmpty == false ? p.error! : "Setup didn't finish."); return }
            case .failure(let f):
                // No record of a request (cleared, or never reached the server): back to the form rather than waiting forever.
                if f.notFound { defaults.removeObject(forKey: defaultsKey); phase = .form; return }
                lost += 1
            }
            try? await Task.sleep(for: pollInterval)
        }
    }

    /// After a failure nothing from the attempt is kept, so the person re-enters the form and fresh credentials are made.
    func startOver() {
        defaults.removeObject(forKey: defaultsKey)
        secrets = SecretsDraft(); progress = nil; phase = .form; step = .review; forward = false
    }
}
