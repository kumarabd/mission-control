import Foundation

/// The one ongoing conversation with the assistant: what was said, what is still streaming, and what is running now.
/// Pure, so the check can pin down the awkward parts — the gateway replays a turn as both its durable messages and
/// its streamed deltas, and a reconnect replays the whole tail again.
///
/// Turn numbers only ever move forward, so an id built from (turn, sequence) is stable across reconnects.
struct ChatTranscript {
    enum Role: Equatable { case you, assistant }

    enum Event {
        /// A message just typed here, before the gateway has echoed it.
        case sent(clientID: String, text: String)
        /// An answer to the assistant's question. The gateway does not report answers as messages, so this stays local.
        case answered(text: String)
        /// The assistant asked a question and the turn is parked on it. The turn has not ended (the gateway ends a turn
        /// only when it is finished), but it is waiting on the person, not working.
        case asked
        case started(turn: Int)
        case message(turn: Int, seq: Int, role: String, content: String, clientMessageID: String?)
        case delta(turn: Int, text: String, replace: Bool, progress: Bool)
        case status(turn: Int, text: String)
        case ended(turn: Int, status: String)
        case failed(String)
    }

    struct Item: Identifiable, Equatable {
        let id: String
        let role: Role
        var text: String
        var turn: Int
        var streaming: Bool
    }

    private(set) var items: [Item] = []
    /// What the assistant says it is doing while it works ("Thinking…"), when it says anything.
    private(set) var progress = ""
    private(set) var runningTurn: Int?
    private(set) var failure: String?
    /// A message just sent whose turn has not started yet.
    private(set) var pendingSend = false
    /// Turns whose durable assistant message has arrived; their streamed deltas are then duplicates.
    private var durable: Set<Int> = []

    /// A question is open and the turn is waiting for the person's answer.
    private(set) var waitingOnYou = false

    var isRunning: Bool { pendingSend || runningTurn != nil }
    /// Running and not waiting on the person: the only time to show progress, or to hold back sending and answering.
    var isWorking: Bool { isRunning && !waitingOnYou }

    mutating func apply(_ event: Event) {
        switch event {
        case .sent(let clientID, let text):
            items.append(Item(id: "u:" + clientID, role: .you, text: text, turn: 0, streaming: false))
            pendingSend = true
            waitingOnYou = false
            failure = nil

        case .answered(let text):
            guard Self.said(text) else { return }
            items.append(Item(id: "u:ans:" + UUID().uuidString, role: .you, text: text, turn: 0, streaming: false))
            waitingOnYou = false
            failure = nil

        case .asked:
            waitingOnYou = true

        case .started(let turn):
            runningTurn = turn
            pendingSend = false
            waitingOnYou = false

        case .message(let turn, let seq, let role, let content, let clientMessageID):
            guard Self.said(content) else { return }              // a frame carrying only tool work is not something said
            if role == "user" {
                let id = "u:\(turn):\(seq)"
                // The echo of a message sent here replaces it where it stands, so it is never shown twice — and it
                // keeps the text the person typed, because the wire copy of a message also carries the lines this
                // client prepends for the harness (see `spoken`).
                if let clientMessageID, let index = items.firstIndex(where: { $0.id == "u:" + clientMessageID }) {
                    items[index] = Item(id: id, role: .you, text: items[index].text, turn: turn, streaming: false)
                } else if !items.contains(where: { $0.id == id }) {
                    items.append(Item(id: id, role: .you, text: Self.spoken(content), turn: turn, streaming: false))
                }
            } else if role == "assistant" {
                durable.insert(turn)
                let id = "a:\(turn):\(seq)"
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].text = content                     // the same message replayed
                } else {
                    items.append(Item(id: id, role: .assistant, text: content, turn: turn, streaming: false))
                }
                items.removeAll { $0.id == Self.streamID(turn) }     // the durable text supersedes the stream
                progress = ""
            }

        case .delta(let turn, let text, let replace, let isProgress):
            if isProgress { progress = text; return }                // narration, never the answer
            guard !durable.contains(turn) else { return }            // a replayed stream for a turn already held
            guard !text.isEmpty else { return }
            let id = Self.streamID(turn)
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].text = replace ? text : items[index].text + text
                items[index].streaming = true
            } else {
                items.append(Item(id: id, role: .assistant, text: text, turn: turn, streaming: true))
            }

        case .status(_, let text):
            progress = text

        case .ended(let turn, _):
            if let index = items.firstIndex(where: { $0.id == Self.streamID(turn) }) {
                if !Self.said(items[index].text) || durable.contains(turn) {
                    items.remove(at: index)                          // nothing was said, or the durable copy is already in
                } else {
                    items[index].streaming = false                   // a stopped turn keeps what the person already saw
                }
            }
            durable.remove(turn)
            runningTurn = nil
            pendingSend = false
            waitingOnYou = false
            progress = ""

        case .failed(let message):
            failure = message
            runningTurn = nil
            pendingSend = false
            waitingOnYou = false
            progress = ""
        }
    }

    private static func streamID(_ turn: Int) -> String { "s:\(turn)" }

    /// What the person actually said. Messages stored by earlier builds carry two lines the harness wanted and the
    /// thread must not show — the clock stamp (`[Now: …]`) and the client's capabilities (`[Client capabilities: …]`)
    /// — and a replay comes back from the gateway with them still attached. New sends carry neither; only these exact
    /// prefixes are dropped here, so a bracketed line the person typed themselves survives.
    static func spoken(_ content: String) -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while let first = lines.first, isInjected(first) { lines.removeFirst() }
        return lines.joined(separator: "\n")
    }

    private static func isInjected(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("[Now: ") || trimmed.hasPrefix("[Client capabilities: ")
    }

    /// Whether a frame says anything a person would read. (Its own check rather than the app's `trimmed` extension,
    /// so this file stays compilable on its own.)
    private static func said(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
