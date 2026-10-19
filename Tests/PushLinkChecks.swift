import Foundation

@main
struct PushLinkChecks {
    static func main() {
        precondition(PushLink.hex(Data([0x00, 0xab, 0x0f, 0xff])) == "00ab0fff")
        precondition(PushLink.hex(Data()) == "")

        let reminder: [AnyHashable: Any] = ["aps": ["alert": "x"], "link": ["entity": "reminder", "id": "r1"]]
        // A reminder opens Goals ▸ Reminders now, not Today.
        precondition(PushLink.target(from: reminder) == .init(entity: "reminder", id: "r1", section: .goals))
        for (entity, section) in [("plan_item", PushLink.Section.today), ("schedule", .today), ("routine", .today), ("monitor", .today), ("goal", .goals), ("step", .goals),
                                  ("journal_entry", .memory), ("note", .memory), ("capture", .memory)] {
            precondition(PushLink.target(from: ["link": ["entity": entity, "id": "x"]])?.section == section, entity)
        }
        // Anything malformed or unknown opens nothing rather than crashing or opening the wrong place.
        precondition(PushLink.target(from: [:]) == nil)
        precondition(PushLink.target(from: ["link": "reminder:r1"]) == nil)
        precondition(PushLink.target(from: ["link": ["entity": "pizza", "id": "1"]]) == nil)
        precondition(PushLink.target(from: ["link": ["entity": "reminder", "id": ""]]) == nil)
        precondition(PushLink.target(from: ["link": ["entity": "reminder"]]) == nil)
        // A goal's link in the assistant's words opens that goal; any other URL is none of ours.
        precondition(PushLink.target(from: URL(string: "missioncontrol://goal/3f2c1a0e-4b6d")!) == .init(entity: "goal", id: "3f2c1a0e-4b6d", section: .goals))
        precondition(PushLink.target(from: URL(string: "https://example.com/goal/1")!) == nil)
        precondition(PushLink.target(from: URL(string: "missioncontrol://reminder/1")!) == nil)
        precondition(PushLink.target(from: URL(string: "missioncontrol://goal")!) == nil)
        print("PushLinkChecks passed")
    }
}
