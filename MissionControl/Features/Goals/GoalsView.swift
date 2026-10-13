import SwiftUI

struct GoalRef: Hashable, Identifiable { let id: String }

/// The goals list. They are the Life Engine's, so a goal the assistant makes is here. The Progress tab owns the navigation,
/// the title and the add button, and a new goal starts as a conversation with the assistant.
struct GoalsList: View {
    @Environment(Life.self) private var life
    let onNew: () -> Void

    var body: some View {
        Group {
            if !life.goalsAvailable {
                EmptyState(symbol: "icloud.slash", title: "Goals need your workspace", message: "They are kept with your assistant, which isn't reachable right now.")
            } else if life.goals.isEmpty {
                EmptyState(symbol: "flag", title: "Start with one thing you care about",
                           message: "Tell your assistant what you want to achieve and it will turn it into small steps and routines.",
                           actionTitle: "Tell your assistant", action: onNew)
            } else {
                List {
                    Section {
                        ForEach(life.goals) { g in NavigationLink(value: GoalRef(id: g.id)) { GoalRow(goal: g) } }
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
            Text(goal.title).font(.mission(.headline, .medium))
            if goal.progress.total > 0 {
                MissionProgressBar(fraction: Double(goal.progress.done) / Double(goal.progress.total), label: "\(goal.progress.done) of \(goal.progress.total) steps")
            }
            if let n = goal.nextStep { Text("Next: \(n.title)").font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
            else if goal.progress.total > 0 { Text("All steps done").font(.mission(.subheadline)).foregroundStyle(Tok.accent) }
            else { Text("No steps yet").font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }
}

struct GoalDetail: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    let goalID: String
    @State private var newStep = ""
    @State private var askAssistant: AssistantPrompt?
    @State private var confirmArchive = false

    struct AssistantPrompt: Identifiable { let id = UUID(); let text: String }

    private var goal: Wire.Goal? { life.goals.first { $0.id == goalID } }

    var body: some View {
        if let goal {
            List {
                Section {
                    if !goal.why.isEmpty { Text(goal.why).font(.mission(.body)).foregroundStyle(Tok.muted) }
                    if goal.progress.total > 0 {
                        MissionProgressBar(fraction: Double(goal.progress.done) / Double(goal.progress.total),
                                           label: "\(goal.progress.done) of \(goal.progress.total) steps · \(goal.weeklyTarget) a week")
                    }
                }
                .listRowBackground(Tok.surface)
                Section {
                    ForEach(goal.steps) { s in
                        Button { Task { await life.setStepDone(s, done: s.doneAt == nil) } } label: {
                            HStack(spacing: Space.m) {
                                Image(systemName: s.doneAt != nil ? "checkmark.circle.fill" : "circle").font(.mission(.title3)).foregroundStyle(s.doneAt != nil ? Tok.accent : Tok.muted)
                                Text(s.title).font(.mission(.body)).foregroundStyle(s.doneAt != nil ? Tok.muted : Tok.text).strikethrough(s.doneAt != nil)
                                Spacer()
                                Text("\(s.minutes) min").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                            }.frame(minHeight: 44)
                        }
                        .disabled(life.busySteps.contains(s.id))
                        .accessibilityLabel("\(s.title), \(s.minutes) minutes, \(s.doneAt != nil ? "done" : "not done")")
                    }
                    HStack {
                        TextField("Add a step", text: $newStep).font(.mission(.body)).onSubmit(add)
                        Button("Add", action: add).disabled(newStep.trimmed.isEmpty)
                    }
                } header: { Text("Steps").font(.mission(.subheadline, .medium)) }
                .listRowBackground(Tok.surface)
                Section {
                    Button { askAssistant = AssistantPrompt(text: "I keep putting off \u{201C}\(goal.title)\u{201D}. Help me make the next step smaller. ") } label: {
                        Label("I keep putting this off", systemImage: "hourglass")
                    }.frame(minHeight: 44)
                    Button { askAssistant = AssistantPrompt(text: "About my goal \u{201C}\(goal.title)\u{201D}: ") } label: {
                        Label("Talk to your assistant about this", systemImage: "bubble.left")
                    }.frame(minHeight: 44)
                } footer: { Text("The routines and reminders that serve it are set up by your assistant; ask it to change them.").font(.mission(.footnote)) }
                .listRowBackground(Tok.surface)
                Section { Button("Archive goal", systemImage: "archivebox", role: .destructive) { confirmArchive = true } }.listRowBackground(Tok.surface)
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(goal.title).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $askAssistant) { CaptureSheet(draft: $0.text).environment(life) }
            .confirmationDialog("Archive this goal?", isPresented: $confirmArchive, titleVisibility: .visible) {
                Button("Archive", role: .destructive) { Task { await life.archiveGoal(goal); dismiss() } }
            } message: { Text("It can be restored later.") }
        } else {
            ContentUnavailableView("This goal is gone", systemImage: "flag", description: Text("It was archived or removed."))
        }
    }

    private func add() {
        let t = newStep.trimmed
        guard !t.isEmpty else { return }
        newStep = ""
        Task { await life.addGoalStep(goal: goalID, title: t) }
    }
}
