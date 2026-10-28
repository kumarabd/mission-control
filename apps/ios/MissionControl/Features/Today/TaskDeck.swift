import SwiftUI

/// One thing to do: a task with no time, or one that was due on an earlier day and is still waiting.
struct TaskCard: Identifiable, Equatable {
    let item: Wire.Item
    /// The occurrence, for a repeating task; nil for a one-off.
    var at: Date?
    var overdue = false

    var id: String { item.id + (at.map { "@" + String(Int($0.timeIntervalSince1970)) } ?? "") }
    var title: String { item.title }
    var ref: ItemRef { ItemRef(id: item.id, at: item.repeats ? at : nil) }

    var detail: String {
        var parts: [String] = []
        if overdue, let at { parts.append("Was due " + at.formatted(.dateTime.month(.abbreviated).day())) }
        if let m = item.minutes { parts.append("\(m) min") }
        if item.isPriority { parts.append("Priority") }
        return parts.joined(separator: " · ")
    }
}

/// The day's tasks as plain list rows, the first one set larger because it is what to do now.
///
/// The circle on the left does the task. Swipe right does it too, swipe left leaves it for
/// later (it goes to the end of the list). Both are VoiceOver actions as well, and the last one can be undone from the row at the end.
struct TaskDeck: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Life.self) private var life
    let cards: [TaskCard]
    let doneToday: Int
    let open: (TaskCard) -> Void

    @State private var backOfLine: [String] = []     // cards left for later, in the order they were left
    @State private var departing: Set<String> = []   // cards that have left the list while their action is being saved
    @State private var firstUp: String?              // a card an undo brought back to the top
    @State private var busy = false
    @State private var completions = 0
    @State private var undo: Undo?

    private enum Direction { case later, done }
    private enum Undo { case uncomplete(item: Wire.Item, at: Date?, card: String), unskip(card: String) }

    private var deck: [TaskCard] {
        let live = cards.filter { !departing.contains($0.id) }
        let later = backOfLine.compactMap { id in live.first { $0.id == id } }
        var ordered = live.filter { c in !backOfLine.contains(c.id) } + later
        if let firstUp, let i = ordered.firstIndex(where: { $0.id == firstUp }), i != 0 { ordered.insert(ordered.remove(at: i), at: 0) }
        return ordered
    }

    var body: some View {
        Group {
            if undo != nil { undoRow }
            if deck.isEmpty { empty }
            ForEach(Array(deck.enumerated()), id: \.element.id) { index, card in row(card, first: index == 0) }
        }
        .sensoryFeedback(.success, trigger: completions)
    }

    private func row(_ card: TaskCard, first: Bool) -> some View {
        HStack(spacing: Space.m) {
            Button { commit(card, .done) } label: { Image(systemName: "circle").font(.system(size: 26, weight: .light)).foregroundStyle(Tok.accent).frame(minWidth: 44, minHeight: 44) }
                .buttonStyle(.borderless).disabled(busy)
                .accessibilityLabel("Mark done: \(card.title)")
            Button { open(card) } label: {
                HStack(spacing: Space.s) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(card.title).font(.mission(first ? .title3 : .body, first ? .medium : .regular)).foregroundStyle(Tok.text).multilineTextAlignment(.leading)
                        Text(detail(card)).font(.mission(.caption)).foregroundStyle(Tok.muted).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Tok.muted)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.borderless).accessibilityLabel("\(card.title). Show details")
        }
        .padding(.vertical, first ? Space.s : 0)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { commit(card, .done) } label: { Label("Mark done", systemImage: "checkmark") }.tint(Tok.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { commit(card, .later) } label: { Label("Move to bottom", systemImage: "forward.end.fill") }.tint(.gray)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Mark done")) { commit(card, .done) }
        .accessibilityAction(named: Text("Move to bottom")) { commit(card, .later) }
        .accessibilityAction(named: Text("Show details")) { open(card) }
        .transition(.opacity)
    }

    private var undoRow: some View {
        Button { Task { await performUndo() } } label: { Label("Undo last action", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(.borderless).foregroundStyle(Tok.muted).disabled(busy).accessibilityLabel("Undo")
    }

    private var empty: some View {
        VStack(spacing: Space.s) {
            Image(systemName: doneToday > 0 ? "checkmark.seal.fill" : "tray").font(.system(size: 36)).foregroundStyle(Tok.accent)
                .accessibilityHidden(true)
            Text(doneToday > 0 ? "Untimed work is done" : "No untimed tasks").font(.mission(.headline, .medium))

        }
        .frame(maxWidth: .infinity).padding(.vertical, Space.m)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ card: TaskCard) -> String {
        let goal = life.goals.first { $0.id == card.item.goalId }?.title
        return [card.detail, goal ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: Acting

    private func commit(_ card: TaskCard, _ direction: Direction) {
        guard !busy else { return }
        busy = true
        if firstUp == card.id { firstUp = nil }
        Task {
            switch direction {
            case .later:
                withAnimation(reduceMotion ? nil : .default) { backOfLine.removeAll { $0 == card.id }; backOfLine.append(card.id) }
                undo = .unskip(card: card.id)
            case .done:
                // Take it out of the list at once, then save; a failed save puts it back.
                withAnimation(reduceMotion ? nil : .default) { _ = departing.insert(card.id) }
                _ = await complete(card)
                withAnimation(reduceMotion ? nil : .default) { _ = departing.remove(card.id) }
            }
            busy = false
        }
    }

    private enum Outcome { case finished, failed }

    /// Marks the task done, and says how it went.
    private func complete(_ card: TaskCard) async -> Outcome {
        guard let updated = await life.complete(card.item, at: card.item.repeats ? card.at : nil) else { return .failed }
        undo = .uncomplete(item: updated, at: card.item.repeats ? card.at : nil, card: card.id); completions += 1
        return .finished
    }

    private func performUndo() async {
        guard let action = undo, !busy else { return }
        busy = true; undo = nil
        switch action {
        case .uncomplete(let item, let at, let card):
            await life.complete(item, at: at, done: false)
            withAnimation(reduceMotion ? nil : .default) { backOfLine.removeAll { $0 == card }; firstUp = card }
        case .unskip(let card):
            withAnimation(reduceMotion ? nil : .default) { backOfLine.removeAll { $0 == card }; firstUp = card }
        }
        busy = false
    }
}
