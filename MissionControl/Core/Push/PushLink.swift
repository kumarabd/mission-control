import Foundation

/// Pure helpers for push: the token as Apple's service wants it, and what a tapped notification should open.
enum PushLink {
    /// The device token as lowercase hex, which is how the gateway stores and sends it.
    static func hex(_ token: Data) -> String { token.map { String(format: "%02x", $0) }.joined() }

    /// The app section a record belongs to.
    enum Section: Equatable { case today, goals, memory }

    struct Target: Equatable { var entity: String; var id: String; var section: Section }

    /// Reads the `link` the gateway puts in a push payload: {"entity": ..., "id": ...}. Anything else opens nothing.
    static func target(from userInfo: [AnyHashable: Any]) -> Target? {
        guard let link = userInfo["link"] as? [String: Any], let entity = link["entity"] as? String, let id = link["id"] as? String,
              !id.isEmpty, let section = section(for: entity) else { return nil }
        return Target(entity: entity, id: id, section: section)
    }

    static func section(for entity: String) -> Section? {
        switch entity {
        case "task", "event", "plan_item": .today
        case "goal", "routine", "reminder": .goals
        case "journal_entry", "note", "capture": .memory
        default: nil
        }
    }
}
