import Foundation

/// The one ongoing conversation with the assistant: what was said, what is still streaming, and what is running now.
/// Pure, so the check can pin down the awkward parts — the gateway replays a turn as both its durable messages and
/// its streamed deltas, and a reconnect replays the whole tail again.
///
/// Turn numbers only ever move forward, so an id built from (turn, sequence) is stable across reconnects.
struct ChatTranscript {
    enum Role: String, Codable, Equatable { case you, assistant }
    /// Whether the gateway has the message: a message just typed is sending until the gateway echoes it, and failed if it
    /// never did (offline, refused), when the person can send it again.
    enum Delivery: String, Codable, Equatable { case sent, sending, failed }

    /// One message of an older page the gateway sent on request.
    struct Past: Equatable { var turn: Int; var seq: Int; var role: String; var content: String; var at: Date? = nil }

    /// How many of the most recent messages are kept. Older ones are fetched as the person scrolls up, and dropped again
    /// when the chat closes, so what the app holds stays this small however long the conversation is.
    static let window = 10

    enum Event {
        /// A message just typed here, before the gateway has echoed it.
        case sent(clientID: String, text: String, at: Date = Date())
        /// A message that was not delivered, shown as failed with a way to send it again.
        case deliveryFailed(clientID: String)
        /// The person sent a failed message again; it keeps its place and its id, so the gateway's dedupe makes it safe.
        case resending(clientID: String)
        /// An answer to the assistant's question. The gateway does not report answers as messages, so this stays local.
        case answered(text: String)
        /// The assistant asked a question and the turn is parked on it. The turn has not ended (the gateway ends a turn
        /// only when it is finished), but it is waiting on the person, not working.
        case asked
        case started(turn: Int)
        case message(turn: Int, seq: Int, role: String, content: String, clientMessageID: String?, at: Date? = nil)
        case delta(turn: Int, text: String, replace: Bool, progress: Bool)
        case status(turn: Int, text: String)
        /// What streamed for this turn so far was narration between tool calls, which the gateway does not keep: take
        /// the bubble back. A later stream for the same turn starts a fresh one.
        case retract(turn: Int)
        case ended(turn: Int, status: String)
        case failed(String)
        /// A page of older messages, oldest first. `oldestTurn` is the lowest turn the gateway looked at, even if it held
        /// no message: the next request asks before it. `hasMore` is false at the start of the conversation.
        case earlier(messages: [Past], oldestTurn: Int, hasMore: Bool)
        /// A request for older messages failed. It is shown where the page would have gone, not as a failure of the chat.
        case earlierFailed(String)
    }

    struct Item: Identifiable, Equatable, Codable {
        let id: String
        let role: Role
        var text: String
        var turn: Int
        var streaming: Bool
        /// When it was said (the gateway's time for a saved message, the phone's for one just typed or streaming).
        var at: Date? = nil
        var delivery: Delivery = .sent
    }

    /// The most recent messages (at most `window`), as they arrive.
    private(set) var items: [Item] = []
    /// Older messages loaded on request, oldest first; they sit before `items` and are dropped by `dropEarlier()`.
    private(set) var earlier: [Item] = []
    private(set) var hasMoreEarlier = true
    private(set) var loadingEarlier = false
    /// Why the last request for older messages failed, until the next attempt.
    private(set) var earlierFailure: String?
    /// The next history request asks for turns before this one.
    private var earlierCursor: Int?
    /// Turns at or below this are older than the window. A replay of one is ignored, not appended again out of order.
    private var floorTurn: Int?

    /// What the thread shows: anything loaded from further back, then the recent window.
    var displayed: [Item] { earlier + items }
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
        case .sent(let clientID, let text, let at):
            items.append(Item(id: "u:" + clientID, role: .you, text: text, turn: 0, streaming: false, at: at, delivery: .sending))
            trim()
            pendingSend = true
            waitingOnYou = false
            failure = nil

        case .deliveryFailed(let clientID):
            if let index = items.firstIndex(where: { $0.id == "u:" + clientID && $0.delivery == .sending }) { items[index].delivery = .failed }
            pendingSend = items.contains { $0.delivery == .sending }

        case .resending(let clientID):
            if let index = items.firstIndex(where: { $0.id == "u:" + clientID && $0.delivery == .failed }) {
                items[index].delivery = .sending
                pendingSend = true
                failure = nil
            }

        case .answered(let text):
            guard Self.said(text) else { return }
            items.append(Item(id: "u:ans:" + UUID().uuidString, role: .you, text: text, turn: 0, streaming: false, at: Date()))
            trim()
            waitingOnYou = false
            failure = nil

        case .asked:
            waitingOnYou = true

        case .started(let turn):
            runningTurn = turn
            pendingSend = false
            waitingOnYou = false

