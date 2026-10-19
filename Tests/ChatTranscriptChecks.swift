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

        // Only the most recent messages are kept: 8 turns of two messages arrive, 10 stay.
        func turn(_ t: Int, in tr: inout ChatTranscript) {
            tr.apply(.started(turn: t))
            tr.apply(.message(turn: t, seq: 1, role: "user", content: "q\(t)", clientMessageID: nil))
            tr.apply(.message(turn: t, seq: 2, role: "assistant", content: "a\(t)", clientMessageID: nil))
            tr.apply(.ended(turn: t, status: "completed"))
        }
        var w = ChatTranscript()
        for t in 1...8 { turn(t, in: &w) }
        precondition(w.items.count == ChatTranscript.window && w.earlier.isEmpty, "\(w.items.count)")
        precondition(w.items.map(\.id) == ["u:4:1", "a:4:2", "u:5:1", "a:5:2", "u:6:1", "a:6:2", "u:7:1", "a:7:2", "u:8:1", "a:8:2"], "\(w.items.map(\.id))")
        precondition(w.displayed == w.items && w.hasMoreEarlier)

        // A reconnect replays the recent turns again: what the window already passed is not appended after newer ones.
        for t in 1...8 { turn(t, in: &w) }
        precondition(w.items.map(\.id).first == "u:4:1" && w.items.last?.id == "a:8:2" && w.items.count == 10, "\(w.items.map(\.id))")
        w.apply(.message(turn: 3, seq: 2, role: "assistant", content: "a3 again", clientMessageID: nil))
        w.apply(.delta(turn: 2, text: "late stream", replace: false, progress: false))
        precondition(w.items.count == 10 && !w.items.contains { $0.id == "a:3:2" || $0.id == "s:2" })

        // A message just sent counts toward the window, and the window moves on with it.
        w.apply(.sent(clientID: "n1", text: "hello"))
        precondition(w.items.count == 10 && w.items.last?.id == "u:n1" && w.items.first?.id == "a:4:2", "\(w.items.map(\.id))")

        // Reaching the top asks for the turns before the window; a turn cut in half by the window comes back whole.
        var p = ChatTranscript()
        for t in 1...8 { turn(t, in: &p) }
        p.apply(.sent(clientID: "n2", text: "x"))                          // 11 items: u:4:1 dropped, a:4:2 first
        precondition(p.items.first?.id == "a:4:2")
        let before = p.beginLoadEarlier()
        precondition(before == 5 && p.loadingEarlier, "\(String(describing: before))")   // one past the oldest turn held
        precondition(p.beginLoadEarlier() == nil, "one request at a time")
        p.apply(.earlier(messages: [
            .init(turn: 2, seq: 1, role: "user", content: "q2"), .init(turn: 2, seq: 2, role: "assistant", content: "a2"),
            .init(turn: 3, seq: 1, role: "user", content: "q3"), .init(turn: 3, seq: 2, role: "assistant", content: "a3"),
            .init(turn: 4, seq: 1, role: "user", content: "q4"), .init(turn: 4, seq: 2, role: "assistant", content: "a4"),
        ], oldestTurn: 2, hasMore: true))
        precondition(!p.loadingEarlier && p.hasMoreEarlier)
        precondition(p.earlier.map(\.id) == ["u:2:1", "a:2:2", "u:3:1", "a:3:2", "u:4:1"], "\(p.earlier.map(\.id))")   // a:4:2 is already held
        precondition(p.displayed.map(\.id).first == "u:2:1" && p.displayed.count == p.earlier.count + p.items.count)
        precondition(Set(p.displayed.map(\.id)).count == p.displayed.count, "no message is shown twice")
        precondition(p.beginLoadEarlier() == 2, "the next page asks before the oldest turn looked at")
        p.apply(.earlier(messages: [.init(turn: 1, seq: 1, role: "user", content: "q1"), .init(turn: 1, seq: 2, role: "assistant", content: "a1")], oldestTurn: 1, hasMore: false))
        precondition(!p.hasMoreEarlier && p.beginLoadEarlier() == nil && p.displayed.first?.id == "u:1:1")

        // With older messages on screen, a new message does not leave a gap: what falls off the window joins them.
        let shown = p.displayed.map(\.id)
        p.apply(.sent(clientID: "n3", text: "y"))
        precondition(Array(p.displayed.map(\.id).dropLast()) == shown && p.displayed.last?.id == "u:n3", "\(p.displayed.map(\.id))")
        precondition(p.items.count == 10)

        // Closing the chat drops what was loaded from further back and keeps the window.
        let window = p.items
        p.dropEarlier()
        precondition(p.earlier.isEmpty && p.items == window && p.hasMoreEarlier && !p.loadingEarlier)
        precondition(p.beginLoadEarlier() != nil, "scrolling up again asks again")

        // A failed request does not leave the thread waiting for a page that is not coming.
        p.apply(.failed("You're offline."))
        precondition(!p.loadingEarlier)

        // Text that streamed before its step turned out to be narration is taken back, and only that turn's.
        var r = ChatTranscript()
        r.apply(.started(turn: 4))
        r.apply(.delta(turn: 4, text: "I have spending_analyze which", replace: false, progress: false))
        r.apply(.message(turn: 3, seq: 1, role: "assistant", content: "an earlier reply", clientMessageID: nil))
        precondition(r.items.map(\.id) == ["s:4", "a:3:1"] || r.items.map(\.id) == ["a:3:1", "s:4"], "\(r.items.map(\.id))")
        r.apply(.retract(turn: 4))
        precondition(r.items.map(\.id) == ["a:3:1"], "\(r.items.map(\.id))")
        r.apply(.retract(turn: 4))                                                 // nothing left to take back: harmless
        r.apply(.retract(turn: 99))
        precondition(r.items.map(\.id) == ["a:3:1"])
        r.apply(.delta(turn: 4, text: "Here is the answer", replace: false, progress: false))   // the real reply streams on
        precondition(r.items.contains { $0.id == "s:4" && $0.text == "Here is the answer" })
        r.apply(.status(turn: 4, text: "Working on it"))
        precondition(r.progress == "Working on it", "a retract does not touch the progress line")

        // A failed request for older messages is shown at the top, stops the loading state, and clears on the next try.
        var f = ChatTranscript()
        for t in 1...8 { turn(t, in: &f) }
        precondition(f.beginLoadEarlier() != nil && f.loadingEarlier && f.earlierFailure == nil)
        f.apply(.earlierFailed("Couldn\u{2019}t load earlier messages."))
        precondition(!f.loadingEarlier && f.earlierFailure != nil && f.failure == nil, "it is not a failure of the chat")
        precondition(f.beginLoadEarlier() != nil && f.earlierFailure == nil && f.loadingEarlier, "trying again clears it and loads")
        f.apply(.earlier(messages: [], oldestTurn: 1, hasMore: false))
        precondition(!f.loadingEarlier && f.earlierFailure == nil)
        f.apply(.earlierFailed("x")); f.dropEarlier()
        precondition(f.earlierFailure == nil)

        // Messages with nothing to show, or of another role, are not added from a page.
        var q2 = ChatTranscript()
        q2.apply(.message(turn: 9, seq: 1, role: "user", content: "hi", clientMessageID: nil))
        q2.apply(.earlier(messages: [.init(turn: 8, seq: 1, role: "assistant", content: "  "), .init(turn: 8, seq: 2, role: "tool", content: "x"),
                                     .init(turn: 8, seq: 3, role: "assistant", content: "real")], oldestTurn: 8, hasMore: true))
        precondition(q2.earlier.map(\.id) == ["a:8:3"], "\(q2.earlier.map(\.id))")

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
