import SwiftUI

/// One thing to do today: a routine that is due, a one-off task, or the next milestone of a goal.
enum TaskCard: Identifiable, Equatable {
    case routine(Wire.RoutineStatus)
    case task(Wire.PlanItem)
    case step(Wire.Suggestion)

    var id: String {
        switch self {
        case .routine(let s): "r:" + s.id
        case .task(let t): "t:" + t.id
        case .step(let s): "s:" + (s.stepId ?? s.title)
        }
    }

    var title: String {
        switch self {
        case .routine(let s): s.routine.title
        case .task(let t): t.title
        case .step(let s): s.title
        }
    }

    var kind: String {
        switch self { case .routine: "Routine"; case .task: "Task"; case .step: "Milestone" }
    }

    var symbol: String {
        switch self { case .routine: "repeat"; case .task: "checklist"; case .step: "flag" }
    }

    var detail: String {
        switch self {
        case .routine(let s):
            let progress = s.count > 0 ? "\(s.count) of \(s.target) today" : (s.target > 1 ? "\(s.target) times today" : "Once today")
            return [progress, s.nextNudgeText].compactMap { $0 }.joined(separator: " · ")
        case .task(let t): return t.isPriority ? "\(t.minutes) min · Priority" : "\(t.minutes) min"
        case .step(let s): return s.reason.isEmpty ? "\(s.minutes) min" : "\(s.minutes) min · \(s.reason)"
        }
    }
}

extension Wire.RoutineStatus {
    /// "Next nudge 1:00 PM", or nil when the routine has none left today.
    var nextNudgeText: String? {
        RoutineSchedule.nextCue(cues: routine.cues, zone: routine.timeZone).map { "Next nudge \($0.formatted(date: .omitted, time: .shortened))" }
    }
}

/// The day's tasks as plain list rows, the first one set larger because it is what to do now.
///
/// The ring or circle on the left does the task (a routine records one more time). Swipe right does it too, swipe left leaves it for
/// later (it goes to the end of the list). Both are VoiceOver actions as well, and the last one can be undone from the row at the end.
struct TaskDeck: View {
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
    private enum Undo { case unlog(routine: String, card: String), uncomplete(task: String, card: String), unskip(card: String) }

    private var deck: [TaskCard] {
        let live = cards.filter { !departing.contains($0.id) }
        let later = backOfLine.compactMap { id in live.first { $0.id == id } }
        var ordered = live.filter { c in !backOfLine.contains(c.id) } + later
        if let firstUp, let i = ordered.firstIndex(where: { $0.id == firstUp }), i != 0 { ordered.insert(ordered.remove(at: i), at: 0) }
        return ordered
    }

    var body: some View {
        Group {
            if deck.isEmpty { empty }
            ForEach(Array(deck.enumerated()), id: \.element.id) { index, card in row(card, first: index == 0) }
            if !deck.isEmpty, undo != nil { undoRow }
        }
        .sensoryFeedback(.success, trigger: completions)
    }

