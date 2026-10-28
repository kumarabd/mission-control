import SwiftUI

/// One task or event, with everything the record holds and every action the
/// other clients can take on it.
struct TaskDetailView: View {
    let ref: ItemRef
    /// A pane closes by clearing its selection; a sheet dismisses itself.
    var onClose: (() -> Void)?
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss

    @State private var editing: Wire.Item?
    @State private var confirmDelete = false

    private var item: Wire.Item? { life.item(ref.id) }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if let item { details(item) }
                else {
                    ContentUnavailableView("This is gone", systemImage: "checklist",
                                           description: Text("It was finished a while ago or removed."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            actions
        }
        .background(Tok.background)
        .sheet(item: $editing) { item in
            ItemEditor(mode: .edit(item))
        }
        .confirmationDialog("Delete this?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let item else { return }
                Task { if await life.delete(item) { close() } }
            }
        } message: {
            Text("It is removed from your workspace for every client.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item?.isEvent == true ? "Event" : "Task")
                    .font(.missionMono(.caption, .medium))
                    .foregroundStyle(Tok.accent)
                Text(item?.title ?? "Task")
                    .font(.mission(.title3, .semibold))
                    .strikethrough(item?.isDone == true)
                    .foregroundStyle(item?.isDone == true ? Tok.muted : Tok.text)
            }
            Spacer()
            Button("Done") { close() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(Space.l)
    }

    private func details(_ item: Wire.Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if !item.notes.isEmpty {
                    Text(item.notes).font(.mission(.body)).foregroundStyle(Tok.text)
                }
                if let goal = life.goals.first(where: { $0.id == item.goalId }) {
                    Label("For \(goal.title)", systemImage: "flag")
                        .font(.mission(.subheadline))
                        .foregroundStyle(Tok.muted)
                }

                MissionCard {
                    VStack(alignment: .leading, spacing: Space.s) {
                        field("When", (ref.at ?? item.at).map {
                            $0.formatted(date: .complete, time: .shortened)
                        } ?? "No time set")
                        if let minutes = item.minutes { field("Length", "\(minutes) minutes") }
                        if let rule = item.repeatDescription { field("Repeats", rule) }
                        if let alert = item.alertDescription { field("Alert", alert) }
                        if let until = item.snoozedUntil, until > Date() {
                            field("Snoozed until", until.formatted(date: .abbreviated, time: .shortened))
                        }
                        field("Priority", item.isPriority ? "Yes" : "No")
                        field("Updated", item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if let error = life.error {
                    Text(error).font(.mission(.subheadline)).foregroundStyle(Tok.critical)
                }
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.missionMono(.caption))
                .foregroundStyle(Tok.muted)
                .frame(width: 100, alignment: .leading)
            Text(value).font(.mission(.body))
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var actions: some View {
        if let item {
            Divider()
            HStack(spacing: Space.s) {
                if item.isTask {
                    let done = ref.at == nil
                        ? item.isDone
                        : (life.day?.entries.first { $0.item.id == item.id && $0.at == ref.at }?.isDone ?? false)
                    Button(done ? "Mark not done" : "Mark done", systemImage: "checkmark.circle") {
                        Task { await life.complete(item, at: item.repeats ? ref.at : nil, done: !done) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                if item.alertBeforeMinutes != nil {
                    Button("Snooze 1 hour", systemImage: "moon.zzz") {
                        Task { await life.snooze(item, until: Date().addingTimeInterval(3600)) }
                    }
                }
                Button(item.isPriority ? "Remove priority" : "Make priority",
                       systemImage: item.isPriority ? "star.slash" : "star") {
                    var draft = ItemsService.Draft(item)
                    draft.isPriority.toggle()
                    Task { _ = await life.save(item, draft) }
                }
                Button("Edit", systemImage: "pencil") { editing = item }
                Spacer()
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }
            .disabled(life.busyItems.contains(item.id))
            .padding(Space.l)
        }
    }
}
