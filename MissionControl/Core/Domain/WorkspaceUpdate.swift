import Foundation

/// A receipt is based on records returned by the workspace, not on the assistant's wording.
struct WorkspaceUpdate: Identifiable, Equatable {
    enum Kind: String { case goal, task, event }
    let kind: Kind
    let entityID: String
    let title: String
    let detail: String
    let version: Int
    var id: String { kind.rawValue + ":" + entityID }
}
