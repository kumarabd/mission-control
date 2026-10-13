import Foundation

/// Goals are the Life Engine's, the same records the assistant creates and edits. The app reads them and ticks off their steps;
/// it does not keep a copy of its own.
struct GoalsService {
    var api: LifeAPI

    private struct ListIn: Encodable { var limit = 100 }
    private struct StepDoneIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var done: Bool }
    private struct AddStepIn: Encodable { var idempotencyKey: String; var goalId: String; var title: String; var minutes: Int }
    private struct EditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }

    /// Active goals with their steps, progress and next step.
    func list() async throws -> [Wire.Goal] {
        let page: Wire.Page<Wire.Goal> = try await api.call("goals_list", ListIn())
        return page.items
    }

    func setStep(_ step: Wire.Step, done: Bool) async throws -> Wire.Step {
        try await api.call("steps_complete", StepDoneIn(idempotencyKey: UUID().uuidString, id: step.id, expectedVersion: step.version, done: done))
    }

    func addStep(goal: String, title: String, minutes: Int) async throws -> Wire.Step {
        try await api.call("steps_add", AddStepIn(idempotencyKey: UUID().uuidString, goalId: goal, title: title, minutes: minutes))
    }

    func archive(_ goal: Wire.Goal) async throws {
        let _: Wire.Goal = try await api.call("goals_archive", EditIn(idempotencyKey: UUID().uuidString, id: goal.id, expectedVersion: goal.version))
    }
}
