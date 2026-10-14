import SwiftUI

struct MemoryView: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @State private var query = ""
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
                    .scrollContentBackground(.hidden).safeAreaPadding(.bottom, 80)
                }
            }
            .screenBackground()
            .navigationTitle("Memory")
            .searchable(text: $query, prompt: "Search what you've saved")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Save a memory")
                }
            }
            .sheet(isPresented: $adding) { NewMemorySheet() }
        }
    }
}

struct NewMemorySheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var reason = ""
    @State private var saving = false
    @State private var kind: MemoryKind = .decision

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) { ForEach(MemoryKind.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                Section { TextField(kind == .decision ? "What did you decide?" : "What do you want to keep?", text: $text, axis: .vertical).lineLimit(2...6) }
                if kind == .decision { Section("Why") { TextField("The reason, so you remember it later", text: $reason, axis: .vertical) } }
                Section { Text("Saved on this device.").font(.mission(.footnote)).foregroundStyle(Tok.muted) }
                if let error = life.error { Section { Text(error).foregroundStyle(Tok.critical) } }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Save a memory").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saving = true
                        Task {
                            if await life.addMemory(Memory(text: text.trimmed, reason: reason.trimmed.isEmpty ? nil : reason.trimmed, kind: kind)) { dismiss() }
                            saving = false
                        } }
                        .disabled(text.trimmed.isEmpty || saving)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
