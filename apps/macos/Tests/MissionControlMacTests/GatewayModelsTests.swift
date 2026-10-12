import XCTest
@testable import MissionControlMac

final class GatewayModelsTests: XCTestCase {
    func testDecodesToolFrame() throws {
        let data = #"{"type":"tool_call","turn_seq":3,"message_seq":2,"tool_call_id":"call_1","tool_name":"search_web","arguments":{"query":"weather"},"status":"running","partial_output":"Searching"}"#.data(using: .utf8)!
        let frame = try JSONDecoder().decode(GatewayFrame.self, from: data)
        XCTAssertEqual(frame.type, "tool_call")
        XCTAssertEqual(frame.turnSequence, 3)
        XCTAssertEqual(frame.toolName, "search_web")
        XCTAssertEqual(frame.partialOutput, "Searching")
    }

    func testSessionUsesStableIdentifier() {
        XCTAssertEqual(SessionSummary.main().id, "main")
    }
    func testNewConversationIsAnIndependentRootSession() {
        let session = SessionSummary.newConversation(
            sessionID: "fresh-session",
            now: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(session.id, "fresh-session")
        XCTAssertNil(session.parentSessionID)
        XCTAssertEqual(session.title, "New conversation")
    }

}
