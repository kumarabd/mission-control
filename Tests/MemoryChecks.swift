import Foundation

@MainActor final class DelayedMemory {
    var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
}
@main struct MemoryChecks {
    @MainActor static func main() async throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        let reflections = try Data(contentsOf: dir.appendingPathComponent("reflections.json"))
        let profile = try Data(contentsOf: dir.appendingPathComponent("profile.json"))
        let profilePage = try Wire.decoder.decode(SemanticMemory.Page.self, from: profile)
        let source = try Data(contentsOf: dir.appendingPathComponent("source.json"))
        func response(_ request: URLRequest, _ code: Int = 200) -> HTTPURLResponse {
            HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        }
        let api = MemoryService(baseURL: "https://test.invalid/brain", token: { "test-token" }, transport: { request in
            precondition(request.httpMethod == "GET")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            let url = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let q = Dictionary(uniqueKeysWithValues: url.queryItems!.map { ($0.name,$0.value!) })
            precondition(q["bank_id"] == nil)
            if url.path.hasSuffix("semantic-source") { precondition(q["parent"] == "model:work"); return (source,response(request)) }
            if q["section"] == "about_you" { return (profile,response(request)) }
            if q["q"] == "a & b" { precondition(url.queryItems!.first(where: {$0.name == "q"})!.value == "a & b") }
            return (reflections,response(request))
        })
        let page = try await api.page(section: .reflections, query: "a & b")
        precondition(page.items.count == 2 && page.bankAvailable)
        precondition(page.items.contains { $0.sourceStatus == "partly_available" })
        let cited = try await api.source(parent: "model:work", id: "memory:10000000-0000-0000-0000-000000000002")
        precondition(cited.content != nil)
        for (code,error) in [(401,MemoryReadError.signedOut),(404,.upgradeNeeded),(503,.unavailable)] {
            let service = MemoryService(baseURL: api.baseURL, token: { "t" }, transport: { request in (Data(), response(request,code)) })
            do { _ = try await service.page(section: .reflections,query: ""); preconditionFailure("status accepted") }
            catch let e as MemoryReadError { precondition(e == error) }
        }
        let model = MemoryModel()
        await model.load(service: api, section: .reflections, query: "")
        precondition(model.loaded && !model.loading && model.items.count == 2)
        let offline = MemoryService(baseURL: api.baseURL, token: { "t" }, transport: { _ in throw URLError(.notConnectedToInternet) })
        await model.load(service: offline, section: .reflections, query: "")
        precondition(model.items == page.items && model.failure != nil && !model.loading)
        var first = page; first.hasMore = true
        let paginated = MemoryService(baseURL: api.baseURL, token: { "t" }, transport: { request in
            let q = URLComponents(url:request.url!,resolvingAgainstBaseURL:false)!.queryItems!
            let offset = Int(q.first(where:{$0.name=="offset"})!.value!)!
            var next = first; next.offset = offset
            if offset > 0 { precondition(offset == 2); next.hasMore = false }
            return (try Wire.encoder.encode(next),response(request))
        })
        await model.load(service: paginated,section:.reflections,query: "")
        await model.load(service: offline,section:.reflections,query: "")
        await model.load(service: paginated,section:.reflections,query: "",more:true)
        precondition(model.items.count == 2 && !model.hasMore && model.failure == nil)
        await model.load(service: offline,section:.aboutYou,query: "different")
        precondition(model.items.isEmpty && !model.loaded && !model.hasMore)
        let missingSource = MemoryService(baseURL:api.baseURL,token:{"t"},transport:{request in (Data(),response(request,404))})
        do { _ = try await missingSource.source(parent:"model:work",id:cited.id); preconditionFailure("missing source accepted") }
        catch let error as MemoryReadError { precondition(error == .sourceUnavailable) }
        let delayed = DelayedMemory()
        let slow = MemoryService(baseURL: api.baseURL, token: { "t" }, transport: { try await delayed.send($0) })
        let old = Task { await model.load(service: slow, section: .reflections, query: "") }
        while delayed.continuation == nil { await Task.yield() }
        await model.load(service: api, section: .aboutYou, query: "")
        let request = URLRequest(url: URL(string:"https://test.invalid")!)
        delayed.continuation!.resume(returning: (reflections,response(request)))
        await old.value
        precondition(model.items.first?.kind == "personal_model" && !model.loading)
        let cancelled = Task { await model.load(service: offline, section: .aboutYou, query: "") }
        cancelled.cancel(); await cancelled.value
        precondition(!model.loading)
        let pending = try Wire.decoder.decode(SemanticMemory.Page.self, from: Data(contentsOf:dir.appendingPathComponent("profile_not_ready.json")))
        precondition(pending.items[0].availability == "not_ready")

