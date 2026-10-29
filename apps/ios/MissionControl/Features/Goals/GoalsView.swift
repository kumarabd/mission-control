import SwiftUI

struct GoalRef: Hashable, Identifiable { let id: String }

/// The goals list. They are the Life Engine's, so a goal the assistant makes is here. The Progress tab owns the navigation,
/// the title and the add button, and a new goal starts as a conversation with the assistant.
struct GoalsList: View {
    @Environment(Life.self) private var life
    /// Set on iPad, where the list is a column and a tap selects the goal shown beside it; nil on iPhone, where a tap pushes it.
    var selection: Binding<GoalRef?>?
    let onNew: () -> Void

    var body: some View {
        Group {
            if !life.goalsAvailable {
                EmptyState(symbol: "icloud.slash", title: "Goals need your workspace", message: "They are kept with your assistant, which isn't reachable right now.")
            } else if !life.workspaceLoaded {
                ProgressView("Loading goals…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = life.goalsLoadError, life.goals.isEmpty {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load goals", message: error, actionTitle: "Try again") { Task { await life.loadGoals() } }
            } else if life.goals.isEmpty {
                EmptyState(symbol: "flag", title: "Start with one thing you care about",
                           message: "Tell your assistant what you want to achieve, or a trip or an event to plan, and it will set up the tasks and dates.",
                           actionTitle: "Tell your assistant", action: onNew)
            } else {
                // Nil on iPhone: a plain list, so the value-based NavigationLinks push. Passing a
                // selection binding here turns rows into selection targets and taps do nothing.
                List(selection: selection) {
                    Section {
                        ForEach(life.goals) { g in
                            if selection != nil { GoalRow(goal: g).tag(GoalRef(id: g.id)) }
                            else { NavigationLink(value: GoalRef(id: g.id)) { GoalRow(goal: g) } }
                        }
                    } header: { Text("Goals").font(.mission(.subheadline, .medium)) }
                    .listRowBackground(Tok.surface)
                }
                .scrollContentBackground(.hidden)
                .refreshable { await life.loadGoals() }
            }
        }
        .task { await life.loadGoals() }
    }
}

struct GoalRow: View {
    let goal: Wire.Goal

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(goal.title).font(.mission(.headline, .medium)).foregroundStyle(Tok.text)
            if goal.progress.total > 0 {
                MissionProgressBar(fraction: Double(goal.progress.done) / Double(goal.progress.total), label: "\(goal.progress.done) of \(goal.progress.total) tasks done")
            } else {
                Text("No tasks yet").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
            }
            if let next = goal.next { Text("Next: \(next.title)").font(.mission(.subheadline)).foregroundStyle(Tok.muted).lineLimit(1) }
            if let ends = goal.endsOnText { Label(ends, systemImage: "calendar").font(.mission(.caption)).foregroundStyle(Tok.muted) }
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }
}

/// A goal: its view if one has been composed, else its plain review.
struct GoalDetail: View {
    @Environment(Life.self) private var life
    let goalID: String
    var body: some View {
        let goal = life.goals.first { $0.id == goalID }
        KitScreen(subject: ViewSubject(kind: "goal", id: goalID), title: goal?.title ?? "Goal", notes: goal?.notes ?? "") { GoalReview(goalID: goalID) }
    }
}

/// How far a goal is along, and the tasks and events that serve it: what shows until it has a view.
struct GoalReview: View {
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    let goalID: String
    @State private var items: [Wire.Item] = []
    @State private var loaded = false
    @State private var detail: ItemRef?
    @State private var adding: ItemsService.Kind?
    @State private var confirmArchive = false
    @Environment(\.dismiss) private var dismiss

    private var goal: Wire.Goal? { life.goals.first { $0.id == goalID } }
    private var tasks: [Wire.Item] { items.filter(\.isTask) }
    private var events: [Wire.Item] { items.filter(\.isEvent) }

    var body: some View {
        if let goal {
            List {
                Section {
                    if !goal.notes.isEmpty { Text(goal.notes).font(.mission(.body)) }
                    if goal.progress.total > 0 {
                        MissionProgressBar(fraction: Double(goal.progress.done) / Double(goal.progress.total), label: "\(goal.progress.done) of \(goal.progress.total) tasks done")
                    }
                    if let ends = goal.endsOnText { Label(ends, systemImage: "calendar").foregroundStyle(Tok.muted) }
                }
                .listRowBackground(Tok.surface)

                if !tasks.isEmpty { section("Tasks", tasks) }
                if !events.isEmpty { section("Events", events) }
                if loaded && items.isEmpty {
                    Section { Text("Nothing is linked to this goal yet.").foregroundStyle(Tok.muted) }.listRowBackground(Tok.surface)
                }

                Section {
                    Button("Add a task", systemImage: "checklist") { adding = .task }.frame(minHeight: 44)
                    Button("Add an event", systemImage: "calendar.badge.plus") { adding = .event }.frame(minHeight: 44)
                    Button { chat.request(draft: "About my goal \u{201C}\(goal.title)\u{201D}: ") } label: {
                        Label("Change this with your assistant", systemImage: "bubble.left")
                    }.frame(minHeight: 44)
                    Button { chat.request(draft: "About my goal \u{201C}\(goal.title)\u{201D}: I keep putting this off. ") } label: {
                        Label("I keep putting this off", systemImage: "clock.arrow.circlepath")
                    }.frame(minHeight: 44)
                    Button("Archive this goal", systemImage: "archivebox", role: .destructive) { confirmArchive = true }.frame(minHeight: 44)
                } footer: { Text("Your assistant can also plan a goal out, and move dates when something changes.").font(.mission(.footnote)) }
                .listRowBackground(Tok.surface)
            }
            .scrollContentBackground(.hidden).screenBackground()
            .task(id: goal.progress) { items = await life.items(forGoal: goalID); loaded = true }
            .refreshable { await life.loadGoals(); items = await life.items(forGoal: goalID) }
            .sheet(item: $detail) { ItemDetailSheet(ref: $0) }
            .sheet(item: $adding) { ItemFormSheet(mode: .new(goalID: goalID), initialKind: $0).environment(life) }
            .confirmationDialog("Archive this goal?", isPresented: $confirmArchive, titleVisibility: .visible) {
                Button("Archive", role: .destructive) { Task { await life.archive(goal); dismiss() } }
            } message: { Text("Its tasks and events stay. You can ask your assistant to bring it back.") }
        } else {
            ContentUnavailableView("This goal is gone", systemImage: "flag", description: Text("It was archived or removed."))
        }
    }

    private func section(_ title: String, _ list: [Wire.Item]) -> some View {
        Section {
            ForEach(list) { item in
                Button { detail = ItemRef(id: item.id) } label: {
                    HStack(spacing: Space.m) {
                        Image(systemName: item.isEvent ? "calendar" : (item.isDone ? "checkmark.circle.fill" : "circle"))
                            .foregroundStyle(item.isDone ? Tok.accent : Tok.muted).frame(width: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(item.title).font(.mission(.body)).foregroundStyle(item.isDone ? Tok.muted : Tok.text).strikethrough(item.isDone)
                            if let at = item.at { Text(at.formatted(date: .abbreviated, time: .shortened)).font(.mission(.caption)).foregroundStyle(Tok.muted) }
                        }
                        Spacer(minLength: 0)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.borderless)
            }
        } header: { Text(title).font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface)
    }
}
