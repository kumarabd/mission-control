import Foundation
import SwiftData

/// Run first with the legacy schema, then with the current schema against the same
/// temporary store. This exercises a real lightweight migration across processes.
@main
struct TaskTimingPersistenceChecks {
    @MainActor
    static func main() throws {
        precondition(CommandLine.arguments.count == 3)
        let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("tasks.store")
        let mode = CommandLine.arguments[2]
        let container = try ModelContainer(for: MissionTask.self,
            configurations: ModelConfiguration("TimingChecks", url: url, cloudKitDatabase: .none))
        let context = container.mainContext
        let descriptor = FetchDescriptor<MissionTask>(sortBy: [SortDescriptor(\MissionTask.createdAt)])
        let timestamp = Date(timeIntervalSince1970: 100)
        #if LEGACY_TASK_SCHEMA
        precondition(mode == "create")
        let existing = try context.fetch(descriptor)
        precondition(existing.isEmpty)
        context.insert(MissionTask(title: "Existing open task", createdAt: timestamp))
        context.insert(MissionTask(title: "Existing completed task", isCompleted: true, createdAt: timestamp.addingTimeInterval(1)))
        try context.save()
        print("PASS: original task store created")
        #else
        let tasks = try context.fetch(descriptor)
        precondition(tasks.count == 2)
        precondition(tasks[0].title == "Existing open task" && !tasks[0].isCompleted && tasks[0].createdAt == timestamp)
        precondition(tasks[1].title == "Existing completed task" && tasks[1].isCompleted)
        let plannedTime = Date(timeIntervalSince1970: 1_800_000_000)
        if mode == "migrate" {
            precondition(tasks.allSatisfy { $0.scheduledAt == nil })
            tasks[0].scheduledAt = plannedTime
            try context.save()
            print("PASS: legacy tasks survived migration; optional time saved")
        } else if mode == "verify" {
            precondition(tasks[0].scheduledAt == plannedTime && tasks[1].scheduledAt == nil)
            tasks[0].scheduledAt = nil
            try context.save()
            print("PASS: scheduled time persisted across process restart")
        } else {
            precondition(mode == "verify-removed")
            precondition(tasks.allSatisfy { $0.scheduledAt == nil })
            print("PASS: removing a time persisted across process restart")
        }
        #endif
    }
}
