import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: MissionTask
    let onDelete: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var saveError: String?
    @State private var showingTiming = false

    var body: some View {
        Button {
            task.isCompleted.toggle()
            do { try modelContext.save() }
            catch { task.isCompleted.toggle(); saveError = error.localizedDescription }
        } label: {
            HStack(spacing: 12) {
                MissionIconBadge(symbol: task.isCompleted ? "checkmark.circle" : "circle",
                                 color: task.isCompleted ? MissionTone.completed.color : MissionTone.focus.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? MissionTheme.quietText : MissionTheme.ink)
                    TaskTimingLabel(date: task.scheduledAt)
                }
                Spacer()
            }
            .frame(minHeight: 44)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(MissionPressStyle())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: task.isCompleted)
        .alert("Couldn’t save task", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "Please try again.") }
        .sensoryFeedback(.selection, trigger: task.isCompleted)
        .sheet(isPresented: $showingTiming) { TaskTimingSheet(task: task) }
        .contextMenu {
            Button("Set or change time", systemImage: "clock") { showingTiming = true }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Task", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(task.title), \(task.isCompleted ? "completed" : "not completed"), \(task.scheduledAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Anytime, no deadline")")
        .accessibilityAction(named: "Set or change time") { showingTiming = true }
        .accessibilityHint("Double tap to mark \(task.isCompleted ? "incomplete" : "complete")")
    }
}
