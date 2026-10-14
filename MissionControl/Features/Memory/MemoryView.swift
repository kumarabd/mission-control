import SwiftUI

struct MemoryView: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @State private var query = ""

    var body: some View {
        NavigationStack {
            let hits = life.search(query)
            Group {
                if hits.isEmpty && query.isEmpty {
                    EmptyState(symbol: "brain.head.profile", title: "No saved memories on this device",
                               message: "Use Capture to discuss what your assistant should remember.")
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
                        } header: {
                            Text("Saved on this device").font(.mission(.subheadline, .medium))
                        } footer: {
                            Text("Use Capture to discuss or correct memory with your assistant.").font(.mission(.footnote))
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
            }
        }
    }
}
