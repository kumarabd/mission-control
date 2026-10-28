import SwiftUI
import XCTest
@testable import MissionControl

@MainActor
final class WorkspaceTests: XCTestCase {
    func testNotificationTargetsRouteToTheirSurface() {
        let model = WorkspaceModel(userId: "test-user")

        model.open(PushLink.Target(entity: "goal", id: "g1", section: .goals))
        XCTAssertEqual(model.destination, .goals)
        XCTAssertEqual(model.pendingGoalID, "g1")

        model.open(PushLink.Target(entity: "task", id: "t1", section: .today))
        XCTAssertEqual(model.destination, .today)
        XCTAssertEqual(model.pendingItem, ItemRef(id: "t1"))
    }

    func testWorkspaceReceiptsOpenTheirRecord() {
        let model = WorkspaceModel(userId: "test-user")

        model.open(WorkspaceUpdate(kind: .goal, entityID: "g1", title: "Ship it", detail: "Goal", version: 2))
        XCTAssertEqual(model.destination, .goals)
        XCTAssertEqual(model.pendingGoalID, "g1")

        model.open(WorkspaceUpdate(kind: .task, entityID: "t1", title: "Fix it", detail: "Task", version: 1))
        XCTAssertEqual(model.destination, .today)
        XCTAssertEqual(model.pendingItem, ItemRef(id: "t1"))
    }

    func testDiscussStartsTheChatWithTheDraft() {
        let model = WorkspaceModel(userId: "test-user")

        model.discuss("About my goal “Ship it”: ")

        XCTAssertEqual(model.destination, .chat)
        XCTAssertEqual(model.chat.draft, "About my goal “Ship it”: ")
        XCTAssertEqual(model.chat.draftToken, 1)
    }

    func testDefaultAgentIsStoredAsNoPreference() {
        let store = ChatStore()
        let original = UserDefaults.standard.string(forKey: ChatStore.agentDefaultsKey)
        defer { UserDefaults.standard.set(original, forKey: ChatStore.agentDefaultsKey) }

        store.setAgent("coach")
        XCTAssertEqual(UserDefaults.standard.string(forKey: ChatStore.agentDefaultsKey), "coach")

        store.setAgent(ChatStore.defaultAgent)
        XCTAssertEqual(UserDefaults.standard.string(forKey: ChatStore.agentDefaultsKey), "")
    }

    func testRouterConfigurationIsNeverEmpty() {
        // The generated Info.plist omits the custom RouterBaseURL key; the Mac
        // target must still hand the shared services a usable router.
        XCTAssertFalse(Config.routerBaseURL.isEmpty)
        XCTAssertEqual(Config.routerBaseURL, AppConfiguration.routerBaseURL.absoluteString)
    }

    func testClerkUsesTheAuthorizedNativeRedirectUntilMacIsRegistered() {
        XCTAssertEqual(AppConfiguration.clerkRedirectURL, "com.kumarabd.MissionControl://callback")
        XCTAssertEqual(AppConfiguration.clerkCallbackScheme, "com.kumarabd.MissionControl")
    }

    func testAppearanceChoiceMapsToColorScheme() {
        XCTAssertNil(AppearanceChoice.system.scheme)
        XCTAssertEqual(AppearanceChoice.light.scheme, .light)
        XCTAssertEqual(AppearanceChoice.dark.scheme, .dark)
    }
}
