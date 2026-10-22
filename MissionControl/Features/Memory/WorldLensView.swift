import SwiftUI

/// One row in "Your world". The icon carries the lens, the label says what it
/// means, and the preview is the thing the assistant currently believes — not a
/// decorative summary of the feature.
struct WorldLensRow: View {
    let lens: SemanticMemory.Lens
    let state: MemoryModel.LensState
    let index: Int
    var showsChevron = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            MissionIconBadge(symbol: lens.symbol, padding: 10)
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(lens.title).font(.mission(.headline, .medium)).layoutPriority(1)
                    Spacer(minLength: Space.s)
                    status.fixedSize()
                }
                Text(lens.blurb).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let preview {
                    Text(preview).font(.mission(.footnote)).foregroundStyle(Tok.muted)
                        .lineLimit(2)
                }
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.mission(.footnote, .semibold)).foregroundStyle(Tok.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 8)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion { appeared = true }
            else {
                withAnimation(.easeOut(duration: 0.35).delay(Double(index) * 0.06)) { appeared = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lens.title). \(lens.blurb) \(accessibilityStatus)")
    }

    private var accessibilityStatus: String {
        switch state {
        case .loading: "Loading."
        case .ready(let item): item.updatedAt.map { "Updated \($0.formatted(date: .abbreviated, time: .omitted))." } ?? ""
        case .empty: "No evidence yet."
        case .failed: "Unavailable."
        case .idle: ""
        }
    }

    @ViewBuilder private var status: some View {
        switch state {
        case .loading:
            ProgressView().controlSize(.mini)
        case .ready(let item):
            if let date = item.updatedAt {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
        case .empty:
            Text("No evidence").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
        case .failed:
            Text("Unavailable").font(.missionMono(.caption)).foregroundStyle(Tok.warn)
        case .idle:
            EmptyView()
        }
    }

    /// The first sentence-like line, not the document's markdown heading.
    private var preview: String? {
        guard case .ready(let item) = state, let content = item.content else { return nil }
        let line = content.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.hasPrefix("#") && !$0.hasPrefix("---") }
        guard let line else { return nil }
        return line
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "- ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

/// The full reading of one standing lens. It fetches its own copy so a direct
/// push is not dependent on the list's state, and it keeps the last good value
/// visible if a refresh fails.
struct WorldLensDetail: View {
    let lens: SemanticMemory.Lens
    var service: MemoryService
    var initialItem: SemanticMemory.Item?
    var onDiscuss: () -> Void
    @State private var state: MemoryModel.LensState
    @State private var heroIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(lens: SemanticMemory.Lens, service: MemoryService, initialItem: SemanticMemory.Item?, onDiscuss: @escaping () -> Void) {
        self.lens = lens
        self.service = service
        self.initialItem = initialItem
        self.onDiscuss = onDiscuss
        _state = State(initialValue: initialItem.map(MemoryModel.LensState.ready) ?? .loading)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                hero
                content
            }
            .padding(Space.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenBackground()
        .navigationTitle(lens.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: Space.l) {
            Image(systemName: lens.symbol)
                .font(.mission(.title, .medium))
                .foregroundStyle(Tok.accent)
                .padding(18)
                .background(Tok.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Tok.accent.opacity(0.18))
                }
                .accessibilityHidden(true)
                .scaleEffect(heroIn ? 1 : 0.9)
                .opacity(heroIn ? 1 : 0)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(lens.title).font(.mission(.title2, .semibold))
                Text(lens.blurb).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            if reduceMotion { heroIn = true }
            else { withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { heroIn = true } }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            HStack(spacing: Space.s) {
                ProgressView()
                Text("Reading \(lens.title.lowercased())…")
            }
            .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
        case .ready(let item):
            if let date = item.updatedAt {
                Text("Updated \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
            }
            SemanticItemBody(item: item, service: service, onDiscuss: onDiscuss)
        case .empty:
            VStack(alignment: .leading, spacing: Space.s) {
                Text("No evidence yet").font(.mission(.headline, .medium))
                Text(lens.emptyDetail).font(.mission(.body)).foregroundStyle(Tok.muted)
                Button("Talk with your assistant", systemImage: "bubble.left", action: onDiscuss)
                    .frame(minHeight: 44)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: Space.s) {
                Text(message).font(.mission(.body))
                Button("Try again") { Task { await load() } }.frame(minHeight: 44)
            }
        case .idle:
            EmptyView()
        }
    }

    private func load() async {
        let cached = state.item
        if cached == nil { state = .loading }
        do {
            let page = try await service.lens(lens)
            if page.bankAvailable, let item = page.items.first,
               let content = item.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state = .ready(item)
            } else { state = .empty }
        } catch {
            if cached == nil {
                state = .failed((error as? MemoryReadError)?.message ?? "Couldn't load \(lens.title.lowercased()).")
            }
        }
    }
}

/// The shared body of a semantic document: content, related context, evidence,
/// and the route back to the assistant. Used by Reflections and by the lenses,
/// so the two surfaces keep the same reading rules.
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
