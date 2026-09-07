import SwiftUI

struct TaskRowView: View {
    @Bindable var task: MissionTask

    var body: some View {
        Button { task.isCompleted.toggle() } label: {
            HStack(spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                Text(task.title)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                Spacer()
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(task.title), \(task.isCompleted ? "completed" : "not completed")")
    }
}
