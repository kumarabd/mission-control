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

/// The day's tasks as a stack of cards. The top card is what to do now.
///
/// Swipe right to do it (a routine records one more time), swipe left to leave it for later (it goes to the back of the stack). The card
/// follows the finger, tilts a little, and reveals what the swipe will do. Every swipe has a visible button and a VoiceOver action,
/// and the last action can be undone.
struct TaskDeck: View {
    @Environment(Life.self) private var life
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cards: [TaskCard]
    let doneToday: Int
    let open: (TaskCard) -> Void

    @State private var backOfLine: [String] = []     // cards left for later, in the order they were left
    @State private var departing: Set<String> = []   // cards that have left the stack while their action is being saved
    @State private var firstUp: String?              // a card an undo brought back to the top
    @State private var draggedID: String?
    @State private var drag: CGFloat = 0
    @State private var busy = false
    @State private var crossed = false
    @State private var completions = 0
    @State private var undo: Undo?

    private enum Direction { case left, right }
    private enum Undo { case unlog(routine: String, card: String), uncomplete(task: String, card: String), unskip(card: String) }
    private let threshold: CGFloat = 110

    private var deck: [TaskCard] {
        let live = cards.filter { !departing.contains($0.id) }
        let later = backOfLine.compactMap { id in live.first { $0.id == id } }
        var ordered = live.filter { c in !backOfLine.contains(c.id) } + later
        if let firstUp, let i = ordered.firstIndex(where: { $0.id == firstUp }), i != 0 { ordered.insert(ordered.remove(at: i), at: 0) }
        return ordered
    }

    var body: some View {
        VStack(spacing: Space.m) {
            if let top = deck.first {
                stack(top)
            } else {
                empty
            }
        }
        .sensoryFeedback(.selection, trigger: crossed)
        .sensoryFeedback(.success, trigger: completions)
    }

    // MARK: The stack

