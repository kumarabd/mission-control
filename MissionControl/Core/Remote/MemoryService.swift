import Foundation

/// Agent-brain projections are data, never instructions or editable local records.
enum SemanticMemory {
    struct Entity: Codable, Equatable, Identifiable { var id: String; var name: String }
    struct Source: Codable, Equatable, Identifiable { var id: String; var title: String; var available: Bool }
    struct Item: Codable, Equatable, Identifiable {
        var id: String; var kind: String; var title: String; var content: String?
        var updatedAt: Date?; var createdAt: Date; var availability: String; var sourceStatus: String
        var entities: [Entity]; var truncated: Bool; var sources: [Source]?
        var label: String {
            switch kind { case "observation": "Observation"; case "personal_model": "Personal understanding"; case "mental_model": "Reflection"; default: "Insight" }
        }
    }
    struct Page: Codable, Equatable {
        var schemaVersion: Int; var section: String; var retrievedAt: Date; var bankAvailable: Bool
        var items: [Item]; var hasMore: Bool; var offset: Int; var limit: Int
    }
    enum Section: String, CaseIterable, Identifiable {
        case reflections, aboutYou = "about_you"
        var id: String { rawValue }
        var title: String { self == .reflections ? "Reflections" : "About you" }
    }
}

enum MemoryReadError: Error, Equatable {
    case signedOut, unavailable, upgradeNeeded, invalidResponse, network, sourceUnavailable
    var message: String {
        switch self {
        case .signedOut: "Please sign in again to read your memory."
        case .unavailable: "Memory isn't available right now. Try again in a moment."
        case .upgradeNeeded: "Your workspace needs the memory service update to show semantic views."
        case .invalidResponse: "Memory returned an unreadable response. Try again later."
        case .sourceUnavailable: "This supporting memory is no longer available."
        case .network: "Couldn't reach your memory. Check your connection and try again."
        }
    }
}
struct MemoryService {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)
    var baseURL: String
    var token: () async -> String?
    var transport: Transport = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw MemoryReadError.invalidResponse }
        return (data, response)
    }
    func page(section: SemanticMemory.Section, query: String, offset: Int = 0) async throws -> SemanticMemory.Page {
        let data = try await read(path: "/v1/explorer/semantic", query: [URLQueryItem(name: "section", value: section.rawValue), URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "20"), URLQueryItem(name: "offset", value: String(offset))])
        let page: SemanticMemory.Page
        do { page = try Wire.decoder.decode(SemanticMemory.Page.self, from: data) } catch { throw MemoryReadError.invalidResponse }
        guard page.schemaVersion == 1, page.section == section.rawValue, page.offset == offset, page.limit > 0 else { throw MemoryReadError.invalidResponse }
        return page
    }
    func source(parent: String, id: String) async throws -> SemanticMemory.Item {
        let data = try await read(path: "/v1/explorer/semantic-source", query: [URLQueryItem(name: "parent", value: parent), URLQueryItem(name: "source", value: id)])
        let item: SemanticMemory.Item
        do { item = try Wire.decoder.decode(SemanticMemory.Item.self, from: data) } catch { throw MemoryReadError.invalidResponse }
        guard item.id == id else { throw MemoryReadError.invalidResponse }
        return item
    }
    private func read(path: String, query: [URLQueryItem]) async throws -> Data {
        guard let bearer = await token(), !bearer.isEmpty else { throw MemoryReadError.signedOut }
        guard var url = URLComponents(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) else { throw MemoryReadError.invalidResponse }
        url.queryItems = query
        guard let target = url.url else { throw MemoryReadError.invalidResponse }
        var request = URLRequest(url: target, timeoutInterval: 30)
        request.httpMethod = "GET"; request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport(request) }
        catch { if Task.isCancelled { throw CancellationError() }; throw MemoryReadError.network }
        switch response.statusCode {
        case 200: return data
        case 401, 403: throw MemoryReadError.signedOut
        case 404: throw path.hasSuffix("semantic-source") ? MemoryReadError.sourceUnavailable : MemoryReadError.upgradeNeeded
        default: throw MemoryReadError.unavailable
        }
    }

}
