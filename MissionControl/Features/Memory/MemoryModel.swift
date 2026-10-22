import Foundation
import Observation

@MainActor @Observable
final class MemoryModel {
    /// A standing lens is one pinned mental model. It is deliberately separate
    /// from the feed's pagination state: three lenses load together, once, and
    /// keep their content if a later refresh fails.
    enum LensState: Equatable {
        case idle, loading
        case ready(SemanticMemory.Item)
        case empty
        case failed(String)

        var item: SemanticMemory.Item? { if case .ready(let item) = self { return item }; return nil }
        var isLoading: Bool { self == .loading }
    }

    private(set) var items: [SemanticMemory.Item] = []
    private(set) var loaded = false
    private(set) var loading = false
    private(set) var failure: String?
    private(set) var hasMore = false
    private(set) var bankAvailable = true
    private(set) var retrievedAt: Date?
    private(set) var lenses: [SemanticMemory.Lens: LensState] = [:]
    private(set) var lensesLoaded = false
    private var lensesLoading = false
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

    func lensState(_ lens: SemanticMemory.Lens) -> LensState { lenses[lens] ?? .idle }

    /// Reads all three lenses concurrently. A failed lens keeps its last good
    /// value; only a lens with nothing cached shows the failure.
    func loadLenses(service: MemoryService, force: Bool = false) async {
        guard !lensesLoading, force || !lensesLoaded else { return }
        lensesLoading = true
        for lens in SemanticMemory.Lens.allCases where lenses[lens]?.item == nil {
            lenses[lens] = .loading
        }
        let results = await withTaskGroup(of: (SemanticMemory.Lens, Result<SemanticMemory.Page, Error>).self) { group in
            for lens in SemanticMemory.Lens.allCases {
                group.addTask {
                    do { return (lens, .success(try await service.lens(lens))) }
                    catch { return (lens, .failure(error)) }
                }
            }
            var values: [(SemanticMemory.Lens, Result<SemanticMemory.Page, Error>)] = []
            for await value in group { values.append(value) }
            return values
        }
        for (lens, result) in results {
            switch result {
            case .success(let page):
                if page.bankAvailable, let item = page.items.first,
                   let content = item.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lenses[lens] = .ready(item)
                } else { lenses[lens] = .empty }
            case .failure(let error):
                if lenses[lens]?.item == nil {
                    lenses[lens] = .failed((error as? MemoryReadError)?.message ?? "Couldn't load \(lens.title.lowercased()).")
                }
            }
        }
        lensesLoaded = true
        lensesLoading = false
    }
}
