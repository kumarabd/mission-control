import SwiftUI

struct JournalView: View {
    @Environment(Life.self) private var life
    @State private var writing = false

    var body: some View {
        NavigationStack {
            Group {
                if life.store.journal.isEmpty {
                    EmptyState(symbol: "book", title: "Your day, in a few lines",
                               message: "Write or dictate what happened. It stays private, and helps you see what to change tomorrow.",
                               actionTitle: "Write an entry") { writing = true }
                } else {
                    List(life.store.journal.sorted { $0.date > $1.date }) { e in
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text(e.date.formatted(date: .complete, time: .shortened)).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                            Text(e.text).font(.mission(.body))
                            if let t = e.tomorrow, !t.isEmpty { Label(t, systemImage: "arrow.turn.down.right").font(.mission(.subheadline)).foregroundStyle(Tok.accent) }
                            let goals = life.store.goals.filter { e.goalIDs.contains($0.id) }
                            if !goals.isEmpty { Text(goals.map(\.title).joined(separator: " · ")).font(.mission(.caption)).foregroundStyle(Tok.muted) }
                        }
                        .padding(.vertical, Space.xs).listRowBackground(Tok.surface)
                        .accessibilityElement(children: .combine)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .screenBackground()
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { writing = true } label: { Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("New entry")
                }
            }
            .sheet(isPresented: $writing) { NewEntrySheet() }
        }
    }
}

struct NewEntrySheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var tomorrow = ""
    @State private var linked: Set<UUID> = []
    private let prompts = ["What went well?", "What was hard?", "What did I learn?"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("How was today?", text: $text, axis: .vertical).lineLimit(4...12).font(.mission(.body))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(prompts, id: \.self) { p in Chip(title: p) { text += (text.isEmpty || text.hasSuffix("\n") ? "" : "\n") + p + " " } } }
                    }
                } footer: { Text("Tap the keyboard's microphone to speak instead of typing.") }
                if !life.store.goals.isEmpty {
                    Section("Connect to a goal") {
                        ForEach(life.store.goals) { g in
                            Toggle(g.title, isOn: Binding(get: { linked.contains(g.id) }, set: { if $0 { linked.insert(g.id) } else { linked.remove(g.id) } }))
                        }
                    }
                }
                Section("One change for tomorrow (optional)") { TextField("e.g. Start with the hardest task", text: $tomorrow) }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("New entry").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await life.addJournal(text: text.trimmed, goals: Array(linked), tomorrow: tomorrow.trimmed.isEmpty ? nil : tomorrow.trimmed); dismiss() } }
                        .disabled(text.trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}