    private func stack(_ top: TaskCard) -> some View {
        let progress = min(abs(drag) / threshold, 1)
        return ZStack {
            ForEach(Array(deck.prefix(3).enumerated()).reversed(), id: \.element.id) { depth, card in
                face(card, depth: depth)
                    .scaleEffect(depth == 0 ? 1 : 1 - 0.05 * CGFloat(depth) + (depth == 1 ? 0.05 * progress : 0))
                    .offset(y: depth == 0 ? 0 : CGFloat(depth) * 12 - (depth == 1 ? 12 * progress : 0))
                    .opacity(depth == 2 ? 0.75 : 1)
                    .offset(x: card.id == draggedID ? drag : 0)
                    .rotationEffect(.degrees(reduceMotion || card.id != draggedID ? 0 : Double(drag) / 20), anchor: .bottom)
                    .overlay { if depth == 0 { hints(progress: progress) } }
                    .zIndex(Double(3 - depth))
                    .allowsHitTesting(depth == 0)
                    .gesture(depth == 0 ? swipe(top) : nil)
                    .onTapGesture { if depth == 0, !busy { open(card) } }
                    .accessibilityElement(children: .combine)
                    .accessibilityHidden(depth != 0)
                    .accessibilityHint("Swipe right to do it, left to leave it for later")
                    .accessibilityAction(named: Text(top.doneActionName)) { commit(top, .right) }
                    .accessibilityAction(named: Text("Leave for later")) { commit(top, .left) }
            }
        }
        .frame(height: 176 + 24)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.82), value: deck.map(\.id))
    }

    /// Cards are the app's own surface, like every other card, with sage only where it means something: the kind label, the ring and a
    /// sage edge on the top card. The cards behind sit slightly deeper so the stack reads as depth without a second palette.
    private func face(_ card: TaskCard, depth: Int) -> some View {
        let top = depth == 0
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Label(card.kind, systemImage: card.symbol).font(.missionMono(.caption, .medium)).foregroundStyle(Tok.accent)
                Spacer()
                if case .routine(let s) = card { LogRing(status: s, size: 52, interactive: false) }
            }
            Text(card.title).font(.mission(.title2, .medium)).foregroundStyle(Tok.text).lineLimit(3).multilineTextAlignment(.leading)
            Text(card.detail).font(.missionMono(.subheadline)).foregroundStyle(Tok.muted).lineLimit(2).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176, alignment: .topLeading)
        .background(Tok.surface.mix(with: Tok.accent, by: top ? 0.0 : (depth == 1 ? 0.06 : 0.1)), in: MissionTheme.cardShape)
        .overlay { MissionTheme.cardShape.strokeBorder(top ? Tok.accent.opacity(0.35) : Tok.hairline, lineWidth: top ? 1.5 : 1) }
        .shadow(color: .black.opacity(top ? 0.12 : 0.05), radius: top ? 14 : 6, y: top ? 8 : 3)
    }

    /// What the swipe will do, shown on the edge it is heading for as the card moves.
    private func hints(progress: CGFloat) -> some View {
        ZStack {
            MissionTheme.cardShape.fill((drag >= 0 ? Tok.accent : Tok.muted).opacity(0.16 * progress))
            HStack {
                hint("checkmark", color: Tok.accent, show: drag > 0, amount: progress)
                Spacer()
                hint("forward.end.fill", color: Tok.muted, show: drag < 0, amount: progress)
            }
            .padding(.horizontal, Space.l)
        }
        .allowsHitTesting(false)
    }

    private func hint(_ symbol: String, color: Color, show: Bool, amount: CGFloat) -> some View {
        Image(systemName: symbol).font(.mission(.title2, .bold)).foregroundStyle(color)
            .opacity(show ? amount : 0).scaleEffect(show ? 0.8 + 0.3 * amount : 0.8).accessibilityHidden(true)
    }

    private func swipe(_ top: TaskCard) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                guard !busy else { return }
                // A mostly vertical drag is the list scrolling, not a swipe.
                if draggedID == nil, abs(v.translation.width) < abs(v.translation.height) * 1.3 { return }
                draggedID = top.id
                drag = v.translation.width
                if (abs(drag) >= threshold) != crossed { crossed = abs(drag) >= threshold }
            }
            .onEnded { v in
                guard !busy, draggedID != nil else { return }
                let predicted = v.predictedEndTranslation.width
                if drag > threshold || predicted > 260 { commit(top, .right) }
                else if drag < -threshold || predicted < -260 { commit(top, .left) }
                else { settle() }
            }
    }

    private func settle() {
        crossed = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.35, dampingFraction: 0.7)) { drag = 0 }
        draggedID = nil
    }

    private var empty: some View {
        VStack(spacing: Space.s) {
            Image(systemName: doneToday > 0 ? "checkmark.seal.fill" : "tray").font(.system(size: 40)).foregroundStyle(Tok.accent)
                .symbolEffect(.bounce, value: doneToday).accessibilityHidden(true)
            Text(doneToday > 0 ? "All clear for today" : "Nothing to do today").font(.mission(.title3, .medium))
            if undo != nil {
                Button { Task { await performUndo() } } label: { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }
                    .buttonStyle(.bordered).tint(Tok.muted).accessibilityLabel("Undo")
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, Space.l)
        .accessibilityElement(children: .combine)
    }

    // MARK: Acting

    /// Sends the top card away (the swipe finishes, or a button does it for you), then does what the direction means.
    private func commit(_ card: TaskCard, _ direction: Direction) {
        guard !busy else { return }
        busy = true
        draggedID = card.id
        withAnimation(reduceMotion ? .easeIn(duration: 0.1) : .easeIn(duration: 0.18)) { drag = direction == .right ? 640 : -640 }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 180))
            // The card has left the screen: take it out of the stack at once, so the next one rises while its action is saved.
            withAnimation { departing.insert(card.id) }
            var instant = Transaction(); instant.disablesAnimations = true
            withTransaction(instant) { drag = 0; draggedID = nil; crossed = false }
            if firstUp == card.id { firstUp = nil }
            switch direction {
            case .left:
                withAnimation { backOfLine.removeAll { $0 == card.id }; backOfLine.append(card.id); departing.remove(card.id) }
                undo = .unskip(card: card.id)
            case .right:
                let outcome = await complete(card)
                withAnimation {
                    // Finished: gone. Done once but more to go (a routine with a count): to the back of the stack. Not saved: back where it was.
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
