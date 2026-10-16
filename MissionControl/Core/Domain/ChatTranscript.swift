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

    var isRunning: Bool { pendingSend || runningTurn != nil }

    mutating func apply(_ event: Event) {
        switch event {
        case .sent(let clientID, let text):
            items.append(Item(id: "u:" + clientID, role: .you, text: text, turn: 0, streaming: false))
            pendingSend = true
            failure = nil

        case .answered(let text):
            guard Self.said(text) else { return }
            items.append(Item(id: "u:ans:" + UUID().uuidString, role: .you, text: text, turn: 0, streaming: false))
            failure = nil

        case .started(let turn):
            runningTurn = turn
            pendingSend = false

        case .message(let turn, let seq, let role, let content, let clientMessageID):
            guard Self.said(content) else { return }              // a frame carrying only tool work is not something said
            if role == "user" {
                let id = "u:\(turn):\(seq)"
                // The echo of a message sent here replaces it where it stands, so it is never shown twice.
                if let clientMessageID, let index = items.firstIndex(where: { $0.id == "u:" + clientMessageID }) {
                    items[index] = Item(id: id, role: .you, text: content, turn: turn, streaming: false)
                } else if !items.contains(where: { $0.id == id }) {
                    items.append(Item(id: id, role: .you, text: content, turn: turn, streaming: false))
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
            progress = ""

        case .failed(let message):
            failure = message
            runningTurn = nil
            pendingSend = false
            progress = ""
        }
    }

    private static func streamID(_ turn: Int) -> String { "s:\(turn)" }

    /// Whether a frame says anything a person would read. (Its own check rather than the app's `trimmed` extension,
    /// so this file stays compilable on its own.)
    private static func said(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
