import Foundation
import ClerkKit

enum AppConfiguration {
    private static let defaultClerkPublishableKey = "pk_live_Y2xlcmsubmlnaHRoYXdrbGFicy5vcmck"
    private static let defaultRouterBaseURL = "https://harness-router.nighthawklabs.org"

    static var clerkPublishableKey: String {
        configuredValue(infoKey: "ClerkPublishableKey", environmentKey: "CLERK_PUBLISHABLE_KEY")
            ?? defaultClerkPublishableKey
    }

    static var routerBaseURL: URL {
        let raw = configuredValue(infoKey: "RouterBaseURL", environmentKey: "ROUTER_BASE_URL")
            ?? defaultRouterBaseURL
        guard let routerURL = URL(string: raw) else {
            preconditionFailure("ROUTER_BASE_URL is not a valid URL")
        }
        return routerURL
    }

    static var gatewayBaseURL: URL { routerBaseURL.appending(path: "gateway") }

    /// The macOS bundle has its own identifier, so ClerkKit's default redirect
    /// would be `com.kumarabd.MissionControlMac://callback` — not yet authorized
    /// on this instance. Use the existing authorized iOS native redirect until
    /// the macOS native application is registered in Clerk. Override with
    /// `CLERK_REDIRECT_URL` once that redirect is allowlisted.
    private static let defaultClerkRedirectURL = "com.kumarabd.MissionControl://callback"

    static var clerkRedirectURL: String {
        configuredValue(infoKey: "ClerkRedirectURL", environmentKey: "CLERK_REDIRECT_URL")
            ?? defaultClerkRedirectURL
    }

    static var clerkCallbackScheme: String {
        URL(string: clerkRedirectURL)?.scheme ?? "com.kumarabd.MissionControl"
    }

    @MainActor
    static func configureAuthentication() {
        Clerk.configure(
            publishableKey: clerkPublishableKey,
            options: .init(redirectConfig: .init(
                redirectUrl: clerkRedirectURL,
                callbackUrlScheme: clerkCallbackScheme
            )))
    }

    private static func configuredValue(infoKey: String, environmentKey: String) -> String? {
        let value = (ProcessInfo.processInfo.environment[environmentKey]
            ?? Bundle.main.object(forInfoDictionaryKey: infoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }
}

/// Mirrors the iOS adapter so the shared registry and model clients use the
/// same fresh Clerk token immediately before a request leaves the device.
struct ClerkGatewayAuthentication {
    func sessionToken() async throws -> String? {
        try await Clerk.shared.auth.getToken()
    }

    func authorizationHeader() async throws -> String? {
        guard let token = try await sessionToken() else { return nil }
        return "Bearer \(token)"
    }
}
