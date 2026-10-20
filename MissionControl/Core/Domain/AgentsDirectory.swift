import ClerkKit
import Foundation
import Observation
import os

/// The agents you can talk to, with who is who in the thread: each agent's name and picture, and your own from your
/// profile. Loaded from the gateway's registry; the chat shows the picked agent's avatar beside its replies.
@MainActor @Observable
final class AgentsDirectory {
    private(set) var agents: [GatewayAgentsAPI.Agent] = []
    private(set) var loaded = false
    private(set) var failure: String?

    private let api = GatewayAgentsAPI(
        baseURL: Config.routerBaseURL + "/gateway",
        token: { try await ClerkGatewayAuthentication().sessionToken() }
    )
    private static let log = Logger(subsystem: "com.kumarabd.MissionControl", category: "agents")

    func load() async {
        // Developer mode has no router, so there is no registry to ask.
        #if DEBUG
        // Developer mode has no registry: two sample agents let the switcher be run and looked at.
        if Config.devEngine {
            let now = Date()
            agents = [
                .init(agentID: "main", displayName: "Aria", avatarURL: nil, description: "Your everyday assistant: reminders, goals, plans.", persona: "", status: "active", createdAt: now),
                .init(agentID: "coach", displayName: "Coach", avatarURL: nil, description: "Training and habits, in plain words.", persona: "", status: "active", createdAt: now),
            ]
            loaded = true
            return
        }
        #endif
        if Config.routerBaseURL.isEmpty { loaded = true; return }
        do {
            agents = try await api.listAgents().filter { $0.status == "active" }
            failure = nil
        } catch {
            Self.log.error("could not load agents: \(error.localizedDescription, privacy: .public)")
            failure = "Couldn\u{2019}t load your agents."
        }
        loaded = true
    }

    /// The agent with this id, when the registry has it.
    func agent(_ id: String) -> GatewayAgentsAPI.Agent? { agents.first { $0.agentID == id } }

    func name(_ id: String) -> String { agent(id)?.displayName ?? (id == ChatStore.defaultAgent ? "Assistant" : id) }
    func avatarURL(_ id: String) -> String? { agent(id)?.avatarURL }

    // MARK: You

    /// Your name as the profile has it; "You" when signed in only for development.
    static var profileName: String {
        guard let user = Clerk.shared.user else { return "You" }
        let name = [user.firstName, user.lastName].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? (user.primaryEmailAddress?.emailAddress ?? "You") : name
    }

    /// Your profile picture, only when you set one (Clerk otherwise serves a generated placeholder).
    static var profileImageURL: String? {
        guard let user = Clerk.shared.user, user.hasImage else { return nil }
        return user.imageUrl
    }
}
