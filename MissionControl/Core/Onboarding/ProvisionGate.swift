import SwiftUI

/// Between sign-in and the app: a new account has no workspace yet, so it is walked through setting one up first.
/// Anything other than "not provisioned" goes straight in (offline, a hiccup, an existing account), so setup never
/// blocks someone who already has a workspace.
struct ProvisionGate: View {
    let userId: String
    @Environment(AuthService.self) private var auth
    @State private var stage: Stage = .checking

    enum Stage { case checking, onboarding(OnboardingModel), ready }

    var body: some View {
        Group {
            switch stage {
            case .checking:
                Image(systemName: "scope").font(.system(size: 44)).foregroundStyle(Tok.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Tok.background.ignoresSafeArea())
            case .onboarding(let model):
                OnboardingFlow(model: model) { stage = .ready }
            case .ready:
                MainTabs(userId: userId).id(userId)   // a different user is a different shell, never a reused one
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stageName)
        .task(id: userId) { await check() }
    }

    private var stageName: String { switch stage { case .checking: "c"; case .onboarding: "o"; case .ready: "r" } }

    private func check() async {
        #if DEBUG
        if Config.devEngine { stage = .ready; return }
        if ProcessInfo.processInfo.arguments.contains("-dev-onboarding") {
            let fail = ProcessInfo.processInfo.arguments.contains("-dev-onboarding-fail")
            stage = .onboarding(OnboardingModel(api: FakeOnboardingAPI(fail: fail), owner: userId, defaults: UserDefaults(suiteName: "onboarding-dev") ?? .standard, pollInterval: .milliseconds(600)))
            return
        }
        #endif
        // Same test as Treasure and AutoTelemetry: an authenticated call through the router. The workspace is per person,
        // so one that exists from another app answers here too. Only the router's "no_tenant" means set it up; done,
        // offline or any other answer goes straight in.
        if await Provisioning.isMissing(token: await auth.token()) {
            stage = .onboarding(OnboardingModel(api: LiveOnboardingAPI(token: { [auth] in await auth.token() }), owner: userId))
        } else {
            stage = .ready
        }
    }
}

enum Provisioning {
    /// The router answers 404 `no_tenant` to any service route when the signed-in person has no workspace.
    static func isMissing(status: Int, body: Data) -> Bool {
        status == 404 && String(decoding: body, as: UTF8.self).contains("no_tenant")
    }

    static func isMissing(token: String?) async -> Bool {
        guard let token, let url = URL(string: Config.routerBaseURL + "/missioncontrol/api/v1/operations/profile_get") else { return false }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"; req.httpBody = Data("{}".utf8)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse else { return false }
        return isMissing(status: http.statusCode, body: data)
    }
}
