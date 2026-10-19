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

    /// A goal's link in the assistant's words, `missioncontrol://goal/<id>`: tapping it opens that goal.
    static func target(from url: URL) -> Target? {
        guard url.scheme == "missioncontrol", url.host == "goal" else { return nil }
        let id = url.lastPathComponent
        return id.isEmpty || id == "/" ? nil : Target(entity: "goal", id: id, section: .goals)
    }

    static func section(for entity: String) -> Section? {
        switch entity {
        case "reminder": .goals                    // a reminder lives in Goals ▸ Reminders, not on Today
        case "plan_item", "schedule", "routine", "monitor": .today
        case "goal", "step": .goals
        case "journal_entry": .memory
        case "note", "capture": .memory
        default: nil
        }
    }
}
