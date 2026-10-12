import Foundation
import SwiftData

@Model
final class MissionTask {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    /// An explicit planned time, never inferred from creation or focus selection.
    var scheduledAt: Date? = nil

    init(title: String, isCompleted: Bool = false, createdAt: Date = .now, scheduledAt: Date? = nil) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.scheduledAt = scheduledAt
    }
}
