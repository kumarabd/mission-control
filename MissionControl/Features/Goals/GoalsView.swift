import SwiftUI

/// The goals list. The Progress tab owns the navigation, the title and the add button.
struct GoalsList: View {
    @Environment(Life.self) private var life
    let onNew: () -> Void

    var body: some View {
        Group {
            if life.store.goals.isEmpty {
                EmptyState(symbol: "flag", title: "Start with one thing you care about",
                           message: "Add a goal and we'll turn it into small steps and show you the next one.",
                           actionTitle: "Add a goal", action: onNew)
            } else {
                List {
                    Section {
                        ForEach(life.store.goals) { g in
                            NavigationLink(value: g.id) { GoalRow(goal: g) }
                        }
                        .onDelete { idx in let ids = idx.map { life.store.goals[$0].id }; Task { for id in ids { await life.deleteGoal(id) } } }
                    } header: { Text("Goals").font(.mission(.subheadline, .medium)) }
                    .listRowBackground(Tok.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(goal.title).font(.mission(.headline, .medium))
            MissionProgressBar(fraction: goal.fraction, label: "\(goal.steps.filter(\.isDone).count) of \(goal.steps.count) steps")
            if let n = goal.nextStep { Text("Next: \(n.title)").font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
            else if !goal.steps.isEmpty { Text("All steps done").font(.mission(.subheadline)).foregroundStyle(Tok.accent) }
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }
}

struct GoalDetail: View {
    @Environment(Life.self) private var life
    let goalID: UUID
    @State private var newStep = ""
    @State private var askObstacle = false

    private var goal: Goal? { life.store.goals.first { $0.id == goalID } }

    var body: some View {
        if let goal {
            List {
                Section {
                    if !goal.why.isEmpty { Text(goal.why).font(.mission(.body)).foregroundStyle(Tok.muted) }
                    MissionProgressBar(fraction: goal.fraction, label: "\(goal.steps.filter(\.isDone).count) of \(goal.steps.count) steps · \(goal.weeklyTarget) a week")
                }
                .listRowBackground(Tok.surface)
                Section {
                    ForEach(goal.steps) { s in
                        Button { Task { await life.setStep(goal: goal.id, step: s.id, done: !s.isDone) } } label: {
                            HStack(spacing: Space.m) {
                                Image(systemName: s.isDone ? "checkmark.circle.fill" : "circle").font(.mission(.title3)).foregroundStyle(s.isDone ? Tok.accent : Tok.muted)
                                Text(s.title).font(.mission(.body)).foregroundStyle(s.isDone ? Tok.muted : Tok.text).strikethrough(s.isDone)
                                Spacer()
                                Text("\(s.minutes) min").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                            }.frame(minHeight: 44)
                        }
                        .accessibilityLabel("\(s.title), \(s.minutes) minutes, \(s.isDone ? "done" : "not done")")
                    }
                    HStack {
                        TextField("Add a step", text: $newStep).font(.mission(.body)).onSubmit(add)
                        Button("Add", action: add).disabled(newStep.trimmed.isEmpty)
                    }
                } header: { Text("Steps").font(.mission(.subheadline, .medium)) }
                .listRowBackground(Tok.surface)
                Section {
                    Button { askObstacle = true } label: { Label("I keep putting this off", systemImage: "hourglass") }
                        .frame(minHeight: 44)
                } footer: { Text("Tell us what's in the way and we'll add a smaller first step.").font(.mission(.footnote)) }
                .listRowBackground(Tok.surface)
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(goal.title).navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("What's in the way?", isPresented: $askObstacle, titleVisibility: .visible) {
                ForEach(Obstacle.allCases) { o in Button(o.title) { Task { await life.shrink(goal: goal.id, obstacle: o) } } }
            }
        }
    }

    private func add() {
        let t = newStep.trimmed
        guard !t.isEmpty else { return }
        newStep = ""
        Task { await life.addStep(goal: goalID, title: t, minutes: 15) }
    }
}

struct NewGoalSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var why = ""
    @State private var weekly = 3

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("What do you want to make progress on?", text: $title) }
                Section("Why it matters (optional)") { TextField("In a sentence", text: $why, axis: .vertical) }
                Section { Stepper("\(weekly) steps a week", value: $weekly, in: 1...14) } footer: { Text("A small weekly commitment you can keep beats a big one you drop.") }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("New goal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await life.addGoal(title: title.trimmed, why: why.trimmed, weeklyTarget: weekly); dismiss() } }.disabled(title.trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
