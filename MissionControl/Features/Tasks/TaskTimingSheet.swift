import SwiftUI
import SwiftData

struct TaskTimingFields: View {
    @Binding var hasTime: Bool
    @Binding var scheduledAt: Date

    var body: some View {
        Section {
            Toggle(isOn: $hasTime) { Label("Specific time", systemImage: "clock") }
            if hasTime {
                DatePicker("When", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
            } else {
                Label("Anytime · no deadline", systemImage: "sun.max")
                    .foregroundStyle(MissionTheme.quietText)
            }
        } header: {
            Text("Timing")
        } footer: {
            Text(hasTime ? "Shown at this time on your dashboard. This does not send a notification."
                 : "Stays in For today until completed. No time or deadline is assigned.")
        }
    }
}

struct TaskTimingLabel: View {
    let date: Date?

    var body: some View {
        Group {
            if let date {
                Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
            } else {
                Label("Anytime · no deadline", systemImage: "sun.max")
            }
        }.font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
    }
}

struct TaskTimingSheet: View {
    let task: MissionTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var hasTime: Bool
    @State private var scheduledAt: Date
    @State private var saveError: String?

    init(task: MissionTask) {
        self.task = task
        _hasTime = State(initialValue: task.scheduledAt != nil)
        _scheduledAt = State(initialValue: task.scheduledAt ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(task.title) }
                TaskTimingFields(hasTime: $hasTime, scheduledAt: $scheduledAt)
            }
            .scrollContentBackground(.hidden).background(MissionTheme.canvas)
            .navigationTitle("Task timing").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
        .foregroundStyle(MissionTheme.ink).tint(MissionTheme.tint)
        .alert("Couldn’t save time", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "Please try again.") }
    }

    private func save() {
        let previous = task.scheduledAt
        task.scheduledAt = hasTime ? scheduledAt : nil
        do { try modelContext.save(); dismiss() }
        catch { task.scheduledAt = previous; saveError = error.localizedDescription }
    }
}
