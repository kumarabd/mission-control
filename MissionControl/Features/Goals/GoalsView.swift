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
            } else if !life.workspaceLoaded {
                ProgressView("Loading goals…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = life.goalsLoadError, life.goals.isEmpty {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load goals", message: error, actionTitle: "Try again") { Task { await life.loadGoals() } }
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
            } else if !goal.steps.isEmpty {
                Text("\(goal.progress.done) of \(goal.progress.total) milestones completed").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
            } else {
                Text(routines == 0 ? "No routines yet" : "Just started").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
            }
            if routines > 0 { Label("\(routines) \(routines == 1 ? "routine" : "routines")", systemImage: "repeat").font(.mission(.caption)).foregroundStyle(Tok.muted) }
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }
}

/// A goal with no view for this device shows its basic review until the assistant adds one.
struct GoalReview: View {
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    let goalID: String
    @State private var openRoutine: RoutineRef?

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

                if routines.isEmpty {
                    Section {
                        Button { chat.request(draft: "Link the routines I already have that serve \u{201C}\(goal.title)\u{201D}, add any that are missing, and replace repeating steps with routines.") } label: {
                            Label("No routines serve this goal yet. Set them up with your assistant", systemImage: "repeat")
                        }.frame(minHeight: 44)
                    }
                    .listRowBackground(Tok.surface)
                }

                if !goal.steps.isEmpty {
                    Section {
                        ForEach(goal.steps) { s in
                            HStack(spacing: Space.m) {
                                // A flag, not a checkbox: nothing here can be ticked.
                                Image(systemName: s.doneAt != nil ? "flag.checkered" : "flag").font(.mission(.body))
                                    .foregroundStyle(s.doneAt != nil ? Tok.accent : Tok.muted).frame(width: 24).accessibilityHidden(true)
                                Text(s.title).font(.mission(.body)).foregroundStyle(s.doneAt != nil ? Tok.muted : Tok.text)
                                Spacer()
                                Text("\(s.minutes) min").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                            }
                            .frame(minHeight: 44).accessibilityElement(children: .combine)
                            .accessibilityLabel("\(s.title), \(s.minutes) minutes, \(s.doneAt != nil ? "done" : "not done")")
                        }
                    } header: { Text("One-off steps").font(.mission(.subheadline, .medium)) }
                    footer: { Text("Milestones done once. They come up under \u{201C}Do this next\u{201D} on Today.").font(.mission(.footnote)) }
                    .listRowBackground(Tok.surface)
                }

                Section {
                    Button { chat.request(draft: "About my goal \u{201C}\(goal.title)\u{201D}: ") } label: {
                        Label("Change this with your assistant", systemImage: "bubble.left")
                    }.frame(minHeight: 44)
                    Button { chat.request(draft: "I keep putting off \u{201C}\(goal.title)\u{201D}. Help me make it smaller. ") } label: {
                        Label("I keep putting this off", systemImage: "hourglass")
                    }.frame(minHeight: 44)
                } footer: { Text("Routines, steps and the goal itself are set up and changed by your assistant, in Chat.").font(.mission(.footnote)) }
                .listRowBackground(Tok.surface)
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(goal.title).navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $openRoutine) { RoutineDetailView(id: $0.id) }
        } else {
            ContentUnavailableView("This goal is gone", systemImage: "flag", description: Text("It was archived or removed."))
        }
    }
}
