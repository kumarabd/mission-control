import Foundation

/// Goals are the Life Engine's, the same records the assistant creates and edits. The app only reads them: a goal is for review, and it
/// changes through the assistant.
struct GoalsService {
    var api: LifeAPI

    private struct ListIn: Encodable { var limit = 100 }

    /// Active goals with their steps, progress and next step.
    func list() async throws -> [Wire.Goal] {
        let page: Wire.Page<Wire.Goal> = try await api.call("goals_list", ListIn())
        return page.items
    }
}