    private func row(_ card: TaskCard, first: Bool) -> some View {
        HStack(spacing: Space.m) {
            Button { commit(card, .done) } label: { mark(card).frame(minWidth: 44, minHeight: 44) }
                .buttonStyle(.borderless).disabled(busy)
                .accessibilityLabel(card.doneActionName)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title).font(.mission(first ? .title3 : .body, first ? .medium : .regular)).foregroundStyle(Tok.text)
                Text(card.detail).font(.missionMono(.footnote)).foregroundStyle(Tok.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle()).onTapGesture { open(card) }
        .padding(.vertical, first ? Space.s : 0)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { commit(card, .done) } label: { Label(card.doneActionName, systemImage: "checkmark") }.tint(Tok.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { commit(card, .later) } label: { Label("Leave for later", systemImage: "forward.end.fill") }.tint(.gray)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(card.doneActionName)) { commit(card, .done) }
        .accessibilityAction(named: Text("Leave for later")) { commit(card, .later) }
        .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .move(edge: .trailing))))
    }

    /// A routine shows its progress for today; anything else is an empty circle that fills when done.
    @ViewBuilder private func mark(_ card: TaskCard) -> some View {
        if case .routine(let s) = card { LogRing(status: s, size: 32, interactive: false) }
        else { Image(systemName: "circle").font(.system(size: 26, weight: .light)).foregroundStyle(Tok.accent) }
    }

    private var undoRow: some View {
        Button { Task { await performUndo() } } label: { Image(systemName: "arrow.uturn.backward").frame(maxWidth: .infinity, minHeight: 36) }
            .buttonStyle(.borderless).foregroundStyle(Tok.muted).disabled(busy).accessibilityLabel("Undo")
    }

    private var empty: some View {
        VStack(spacing: Space.s) {
            Image(systemName: doneToday > 0 ? "checkmark.seal.fill" : "tray").font(.system(size: 36)).foregroundStyle(Tok.accent)
                .symbolEffect(.bounce, value: doneToday).accessibilityHidden(true)
            Text(doneToday > 0 ? "All clear for today" : "Nothing to do today").font(.mission(.headline, .medium))
            if undo != nil {
                Button { Task { await performUndo() } } label: { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }
                    .buttonStyle(.bordered).tint(Tok.muted).accessibilityLabel("Undo")
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, Space.m)
        .accessibilityElement(children: .combine)
    }

    // MARK: Acting

    private func commit(_ card: TaskCard, _ direction: Direction) {
        guard !busy else { return }
        busy = true
        if firstUp == card.id { firstUp = nil }
        Task {
            switch direction {
            case .later:
                withAnimation { backOfLine.removeAll { $0 == card.id }; backOfLine.append(card.id) }
                undo = .unskip(card: card.id)
            case .done:
                // Take it out of the list at once, then save; a failed save puts it back.
                withAnimation { _ = departing.insert(card.id) }
                let outcome = await complete(card)
                withAnimation {
                    if outcome == .progressed { backOfLine.removeAll { $0 == card.id }; backOfLine.append(card.id) }
                    departing.remove(card.id)
                }
            }
            busy = false
        }
    }

    private enum Outcome { case finished, progressed, failed }

    /// Does what "done" means for the card, and says how it went.
    private func complete(_ card: TaskCard) async -> Outcome {
        switch card {
        case .routine(let s):
            await life.logRoutine(s.id)
            guard let after = life.routines.first(where: { $0.id == s.id }), after.count > s.count else { return .failed }
            undo = .unlog(routine: s.id, card: card.id); completions += 1
            return after.done ? .finished : .progressed
        case .task(let t):
            await life.completeTask(t, done: true)
            guard life.tasks.first(where: { $0.id == t.id })?.doneAt != nil else { return .failed }
            undo = .uncomplete(task: t.id, card: card.id); completions += 1
            return .finished
        case .step(let s):
            let before = life.nextSuggestion
            await life.completeSuggestion(s)
            guard life.nextSuggestion != before else { return .failed }
            completions += 1
            return .finished
        }
    }

    private func performUndo() async {
        guard let action = undo, !busy else { return }
        busy = true; undo = nil
        switch action {
        case .unlog(let routine, let card):
            await life.logRoutine(routine, delta: -1)
            withAnimation { backOfLine.removeAll { $0 == card }; firstUp = card }
        case .uncomplete(let task, let card):
            if let item = life.tasks.first(where: { $0.id == task }) { await life.completeTask(item, done: false) }
            withAnimation { backOfLine.removeAll { $0 == card }; firstUp = card }
        case .unskip(let card):
            withAnimation { backOfLine.removeAll { $0 == card }; firstUp = card }
        }
        busy = false
    }
}

extension TaskCard {
    /// What the check does on this card, for the button's label and VoiceOver.
    var doneActionName: String {
        switch self {
        case .routine(let s): s.target > 1 ? "Record one" : "Mark done"
        case .task, .step: "Mark done"
        }
    }
}
