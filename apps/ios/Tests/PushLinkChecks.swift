import Foundation

@main
struct PushLinkChecks {
    static func main() {
        precondition(PushLink.hex(Data([0x00, 0xab, 0x0f, 0xff])) == "00ab0fff")
        precondition(PushLink.hex(Data()) == "")

        // A task or event opens on Today, a goal in Goals.
        precondition(PushLink.target(from: ["aps": ["alert": "x"], "link": ["entity": "task", "id": "t1"]]) == .init(entity: "task", id: "t1", section: .today))
        for (entity, section) in [("task", PushLink.Section.today), ("event", .today), ("goal", .goals), ("journal_entry", .memory), ("note", .memory), ("capture", .memory)] {
            precondition(PushLink.target(from: ["link": ["entity": entity, "id": "x"]])?.section == section, entity)
        }
        // The older model's records open nothing.
        for gone in ["reminder", "plan_item", "routine", "schedule", "monitor", "step"] {
            precondition(PushLink.target(from: ["link": ["entity": gone, "id": "x"]]) == nil, gone)
        }
        // Anything malformed or unknown opens nothing rather than crashing or opening the wrong place.
        precondition(PushLink.target(from: [:]) == nil)
        precondition(PushLink.target(from: ["link": "task:t1"]) == nil)
        precondition(PushLink.target(from: ["link": ["entity": "pizza", "id": "1"]]) == nil)
        precondition(PushLink.target(from: ["link": ["entity": "task", "id": ""]]) == nil)
        precondition(PushLink.target(from: ["link": ["entity": "task"]]) == nil)
        print("PushLinkChecks passed")
    }
}
