import SwiftUI

/// The shared body of a semantic document: content, related context, evidence,
/// and the route back to the assistant. Kept for the About you lens when it
/// returns; the Reflections feed is no longer shown.
struct SemanticItemBody: View {
    let item: SemanticMemory.Item
    var service: MemoryService
    var onDiscuss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if let content = item.content {
                MarkdownView(text: content)
            } else {
                Text("A summary isn't available yet. Your assistant updates understanding as new context is retained.")
                    .font(.mission(.body))
            }
            if item.truncated {
                Text("This is a shortened view of this item.")
                    .font(.mission(.footnote)).foregroundStyle(Tok.muted)
            }
            if !item.entities.isEmpty {
                Text("Related context").font(.mission(.headline, .medium)).accessibilityAddTraits(.isHeader)
                ForEach(item.entities) { entity in
                    NavigationLink { EntityMemoryDetail(entity: entity, service: service) } label: {
                        Text(entity.name).font(.mission(.body))
                    }.frame(minHeight: 44)
                }
            }
            DisclosureGroup("About this insight") {
                Text(item.sourceStatus == "not_recorded" ? "Source links weren't saved with this insight. Related context names describe associations, not supporting evidence." : "These memories informed the document. They aren't citations for individual claims.")
                    .font(.mission(.footnote)).foregroundStyle(Tok.muted).padding(.top, Space.s)
            }.font(.mission(.subheadline))
            if let sources = item.sources, !sources.isEmpty {
                Text("Supporting memory").font(.mission(.headline, .medium)).accessibilityAddTraits(.isHeader)
                ForEach(sources) { source in
                    if source.available {
                        NavigationLink { SemanticSourceDetail(parent: item.id, source: source, service: service) } label: {
                            Label(source.title, systemImage: "doc.text").frame(minHeight: 44)
                        }
                    } else {
                        Text("Source unavailable").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    }
                }
            }
            Button(action: onDiscuss) { Label("Discuss or correct this", systemImage: "bubble.left") }.frame(minHeight: 44)
            Text("Requests go to your assistant. This view updates when memory has actually refreshed.")
                .font(.mission(.footnote)).foregroundStyle(Tok.muted)
        }
    }
}
