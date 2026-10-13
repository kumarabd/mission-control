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
    private var routines: Int { (goal.routineIds ?? []).count }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(goal.title).font(.mission(.headline, .medium))
            if let c = goal.consistency, c.last30.scheduled > 0 {
                MissionProgressBar(fraction: Double(c.last30.done) / Double(c.last30.scheduled), label: "\(c.last30.done) of \(c.last30.scheduled) routine days kept")
            } else {
                Text(routines == 0 ? "No routines yet" : "Just started").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
            }
            if routines > 0 { Label("\(routines) \(routines == 1 ? "routine" : "routines")", systemImage: "repeat").font(.mission(.caption)).foregroundStyle(Tok.muted) }
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }
}

/// A goal is for review. Its progress is how well the routines that serve it are kept; nothing here records, ticks or changes anything.
/// To change a goal, ask the assistant.
struct GoalDetail: View {
    @Environment(Life.self) private var life
    let goalID: String
    @State private var askAssistant: AssistantPrompt?
    @State private var openRoutine: RoutineRef?

    struct AssistantPrompt: Identifiable { let id = UUID(); let text: String }

    private var goal: Wire.Goal? { life.goals.first { $0.id == goalID } }

    var body: some View {
        if let goal {
            List {
                Section {
                    MarkdownView(text: Overview.goal(goal))
                    if let c = goal.consistency, c.last30.scheduled > 0 {
                        MissionProgressBar(fraction: Double(c.last30.done) / Double(c.last30.scheduled), label: "Routines kept, last 30 days")
                    }
                }
                .listRowBackground(Tok.surface)

                let routines = life.routines.filter { (goal.routineIds ?? []).contains($0.id) }
                if !routines.isEmpty {
                    Section {
                        ForEach(routines) { r in RoutineRow(status: r, interactive: false) { openRoutine = RoutineRef(id: r.id) } }
                    } header: { Text("Routines that serve it").font(.mission(.subheadline, .medium)) }
                    footer: { Text("Record them from their own screen or from Today.").font(.mission(.footnote)) }
                    .listRowBackground(Tok.surface)
                }

                if !goal.steps.isEmpty {
                    Section {
                        ForEach(goal.steps) { s in
                            HStack(spacing: Space.m) {
                                Image(systemName: s.doneAt != nil ? "checkmark.circle.fill" : "circle").font(.mission(.title3))
                                    .foregroundStyle(s.doneAt != nil ? Tok.accent : Tok.muted).accessibilityHidden(true)
                                Text(s.title).font(.mission(.body)).foregroundStyle(s.doneAt != nil ? Tok.muted : Tok.text)
                                Spacer()
                                Text("\(s.minutes) min").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                            }
                            .frame(minHeight: 44).accessibilityElement(children: .combine)
                            .accessibilityLabel("\(s.title), \(s.minutes) minutes, \(s.doneAt != nil ? "done" : "not done")")
                        }
                    } header: { Text("One-off steps").font(.mission(.subheadline, .medium)) }
                    footer: { Text("Tasks done once. Tell your assistant when one is done.").font(.mission(.footnote)) }
                    .listRowBackground(Tok.surface)
                }

                Section {
                    Button { askAssistant = AssistantPrompt(text: "About my goal \u{201C}\(goal.title)\u{201D}: ") } label: {
                        Label("Change this with your assistant", systemImage: "bubble.left")
                    }.frame(minHeight: 44)
                    Button { askAssistant = AssistantPrompt(text: "I keep putting off \u{201C}\(goal.title)\u{201D}. Help me make it smaller. ") } label: {
                        Label("I keep putting this off", systemImage: "hourglass")
                    }.frame(minHeight: 44)
                } footer: { Text("Routines, steps and the goal itself are set up and changed by your assistant.").font(.mission(.footnote)) }
                .listRowBackground(Tok.surface)
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(goal.title).navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $openRoutine) { RoutineDetailView(id: $0.id) }
            .sheet(item: $askAssistant) { CaptureSheet(draft: $0.text).environment(life) }
        } else {
            ContentUnavailableView("This goal is gone", systemImage: "flag", description: Text("It was archived or removed."))
        }
    }
}
