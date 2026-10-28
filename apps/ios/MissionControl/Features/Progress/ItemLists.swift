import SwiftUI

/// Every open task, grouped by what the person needs from it: what is overdue, what repeats, what is coming, and what has no time.
struct TasksList: View {
    @Environment(Life.self) private var life
    let open: (ItemRef) -> Void
    let onNew: () -> Void

    private var groups: [(title: String, items: [Wire.Item])] {
        let now = Date()
        let tasks = life.openTasks
        let overdue = tasks.filter { !$0.repeats && ($0.at ?? .distantFuture) < Calendar.current.startOfDay(for: now) }
        let repeating = tasks.filter(\.repeats)
        let upcoming = tasks.filter { !$0.repeats && $0.at != nil && !overdue.contains($0) }
        let untimed = tasks.filter { $0.at == nil }
        return [("Overdue", overdue), ("Repeating", repeating), ("Coming up", upcoming), ("No time", untimed)].filter { !$0.1.isEmpty }
    }

    var body: some View {
        Group {
            if !life.workspaceAvailable {
                EmptyState(symbol: "icloud.slash", title: "Tasks need your workspace", message: "They are kept with your assistant, which isn't reachable right now.")
            } else if !life.workspaceLoaded {
                ProgressView("Loading tasks…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = life.dayLoadError, life.openTasks.isEmpty {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load tasks", message: error, actionTitle: "Try again") { Task { await life.loadDay() } }
            } else if life.openTasks.isEmpty {
                EmptyState(symbol: "checklist", title: "Nothing to do", message: "Add a task, or ask your assistant to remind you of something.", actionTitle: "Add a task", action: onNew)
            } else {
                List {
                    ForEach(groups, id: \.title) { group in
                        Section {
                            ForEach(group.items) { item in row(item) }
                        } header: { Text(group.title).font(.mission(.subheadline, .medium)) }
                        .listRowBackground(Tok.surface)
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable { await life.loadDay() }
            }
        }
        .task { await life.loadDay() }
    }

    private func row(_ item: Wire.Item) -> some View {
        Button { open(ItemRef(id: item.id)) } label: {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(item.title).font(.mission(.body)).foregroundStyle(Tok.text)
                Text(detail(item)).font(.mission(.caption)).foregroundStyle(Tok.muted)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.borderless)
    }

    private func detail(_ item: Wire.Item) -> String {
        var parts: [String] = []
        if let rule = item.repeatDescription { parts.append(rule) }
        else if let at = item.at { parts.append(at.formatted(date: .abbreviated, time: .shortened)) }
        if item.alertBeforeMinutes != nil { parts.append("Alert") }
        if let goal = life.goals.first(where: { $0.id == item.goalId })?.title { parts.append(goal) }
        return parts.joined(separator: " · ")
    }
}

/// Events from now on.
struct EventsList: View {
    @Environment(Life.self) private var life
    let open: (ItemRef) -> Void
    let onNew: () -> Void

    var body: some View {
        Group {
            if !life.workspaceAvailable {
                EmptyState(symbol: "icloud.slash", title: "Events need your workspace", message: "They are kept with your assistant, which isn't reachable right now.")
            } else if !life.workspaceLoaded {
                ProgressView("Loading events…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if life.upcomingEvents.isEmpty {
                EmptyState(symbol: "calendar", title: "Nothing coming up", message: "Add something that happens at a time: a meeting, a flight, a dinner.", actionTitle: "Add an event", action: onNew)
            } else {
                List {
                    Section {
                        ForEach(life.upcomingEvents) { item in
                            Button { open(ItemRef(id: item.id)) } label: {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text(item.title).font(.mission(.body)).foregroundStyle(Tok.text)
                                    Text(item.repeatDescription ?? (item.at?.formatted(date: .complete, time: .shortened) ?? "")).font(.mission(.caption)).foregroundStyle(Tok.muted)
                                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.borderless)
                        }
                    } header: { Text("Coming up").font(.mission(.subheadline, .medium)) }
                    .listRowBackground(Tok.surface)
                }
                .scrollContentBackground(.hidden)
                .refreshable { await life.loadDay() }
            }
        }
        .task { await life.loadDay() }
    }
}
