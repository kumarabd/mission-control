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

        // A turn parked on a question has not ended, but it is waiting on the person, not working: the answer must be
        // possible, and the progress spinner must not keep turning while the pings keep arriving.
        var q = ChatTranscript()
        q.apply(.sent(clientID: "q1", text: "I want to spend less on subscriptions"))
        q.apply(.started(turn: 5))
        precondition(q.isWorking && !q.waitingOnYou)
        q.apply(.status(turn: 5, text: "Working on it \u{2014} ask_user, step 12."))
        q.apply(.asked)
        precondition(q.isRunning && q.waitingOnYou && !q.isWorking)
        q.apply(.delta(turn: 5, text: "Working on it \u{2014} ask_user, step 12.", replace: true, progress: true))
        precondition(!q.isWorking, "a later status ping must not make a waiting turn look busy")
        q.apply(.started(turn: 5))                                       // a reconnect replays the turn start...
        precondition(q.isWorking)
        q.apply(.asked)                                                  // ...and then the open question
        precondition(!q.isWorking)
        q.apply(.answered(text: "Yes, count them"))
        q.apply(.started(turn: -1))                                      // an answer carries on the same turn
        precondition(q.isWorking && !q.waitingOnYou)
        q.apply(.asked)
        q.apply(.ended(turn: 5, status: "completed"))
        precondition(!q.isRunning && !q.waitingOnYou && !q.isWorking)
        var typed = ChatTranscript()                                     // typing something else ends the wait too
        typed.apply(.started(turn: 6)); typed.apply(.asked)
        typed.apply(.sent(clientID: "q2", text: "never mind"))
        precondition(!typed.waitingOnYou && typed.isWorking)
        var broken = ChatTranscript()
        broken.apply(.started(turn: 7)); broken.apply(.asked); broken.apply(.failed("You're offline."))
        precondition(!broken.waitingOnYou && !broken.isRunning)

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

        // A message stored by an older build replays with the lines that build prepended for the harness (the clock
        // stamp and the client's capabilities); the thread shows what the person typed and nothing else.
        var replayed = ChatTranscript()
        replayed.apply(.message(turn: 5, seq: 1, role: "user", content: """
        [Client capabilities: app=mission-control; platform=ios; tracker_catalog=mission-control.ios.goal-tracker.v1. For a new goal, read tracker_catalog_get.]
        [Now: Thursday, 16 October 2026 at 1:05:23 AM GMT+5:30, time zone Asia/Kolkata]
        remind me to call Sam
        """, clientMessageID: nil))
        precondition(replayed.items.map(\.text) == ["remind me to call Sam"], "\(replayed.items.map(\.text))")

        // A bracketed line the person typed themselves is theirs, not ours.
        var literal = ChatTranscript()
        literal.apply(.message(turn: 6, seq: 1, role: "user", content: "[draft] buy milk", clientMessageID: nil))
        precondition(literal.items.map(\.text) == ["[draft] buy milk"])

        // And the echo of a message sent here keeps exactly what was typed, whatever the wire copy says.
        var echoed = ChatTranscript()
        echoed.apply(.sent(clientID: "c9", text: "call Sam"))
        echoed.apply(.message(turn: 7, seq: 1, role: "user", content: "[Client capabilities: …]\n[Now: …]\ncall Sam", clientMessageID: "c9"))
        precondition(echoed.items.map(\.text) == ["call Sam"] && echoed.items.map(\.id) == ["u:7:1"])

        // A failed turn is reported once and leaves the thread usable.
        var failed = ChatTranscript()
        failed.apply(.failed("You're offline."))
        precondition(failed.failure == "You're offline." && !failed.isRunning)

        print("ChatTranscriptChecks passed")
    }
}
