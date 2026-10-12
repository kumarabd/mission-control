import Foundation
import SwiftData

/// Original on-device schema, compiled only by the migration check executable.
@Model
final class MissionTask {
    var title: String
    var isCompleted: Bool
    var createdAt: Date

    init(title: String, isCompleted: Bool = false, createdAt: Date = .now) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
