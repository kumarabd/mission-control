import SwiftUI

struct MemoryView: View {
    @Environment(Life.self) private var life
    @State private var query = ""
    @State private var showReview = false
    @State private var adding = false

    var body: some View {
        NavigationStack {
            let hits = life.search(query)
            Group {
                if hits.isEmpty && query.isEmpty {
                    EmptyState(symbol: "brain.head.profile", title: "Nothing saved yet",
                               message: "Capture a decision and why you made it, or a moment worth keeping. Later, search for it in your own words.",
                               actionTitle: "Save a memory") { adding = true }
                } else {
                    List {
                        Section {
                            Button { showReview = true } label: {
                                Label("What should I change next week?", systemImage: "chart.bar.doc.horizontal").frame(minHeight: 44)
                            }
                        }
                        .listRowBackground(Tok.surface)
                        Section {
                            if hits.isEmpty { Text("No matches for \u{201C}\(query)\u{201D}.").font(.mission(.body)).foregroundStyle(Tok.muted) }
                            ForEach(hits) { h in
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Label(h.label, systemImage: h.symbol).font(.missionMono(.caption, .medium)).foregroundStyle(Tok.accent)
                                    Text(h.text).font(.mission(.body))
                                    if let r = h.reason, !r.isEmpty { Text("Because: \(r)").font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
                                    Text(h.date.formatted(date: .abbreviated, time: .omitted)).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                                }
                                .padding(.vertical, Space.xs).accessibilityElement(children: .combine)
                            }
                        }
                        .listRowBackground(Tok.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .screenBackground()
            .navigationTitle("Memory")
            .searchable(text: $query, prompt: "Search what you've saved")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Save a memory")
                }
            }
            .sheet(isPresented: $showReview) { WeeklyReviewSheet() }
            .sheet(isPresented: $adding) { NewMemorySheet() }
        }
    }
}

struct WeeklyReviewSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let r = life.weeklyReview()
        NavigationStack {
            List {
                Section("Last 7 days") {
                    stat("Planned work finished", "\(r.done) of \(r.planned)")
                    stat("Goal steps done", "\(r.stepsDone)")
                    stat("Routine check-ins", "\(r.routineDays)")
                    stat("Journal entries", "\(r.entries)")
                }
                .listRowBackground(Tok.surface)
                Section("Change for next week") { Text(r.change).font(.mission(.body)) }
                    .listRowBackground(Tok.surface)
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Weekly review").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.mission(.body)); Spacer(); Text(value).font(.missionMono(.body, .medium)) }
            .frame(minHeight: 44).accessibilityElement(children: .combine)
    }
}

struct NewMemorySheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var reason = ""
    @State private var kind: MemoryKind = .decision

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) { ForEach(MemoryKind.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                Section { TextField(kind == .decision ? "What did you decide?" : "What do you want to keep?", text: $text, axis: .vertical).lineLimit(2...6) }
                if kind == .decision { Section("Why") { TextField("The reason, so you remember it later", text: $reason, axis: .vertical) } }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Save a memory").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await life.addMemory(Memory(text: text.trimmed, reason: reason.trimmed.isEmpty ? nil : reason.trimmed, kind: kind)); dismiss() } }
                        .disabled(text.trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
