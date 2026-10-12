import Foundation

/// A device-local presentation preference, not a server-side task identifier.
/// Uses SwiftData's persisted identity without changing the existing task schema.
enum TaskFocusSelection {
    static func reference(for task: MissionTask) -> String {
        // Sorted keys keep the same persistent identity stable across launches.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(task.persistentModelID).base64EncodedString()) ?? ""
    }

    static func resolve(tasks: [MissionTask], reference: String) -> MissionTask? {
        let open = tasks.filter { !$0.isCompleted }
        return open.first { !reference.isEmpty && Self.reference(for: $0) == reference } ?? open.first
    }
}
