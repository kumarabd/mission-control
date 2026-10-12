import Foundation
import SwiftData

/// Standalone checks for the shared local focus behavior; no simulator required.
@main
struct TaskFocusSelectionChecks {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mission-focus-checks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("tasks.store")
        let reference = try createTasks(at: url)
        try reopenAndCheck(at: url, reference: reference)
        print("PASS: focus selection, completion fallback, undo, deletion fallback, and persistence across store reopen")
    }

    @MainActor
    static func createTasks(at url: URL) throws -> String {
        let container = try ModelContainer(for: MissionTask.self, configurations: ModelConfiguration("FocusChecks", url: url, cloudKitDatabase: .none))
        let context = container.mainContext
        let first = MissionTask(title: "First", createdAt: Date(timeIntervalSince1970: 1))
        let second = MissionTask(title: "Second", createdAt: Date(timeIntervalSince1970: 2))
        context.insert(first)
        context.insert(second)
        try context.save()
        let tasks = [first, second]
        precondition(TaskFocusSelection.resolve(tasks: [], reference: "") == nil)
        precondition(TaskFocusSelection.resolve(tasks: tasks, reference: "") === first)
        precondition(TaskFocusSelection.resolve(tasks: tasks, reference: "stale") === first)
        let reference = TaskFocusSelection.reference(for: second)
        precondition(!reference.isEmpty)
        precondition(reference == TaskFocusSelection.reference(for: second))
        precondition(TaskFocusSelection.resolve(tasks: tasks, reference: reference) === second)
        second.isCompleted = true
        precondition(TaskFocusSelection.resolve(tasks: tasks, reference: reference) === first)
        first.isCompleted = true
        precondition(TaskFocusSelection.resolve(tasks: tasks, reference: reference) == nil)
        second.isCompleted = false
        precondition(TaskFocusSelection.resolve(tasks: tasks, reference: reference) === second)
        first.isCompleted = false
        try context.save()
        return reference
    }

    @MainActor
    static func reopenAndCheck(at url: URL, reference: String) throws {
        let container = try ModelContainer(for: MissionTask.self, configurations: ModelConfiguration("FocusChecks", url: url, cloudKitDatabase: .none))
        let context = container.mainContext
        let descriptor = FetchDescriptor<MissionTask>(sortBy: [SortDescriptor(\MissionTask.createdAt)])
        let tasks = try context.fetch(descriptor)
        precondition(tasks.count == 2)
        precondition(TaskFocusSelection.resolve(tasks: tasks, reference: reference)?.title == "Second")
        context.delete(tasks[1])
        try context.save()
        let remaining = try context.fetch(descriptor)
        precondition(TaskFocusSelection.resolve(tasks: remaining, reference: reference)?.title == "First")
    }
}
