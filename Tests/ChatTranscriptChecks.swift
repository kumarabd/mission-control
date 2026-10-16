import Foundation

@main
struct ChatTranscriptChecks {
    static func main() {
        // The echo of a message sent here replaces it where it stands, so it is never shown twice.
        var t = ChatTranscript()
        t.apply(.sent(clientID: "c1", text: "remind me to call Sam"))
        precondition(t.items.map(\.id) == ["u:c1"] && t.isRunning)
        t.apply(.started(turn: 7))
        t.apply(.message(turn: 7, seq: 1, role: "user", content: "remind me to call Sam", clientMessageID: "c1"))
        precondition(t.items.map(\.id) == ["u:7:1"], "\(t.items.map(\.id))")
        precondition(t.items[0].role == .you && t.isRunning)   // the turn is still running
        t.apply(.ended(turn: 7, status: "ok"))
        precondition(!t.isRunning)

        // Deltas build one bubble; replace resets it rather than appending.
        var d = ChatTranscript()
        d.apply(.started(turn: 1))
        d.apply(.delta(turn: 1, text: "Call", replace: false, progress: false))
        d.apply(.delta(turn: 1, text: " Sam at 5.", replace: false, progress: false))
        precondition(d.items.map(\.text) == ["Call Sam at 5."])
        precondition(d.items[0].streaming)
        d.apply(.delta(turn: 1, text: "Call Sam at 5pm.", replace: true, progress: false))
        precondition(d.items.map(\.text) == ["Call Sam at 5pm."], "replace swaps the text, it does not append")

        // Narration is not the answer.
        d.apply(.delta(turn: 1, text: "Reading your day…", replace: true, progress: true))
        precondition(d.progress == "Reading your day…" && d.items.count == 1)
        d.apply(.status(turn: 1, text: "Checking your calendar"))
        precondition(d.progress == "Checking your calendar" && d.items.count == 1)

        // The durable message supersedes the stream, and the stream bubble goes.
        d.apply(.message(turn: 1, seq: 2, role: "assistant", content: "Call Sam at 5pm.", clientMessageID: nil))
        precondition(d.items.map(\.id) == ["a:1:2"] && d.items[0].streaming == false)
        precondition(d.progress.isEmpty)

        // A replayed delta for a turn already held durably is a duplicate, not more text.
        d.apply(.delta(turn: 1, text: "Call Sam at 5pm.", replace: false, progress: false))
        precondition(d.items.map(\.id) == ["a:1:2"])

        // A stopped turn keeps what the person already saw, and a turn that said nothing leaves no empty bubble.
        var stopped = ChatTranscript()
        stopped.apply(.started(turn: 2))
        stopped.apply(.delta(turn: 2, text: "Working on", replace: false, progress: false))
        stopped.apply(.ended(turn: 2, status: "cancelled"))
        precondition(stopped.items.map(\.text) == ["Working on"] && stopped.items[0].streaming == false)
        var silent = ChatTranscript()
        silent.apply(.started(turn: 3))
        silent.apply(.ended(turn: 3, status: "cancelled"))
        precondition(silent.items.isEmpty)

        // A frame carrying only tool work is not something anyone said.
        var quiet = ChatTranscript()
        quiet.apply(.message(turn: 4, seq: 1, role: "assistant", content: "  \n", clientMessageID: nil))
        precondition(quiet.items.isEmpty)

        // Replaying a whole connect twice changes nothing: ids are (turn, sequence), so the second pass updates in place.
        let connect: [ChatTranscript.Event] = [
            .started(turn: 9),
            .message(turn: 9, seq: 1, role: "user", content: "drink more water", clientMessageID: nil),
            .message(turn: 9, seq: 2, role: "assistant", content: "Set up as a routine.", clientMessageID: nil),
            .delta(turn: 9, text: "Set up as a routine.", replace: true, progress: false),
            .ended(turn: 9, status: "ok"),
        ]
        var once = ChatTranscript(); connect.forEach { once.apply($0) }
        var twice = once; connect.forEach { twice.apply($0) }
        precondition(twice.items == once.items, "a reconnect must not double the thread")
        precondition(once.items.map(\.id) == ["u:9:1", "a:9:2"])

        // A failed turn is reported once and leaves the thread usable.
        var failed = ChatTranscript()
        failed.apply(.failed("You're offline."))
        precondition(failed.failure == "You're offline." && !failed.isRunning)

        print("ChatTranscriptChecks passed")
    }
}