        // The world model: one projection route, decoded as sent, loaded into the model, and kept on failure.
        let worldJSON = """
        {"schema_version":1,"retrieved_at":"2026-10-25T10:00:00Z","bank_available":true,"truncated":false,"limit":100,
         "nodes":[{"id":"entity:a","kind":"entity","subtype":"person","label":"Dana","attributes":{"role":"lead","city":"Lisbon"},"mention_count":9},
                  {"id":"entity:b","kind":"entity","subtype":"company","label":"Acme","mention_count":4},
                  {"id":"entity:c","kind":"entity","label":"Mara","mention_count":1}],
         "edges":[{"from":"entity:a","to":"entity:b","type":"relation","label":"works_at","source_count":2}]}
        """
        var worldPaths: [String] = []
        let worldAPI = MemoryService(baseURL: api.baseURL, token: { "t" }, transport: { request in
            worldPaths.append(request.url!.path)
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            precondition(q.first { $0.name == "limit" }?.value == "100")
            return (Data(worldJSON.utf8), response(request))
        })
        let graph = try await worldAPI.world()
        precondition(worldPaths == ["/brain/v1/explorer/semantic/world"], "\(worldPaths)")
        precondition(graph.nodes.count == 3 && graph.edges.count == 1)
        precondition(graph.nodes[0].entityID == "a" && graph.nodes[0].typeName == "person")
        precondition(graph.nodes[0].sortedAttributes.map(\.key) == ["city", "role"], "attributes read in a stable order")
        precondition(graph.nodes[2].typeName == nil && graph.nodes[2].attributes == nil, "an entity with no profile has no type")
        precondition(graph.edges[0].phrase == "works at" && graph.edges[0].sourceCount == 2)
        precondition(graph.relatedCount == 2)
        let worldModel = MemoryModel()
        await worldModel.loadWorld(service: worldAPI)
        precondition(worldModel.worldLoaded && worldModel.world.graph?.nodes.count == 3)
        await worldModel.loadWorld(service: offline, force: true)
        precondition(worldModel.world.graph?.nodes.count == 3, "a failed refresh keeps the last good world")
        let failingWorld = MemoryModel()
        await failingWorld.loadWorld(service: offline)
        if case .failed = failingWorld.world {} else { preconditionFailure("a first load that fails shows the failure") }
        let noWorld = MemoryService(baseURL: api.baseURL, token: { "t" }, transport: { request in
            (Data(#"{"schema_version":1,"retrieved_at":"2026-10-25T10:00:00Z","bank_available":true,"nodes":[],"edges":[],"truncated":false,"limit":100}"#.utf8), response(request))
        })
        let emptyWorld = MemoryModel()
        await emptyWorld.loadWorld(service: noWorld)
        precondition(emptyWorld.world == .empty)
        let oldServer = MemoryService(baseURL: api.baseURL, token: { "t" }, transport: { request in (Data(), response(request, 404)) })
        do { _ = try await oldServer.world(); preconditionFailure("an older server has no world route") }
        catch let error as MemoryReadError { precondition(error == .upgradeNeeded) }
        let badSchema = MemoryService(baseURL: api.baseURL, token: { "t" }, transport: { request in
            (Data(worldJSON.replacingOccurrences(of: "\"schema_version\":1", with: "\"schema_version\":2").utf8), response(request))
        })
        do { _ = try await badSchema.world(); preconditionFailure("an unknown schema is refused") }
        catch let error as MemoryReadError { precondition(error == .invalidResponse) }
        print("Memory contract, auth, source, world, cache and request ordering checks passed")
    }
}
