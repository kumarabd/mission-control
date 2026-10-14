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
        print("Memory contract, auth, source, cache and request ordering checks passed")
    }
}
