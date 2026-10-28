import Foundation

@main
struct GatewayAgentsChecks {
    @MainActor static func main() async throws {
        // listAgents decodes the real {"agents": [...]} envelope, snake_case fields, and an RFC 3339 timestamp.
        let listJSON = Data("""
        {"agents": [{"agent_id": "main", "display_name": "Nighthawk", "avatar_url": null, "description": "", "persona": "You are helpful.", "status": "active", "created_at": "2026-01-01T00:00:00Z"}]}
        """.utf8)
        let listAPI = GatewayAgentsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/agents" && request.httpMethod == "GET")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return (listJSON, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let agents = try await listAPI.listAgents()
        precondition(agents.count == 1 && agents[0].agentID == "main" && agents[0].displayName == "Nighthawk" && agents[0].avatarURL == nil)

        // createAgent encodes the request body in the real snake_case shape and decodes the created row.
        var capturedBody: [String: Any] = [:]
        let createdJSON = Data("""
        {"agent_id": "a1b2", "display_name": "Researcher", "avatar_url": null, "description": "d", "persona": "p", "status": "active", "created_at": "2026-01-02T00:00:00Z"}
        """.utf8)
        let createAPI = GatewayAgentsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/agents" && request.httpMethod == "POST")
            capturedBody = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
            return (createdJSON, HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!)
        })
        let created = try await createAPI.createAgent(displayName: "Researcher", persona: "p", description: "d", avatarURL: nil)
        precondition(created.agentID == "a1b2")
        precondition(capturedBody["display_name"] as? String == "Researcher")

        // A plain-text, non-JSON error body (http.Error's real shape) classifies as .server with that exact
        // message — this client must not expect LifeAPI's {"error":{"code","message"}} envelope.
        let errorAPI = GatewayAgentsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            (Data("display_name is required".utf8), HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        })
        do {
            _ = try await errorAPI.listAgents()
            preconditionFailure("expected an error")
        } catch let error as GatewayAgentsError {
            guard case .server(let status, let message) = error else { preconditionFailure("expected .server") }
            precondition(status == 400 && message == "display_name is required")
        }

        // A missing token fails fast with .unauthorized and never reaches the network.
        let noTokenAPI = GatewayAgentsAPI(baseURL: "https://test.invalid", token: { nil }, transport: { _ in
            preconditionFailure("should not reach the network with no token")
        })
        do {
            _ = try await noTokenAPI.listAgents()
            preconditionFailure("expected an error")
        } catch let error as GatewayAgentsError {
            precondition(error == .unauthorized)
        }

        print("GatewayAgentsChecks passed")
    }
}
