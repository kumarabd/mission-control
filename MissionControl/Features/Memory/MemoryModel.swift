import Foundation
import Observation

@MainActor @Observable
final class MemoryModel {
    /// The world model loads on its own, apart from the feed's pagination, and keeps its last good picture if a
    /// later refresh fails.
    enum WorldState: Equatable {
        case idle, loading
        case ready(SemanticWorld.Graph)
        case empty
        case failed(String)

        var graph: SemanticWorld.Graph? { if case .ready(let graph) = self { return graph }; return nil }
    }

    private(set) var items: [SemanticMemory.Item] = []
    private(set) var loaded = false
    private(set) var loading = false
    private(set) var failure: String?
    private(set) var hasMore = false
    private(set) var bankAvailable = true
    private(set) var retrievedAt: Date?
    private(set) var world: WorldState = .idle
    private(set) var worldLoaded = false
    private var worldLoading = false
    private var generation = 0
    private var offset = 0
    private var key = ""

    func load(service: MemoryService, section: SemanticMemory.Section, query: String, more: Bool = false) async {
        let requested = section.rawValue + ":" + query
        if more { guard !loading, hasMore, requested == key else { return } }
        else {
            generation += 1
            if requested != key { items = []; loaded = false; retrievedAt = nil; offset = 0; hasMore = false; bankAvailable = true }
            key = requested
        }
        let current = generation
        loading = true; failure = nil
        defer { if current == generation { loading = false } }
        do {
            let page = try await service.page(section: section, query: query, offset: more ? offset : 0)
            guard !Task.isCancelled, current == generation else { return }
            if more {
                let known = Set(items.map(\.id)); items += page.items.filter { !known.contains($0.id) }
            } else { items = page.items }
            offset = page.offset + page.items.count
            hasMore = page.hasMore; bankAvailable = page.bankAvailable; retrievedAt = page.retrievedAt; loaded = true
        } catch {
            if !Task.isCancelled, current == generation { failure = (error as? MemoryReadError)?.message ?? "Couldn't load memory. Try again." }
        }
    }

    /// Reads the world model. A failed refresh keeps the last good picture; only a first load shows the failure.
    func loadWorld(service: MemoryService, force: Bool = false) async {
        guard !worldLoading, force || !worldLoaded else { return }
        worldLoading = true
        defer { worldLoading = false }
        if world.graph == nil { world = .loading }
        do {
            let graph = try await service.world()
            world = graph.bankAvailable && !graph.nodes.isEmpty ? .ready(graph) : .empty
            worldLoaded = true
        } catch {
            if Task.isCancelled { if world == .loading { world = .idle }; return }
            if world.graph == nil { world = .failed((error as? MemoryReadError)?.message ?? "Couldn't load your world.") }
        }
    }
}
