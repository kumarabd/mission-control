import Foundation

protocol GitHubRepositoryProviding {
    func repositories() -> [GitHubRepository]
}

/// V1 data source. This keeps the dashboard independent from the later GitHub API client.
struct MockGitHubService: GitHubRepositoryProviding {
    func repositories() -> [GitHubRepository] {
        [
            GitHubRepository(id: 1, name: "Mission Control", description: "Personal productivity dashboard", htmlURL: URL(string: "https://github.com/kumarabd/mission-control")!, pushedAt: .now.addingTimeInterval(-12 * 60)),
            GitHubRepository(id: 2, name: "Agent Memory", description: "Long-term memory system for agents", htmlURL: URL(string: "https://github.com/kumarabd/agent-memory")!, pushedAt: .now.addingTimeInterval(-26 * 60 * 60)),
            GitHubRepository(id: 3, name: "Agent Harness", description: "Production agent orchestration framework", htmlURL: URL(string: "https://github.com/kumarabd/agent-harness")!, pushedAt: .now.addingTimeInterval(-3 * 24 * 60 * 60))
        ]
    }
}