        case .message(let turn, let seq, let role, let content, let clientMessageID, let at):
            guard Self.said(content) else { return }              // a frame carrying only tool work is not something said
            if role == "user" {
                let id = "u:\(turn):\(seq)"
                // The echo of a message sent here replaces it where it stands, so it is never shown twice — and it
                // keeps the text the person typed, because the wire copy of a message also carries the lines this
                // client prepends for the harness (see `spoken`).
                if let clientMessageID, let index = items.firstIndex(where: { $0.id == "u:" + clientMessageID }) {
                    items[index] = Item(id: id, role: .you, text: items[index].text, turn: turn, streaming: false, at: at ?? items[index].at)
                } else if !items.contains(where: { $0.id == id }), !isBeforeWindow(turn) {
                    items.append(Item(id: id, role: .you, text: Self.spoken(content), turn: turn, streaming: false, at: at))
                    trim()
                }
            } else if role == "assistant" {
                durable.insert(turn)
                let id = "a:\(turn):\(seq)"
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].text = content                     // the same message replayed
                } else if !isBeforeWindow(turn) {
                    items.append(Item(id: id, role: .assistant, text: content, turn: turn, streaming: false, at: at))
                    trim()
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
            } else if !isBeforeWindow(turn) {
                items.append(Item(id: id, role: .assistant, text: text, turn: turn, streaming: true, at: Date()))
                trim()
            }

        case .status(_, let text):
            progress = text

        case .retract(let turn):
            items.removeAll { $0.id == Self.streamID(turn) }

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
            // Whatever was still waiting on the gateway did not get there.
            for index in items.indices where items[index].delivery == .sending { items[index].delivery = .failed }
            failure = message
            runningTurn = nil
            pendingSend = false
            waitingOnYou = false
            loadingEarlier = false
            progress = ""

        case .earlierFailed(let message):
            loadingEarlier = false
            earlierFailure = message

        case .earlier(let past, let oldestTurn, let hasMore):
            loadingEarlier = false
            earlierFailure = nil
            hasMoreEarlier = hasMore
            earlierCursor = oldestTurn
            var older: [Item] = []
            for m in past where Self.said(m.content) && (m.role == "user" || m.role == "assistant") {
                let id = (m.role == "user" ? "u:" : "a:") + "\(m.turn):\(m.seq)"
                guard !earlier.contains(where: { $0.id == id }), !items.contains(where: { $0.id == id }) else { continue }
                older.append(Item(id: id, role: m.role == "user" ? .you : .assistant,
                                  text: m.role == "user" ? Self.spoken(m.content) : m.content, turn: m.turn, streaming: false, at: m.at))
            }
            earlier.insert(contentsOf: older, at: 0)
        }
    }

    /// Keeps only the most recent `window` messages. What falls off is dropped, unless older messages are already on
    /// screen: then it joins them, so the two never leave a gap between them.
    private mutating func trim() {
        guard items.count > Self.window else { return }
        let overflow = items.count - Self.window
        let dropped = Array(items.prefix(overflow))
        items.removeFirst(overflow)
        if !earlier.isEmpty { earlier.append(contentsOf: dropped) }
        hasMoreEarlier = true
        if let first = items.first(where: { $0.turn > 0 }) { floorTurn = max(floorTurn ?? 0, first.turn) }
    }

    /// A message of a turn the window has already moved past. A replay (every reconnect replays the recent turns)
    /// carries these; they are ignored, not appended after newer ones.
    private func isBeforeWindow(_ turn: Int) -> Bool {
        guard let floorTurn, turn > 0 else { return false }
        return turn <= floorTurn
    }

    /// The turn a history request should ask before, or nil when there is nothing to ask or one is already out. The
    /// first request starts one past the oldest turn held, so a turn the window cut in half comes back whole.
    mutating func beginLoadEarlier() -> Int? {
        guard hasMoreEarlier, !loadingEarlier else { return nil }
        guard let before = earlierCursor ?? items.first(where: { $0.turn > 0 }).map({ $0.turn + 1 }) else { return nil }
        loadingEarlier = true
        earlierFailure = nil
        return before
    }

    /// What to keep on the phone: the recent window, without a stream still being written (its saved message comes back
    /// from the gateway when the app opens).
    var saved: [Item] { items.filter { !$0.streaming } }

    /// Starts the thread from what was kept. A message that was still sending when the app closed never reached the
    /// gateway for certain, so it comes back failed, ready to send again. What the gateway replays after this only fills
    /// in what is newer; the turns the kept messages already cover are skipped.
    mutating func restore(_ kept: [Item]) {
        items = kept.suffix(Self.window).map { item in
            var item = item
            item.streaming = false
            if item.delivery == .sending { item.delivery = .failed }
            return item
        }
        if let oldest = items.first(where: { $0.turn > 0 }) { floorTurn = oldest.turn }
    }

    /// Forgets everything loaded from further back; the recent window stays.
    mutating func dropEarlier() {
        earlier = []
        earlierCursor = nil
        hasMoreEarlier = true
        loadingEarlier = false
        earlierFailure = nil
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

    // MARK: Rows

    /// One line of the thread as drawn: a day heading, or a message with how it sits among its neighbours.
    enum Row: Identifiable, Equatable {
        case day(Date)
        case message(Item, groupedAbove: Bool, showsTime: Bool, endsRun: Bool)
        var id: String {
            switch self {
            case .day(let d): "day:\(Int(d.timeIntervalSince1970))"
            case .message(let item, _, _, _): item.id
            }
        }
    }

    /// Messages in a run (the same speaker, within this many seconds of each other) sit close together and share one
    /// time, under the last of them; a new day gets a heading.
    static let runGap: TimeInterval = 120

    static func rows(_ items: [Item], calendar: Calendar = .current) -> [Row] {
        var rows: [Row] = []
        for (index, item) in items.enumerated() {
            let previous = index > 0 ? items[index - 1] : nil
            if let at = item.at, previous?.at.map({ !calendar.isDate($0, inSameDayAs: at) }) ?? true {
                rows.append(.day(calendar.startOfDay(for: at)))
            }
            let grouped = previous.map { Self.sameRun($0, item) } ?? false
            let next = index + 1 < items.count ? items[index + 1] : nil
            let endsRun = !(next.map { Self.sameRun(item, $0) } ?? false)
            rows.append(.message(item, groupedAbove: grouped, showsTime: item.at != nil && endsRun, endsRun: endsRun))
        }
        return rows
    }

    private static func sameRun(_ a: Item, _ b: Item) -> Bool {
        guard a.role == b.role else { return false }
        guard let x = a.at, let y = b.at else { return true }
        return abs(y.timeIntervalSince(x)) <= runGap
    }
}
