import Foundation
import Observation
import UIKit
import UserNotifications

/// Registers this phone with the gateway so reminders and nudges can reach it while the app is closed.
///
/// The inbox stays the source of truth; push is only a nudge. So nothing here is allowed to get in the person's way: no
/// permission prompt of its own (the first timed reminder asks, through `Notifier`), failures are silent and retried
/// the next time the app starts, and a person who says no simply keeps the inbox.
@MainActor @Observable
final class PushRegistrar {
    static let shared = PushRegistrar()

    private var auth: AuthService?
    private var token: String?
    private var registered: String?   // the token the gateway last accepted

    /// Called once signed in. Registers silently if the person already allowed notifications.
    func attach(_ auth: AuthService) {
        self.auth = auth
        Task { await start() }
    }

    /// Asks iOS for a device token if notifications are allowed. Safe to call repeatedly.
    func start() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        UIApplication.shared.registerForRemoteNotifications()
        if let token { await register(token) }
    }

    func didReceive(deviceToken: Data) {
        let hex = PushLink.hex(deviceToken)
        token = hex
        Task { await register(hex) }
    }

    private func register(_ hex: String) async {
        guard hex != registered, let auth, let bearer = await auth.token(), let url = endpoint("devices") else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        // `sources` names the engines this app is the face of (the Life Engine, and the agent itself for its own notifications), so a notification from one is pushed to this app and no other.
        let body: [String: Any] = ["platform": "ios", "device_id": GatewayDeviceIdentity.value, "token": hex, "environment": environment,
                                   "topic": Bundle.main.bundleIdentifier ?? "", "name": UIDevice.current.name, "sources": ["life", "agent"]]
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 { registered = hex }
    }

    /// Stops pushes to this phone; called before signing out so the next person on it is not sent this one's reminders.
    func unregister() async {
        defer { registered = nil }
        guard let auth, let bearer = await auth.token(),
              let url = endpoint("devices/\(GatewayDeviceIdentity.value)") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    private func endpoint(_ path: String) -> URL? {
        guard !Config.routerBaseURL.isEmpty else { return nil }
        return URL(string: Config.routerBaseURL + "/gateway/" + path)
    }
}

/// Where a tapped notification should take the person. MainTabs reads and clears `pending`.
@MainActor @Observable
final class DeepLink {
    static let shared = DeepLink()
    var pending: PushLink.Target?
}

final class MissionControlAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushRegistrar.shared.didReceive(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on the simulator and without the push entitlement; the inbox still works.
    }

    /// A notification arriving while the app is open still shows, since the gateway only sends one then if it is high priority.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let target = PushLink.target(from: response.notification.request.content.userInfo) else { return }
        await MainActor.run { DeepLink.shared.pending = target }
    }
}
