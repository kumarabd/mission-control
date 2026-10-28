import SwiftUI

/// What memory holds about one entity, newest first.
struct EntityMemoryDetail: View {
    var entity: SemanticMemory.Entity
    var service: MemoryService
    @State private var page: EntityMemory.Page?
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let page {
                    if page.items.isEmpty {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("Nothing remembered yet").font(.mission(.headline, .medium))
                            Text("Your assistant hasn't connected \(entity.name) to anything else yet.")
                                .font(.mission(.body)).foregroundStyle(Tok.muted)
                        }
                    } else {
                        ForEach(page.items) { item in
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(item.label).font(.missionMono(.caption, .medium)).foregroundStyle(Tok.accent)
                                Text(item.text).font(.mission(.body))
                                Text(item.mentionTime.formatted(date: .abbreviated, time: .omitted))
                                    .font(.mission(.caption)).foregroundStyle(Tok.muted)
                            }
                            .padding(.bottom, Space.s)
                            .accessibilityElement(children: .combine)
                        }
                        if page.hasMore {
                            Text("Showing the most recent memory connected to \(entity.name).")
                                .font(.mission(.footnote)).foregroundStyle(Tok.muted)
                        }
                    }
                } else if let failure {
                    Text(failure).font(.mission(.body))
                    Button("Try again") { Task { await load() } }
                } else {
                    ProgressView("Loading related memory…")
                }
            }
            .padding(Space.xl)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tok.background)
        .navigationTitle(entity.name)
        .task { await load() }
    }

    private func load() async {
        failure = nil
        do { page = try await service.entityFacts(entityID: entity.id) }
        catch { if !Task.isCancelled { failure = (error as? MemoryReadError)?.message ?? "Couldn't load related memory." } }
    }
}

/// The supporting memory behind an insight.
struct SemanticSourceDetail: View {
    var parent: String
    var source: SemanticMemory.Source
    var service: MemoryService
    @State private var item: SemanticMemory.Item?
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let item {
                    if let date = item.updatedAt {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.mission(.caption)).foregroundStyle(Tok.muted)
                    }
                    if let content = item.content { MarkdownView(text: content) }
                    else { Text("No readable content is available.") }
                    if item.truncated {
                        Text("This is a shortened view.").font(.mission(.footnote)).foregroundStyle(Tok.muted)
                    }
                } else if let failure {
                    Text(failure).font(.mission(.body))
                    Button("Try again") { Task { await load() } }
                } else {
                    ProgressView("Loading supporting memory…")
                }
            }
            .padding(Space.xl)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tok.background)
        .navigationTitle(source.title)
        .task { await load() }
    }

    private func load() async {
        failure = nil
        do { item = try await service.source(parent: parent, id: source.id) }
        catch { if !Task.isCancelled { failure = (error as? MemoryReadError)?.message ?? "Couldn't load this source." } }
    }
}
