import Foundation

/// Goals are the Life Engine's, the same records the assistant creates and edits. The app only reads them: a goal is for review, and it
/// changes through the assistant.
struct GoalsService {
    var api: LifeAPI

    private struct ListIn: Encodable { var limit = 100 }
    private struct StepDoneIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var done: Bool }

    /// Active goals with their steps, progress and next step.
    func list() async throws -> [Wire.Goal] {
        let page: Wire.Page<Wire.Goal> = try await api.call("goals_list", ListIn())
        return page.items
    }

    /// Finishes a one-off step. It is done from Today (the next thing to do), never from the goal, which is only for review.
    func completeStep(id: String, version: Int) async throws {
        let _: Wire.Step = try await api.call("steps_complete", StepDoneIn(idempotencyKey: UUID().uuidString, id: id, expectedVersion: version, done: true))
    }
}
