import SwiftUI

struct TaskRowView: View {
    @Bindable var task: MissionTask
    let onDelete: () -> Void

    var body: some View {
        Button {
            task.isCompleted.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                Text(task.title)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                Spacer()
            }
            .frame(minHeight: 44)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: task.isCompleted)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Task", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(task.title), \(task.isCompleted ? "completed" : "not completed")")
        .accessibilityHint("Double tap to mark \(task.isCompleted ? "incomplete" : "complete")")
    }
}
