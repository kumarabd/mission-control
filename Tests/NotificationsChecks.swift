import Foundation

@main
struct NotificationsChecks {
    @MainActor static func main() async throws {
        // One page: snake_case envelope, microseconds on created_at, an absent session_id, one link and one null.
        let pageJSON = Data("""
        {"items": [
          {"id": "n1", "source": "life", "kind": "reminder", "title": "Call Sam", "body": "It is 5pm", "priority": "normal",
           "link": {"entity": "reminder", "id": "r1"}, "created_at": "2026-10-16T10:00:00.123456Z", "read_at": null},
          {"id": "n2", "source": "life", "kind": "nudge", "title": "Drink water", "body": "", "priority": "high",
           "link": null, "created_at": "2026-10-16T09:00:00Z", "read_at": "2026-10-16T09:05:00Z"}
        ], "unread": 1, "next_before": "2026-10-16T09:00:00Z"}
        """.utf8)
        let pageAPI = NotificationsAPI(baseURL: "https://test.invalid/gateway", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/gateway/notifications" && request.httpMethod == "GET")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return (pageJSON, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let page = try await pageAPI.page()
        precondition(page.items.count == 2 && page.unread == 1 && page.nextBefore == "2026-10-16T09:00:00Z")
        precondition(page.items[0].isUnread && page.items[0].link == Wire.Link(entity: "reminder", id: "r1"))
        precondition(page.items[1].readAt != nil && page.items[1].link == nil && page.items[1].priority == "high")
        // Postgres hands back microseconds; they must survive decoding rather than being dropped.
        let expected = ISO8601DateFormatter().date(from: "2026-10-16T10:00:00Z")!.addingTimeInterval(0.123456)
        precondition(abs(page.items[0].createdAt.timeIntervalSince(expected)) < 0.001, "\(page.items[0].createdAt)")

        // A row whose link is malformed (the store hands back whatever JSON was written) opens nothing but must not
        // fail the whole page.
        let badLinkJSON = Data("""
        {"items": [{"id": "n3", "source": "life", "kind": "notice", "title": "T", "body": "b", "priority": "normal",
          "link": "not-a-link", "created_at": "2026-10-16T10:00:00Z", "read_at": null}], "unread": 1, "next_before": null}
        """.utf8)
        let badLinkAPI = NotificationsAPI(baseURL: "https://test.invalid/gateway", token: { "test-token" }, transport: { request in
            (badLinkJSON, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let badPage = try await badLinkAPI.page()
        precondition(badPage.items.count == 1 && badPage.items[0].link == nil && badPage.nextBefore == nil)

        // The cursor goes back byte for byte: reformatting it would skip or repeat the boundary row.
        let cursor = "2026-10-16T09:00:00.123456Z"
        let cursorAPI = NotificationsAPI(baseURL: "https://test.invalid/gateway", token: { "test-token" }, transport: { request in
            let sent = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "before" }?.value
            precondition(sent == cursor, "the cursor must not be reformatted: \(sent ?? "nil")")
            return (Data(#"{"items": [], "unread": 0, "next_before": null}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        _ = try await cursorAPI.page(before: cursor)

        // Marking one read answers 204 with no body; marking all answers {"marked": n}.
        let readAPI = NotificationsAPI(baseURL: "https://test.invalid/gateway", token: { "test-token" }, transport: { request in
            if request.url!.path.hasSuffix("/read-all") {
                return (Data(#"{"marked": 3}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            precondition(request.url!.path == "/gateway/notifications/n1/read" && request.httpMethod == "POST")
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        })
        try await readAPI.markRead("n1")
        let marked = try await readAPI.markAllRead()
        precondition(marked == 3)

        // The gateway answers failures as plain text (http.Error), not Life's JSON envelope.
        let errorAPI = NotificationsAPI(baseURL: "https://test.invalid/gateway", token: { "test-token" }, transport: { request in
            (Data("unauthorized".utf8), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
        })
        do {
            _ = try await errorAPI.page()
            preconditionFailure("expected an error")
        } catch let error as NotificationsError {
            guard case .server(let status, let message) = error else { preconditionFailure("expected .server") }
            precondition(status == 500 && message == "unauthorized")
        }

        // A missing token fails before any network call.
        let noTokenAPI = NotificationsAPI(baseURL: "https://test.invalid/gateway", token: { nil }, transport: { _ in
            preconditionFailure("should not reach the network with no token")
        })
        do {
            _ = try await noTokenAPI.page()
            preconditionFailure("expected an error")
        } catch let error as NotificationsError {
            precondition(error == .unauthorized)
        }

        // The model: pagination appends without duplicates, and a failed refresh keeps what is already shown.
        let pages = [
            #"{"items": [{"id": "a", "source": "life", "kind": "notice", "title": "A", "body": "", "priority": "normal", "link": null, "created_at": "2026-10-16T10:00:00Z", "read_at": null}], "unread": 1, "next_before": "2026-10-16T09:00:00Z"}"#,
            #"{"items": [{"id": "a", "source": "life", "kind": "notice", "title": "A", "body": "", "priority": "normal", "link": null, "created_at": "2026-10-16T10:00:00Z", "read_at": null}, {"id": "b", "source": "life", "kind": "notice", "title": "B", "body": "", "priority": "normal", "link": null, "created_at": "2026-10-16T09:00:00Z", "read_at": null}], "unread": 2, "next_before": null}"#,
        ]
        var call = 0
        var failing = false
        let modelAPI = NotificationsAPI(baseURL: "https://test.invalid/gateway", token: { "test-token" }, transport: { request in
            if failing { return (Data("busy".utf8), HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!) }
            let body = Data(pages[min(call, pages.count - 1)].utf8)
            call += 1
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let model = NotificationsModel()
        model.attach(modelAPI)
        precondition(model.available)
        await model.refresh()
        precondition(model.items.map(\.id) == ["a"] && model.unread == 1 && model.hasMore && model.loaded)
        await model.loadMore()
        precondition(model.items.map(\.id) == ["a", "b"], "a page that repeats a row must not duplicate it: \(model.items.map(\.id))")
        precondition(model.unread == 2 && !model.hasMore)

        // Reading one marks it locally and asks the gateway.
        await model.markRead(model.items[0])
        precondition(model.items[0].readAt != nil && model.unread == 1)

        // A failed refresh keeps the list and records why.
        failing = true
        await model.refresh()
        precondition(model.items.map(\.id) == ["a", "b"] && model.failure == "busy")

        // With no API attached the inbox is simply unavailable, not broken.
        let detached = NotificationsModel()
        await detached.refresh()
        precondition(!detached.available && detached.items.isEmpty && detached.failure == nil)

        print("NotificationsChecks passed")
    }
}
