import Foundation
import ClerkKit

enum AppConfiguration {
    private static let defaultClerkPublishableKey = "pk_test_cHJpbWFyeS1qYXktMjEuY2xlcmsuYWNjb3VudHMuZGV2JA"
    private static let defaultRouterBaseURL = "https://harness-router.nighthawklabs.org"

    static var clerkPublishableKey: String {
        configuredValue(infoKey: "ClerkPublishableKey", environmentKey: "CLERK_PUBLISHABLE_KEY")
            ?? defaultClerkPublishableKey
    }

    static var gatewayBaseURL: URL {
        let raw = configuredValue(infoKey: "RouterBaseURL", environmentKey: "ROUTER_BASE_URL")
            ?? defaultRouterBaseURL
        guard let routerURL = URL(string: raw) else {
            preconditionFailure("ROUTER_BASE_URL is not a valid URL")
        }
        return routerURL.appending(path: "gateway")
    }

    @MainActor
    static func configureAuthentication() {
        Clerk.configure(publishableKey: clerkPublishableKey)
    }

    private static func configuredValue(infoKey: String, environmentKey: String) -> String? {
        let value = (ProcessInfo.processInfo.environment[environmentKey]
            ?? Bundle.main.object(forInfoDictionaryKey: infoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }
}
