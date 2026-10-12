import ClerkKit
import Foundation

/// Keeps Clerk configuration and gateway authentication at the app boundary.
/// The publishable key is supplied through the target's `CLERK_PUBLISHABLE_KEY`
/// build setting, never committed as an application secret.
enum ClerkConfiguration {
    /// Clerk publishable keys identify the Clerk instance; unlike secret keys they
    /// are intentionally safe to ship in an iOS client. The Info.plist value lets
    /// each build configuration override this, while the fallback keeps generated
    /// Info.plists (including simulator builds) from launching without Clerk.
    private static let bundledPublishableKey = "pk_live_Y2xlcmsubmlnaHRoYXdrbGFicy5vcmck"

    static let publishableKey: String = {
        let configuredKey = (Bundle.main.object(forInfoDictionaryKey: "ClerkPublishableKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !configuredKey.isEmpty, !configuredKey.contains("$(CLERK_PUBLISHABLE_KEY)") else {
            return bundledPublishableKey
        }

        return configuredKey
    }()

    static var isConfigured: Bool {
        !publishableKey.isEmpty && !publishableKey.contains("$(CLERK_PUBLISHABLE_KEY)")
    }

    @MainActor static func configure() {
        Clerk.configure(publishableKey: publishableKey)
    }
}

/// The remote agent gateway can depend on this protocol instead of Clerk directly.
/// ClerkKit keeps the session secure; this adapter obtains a fresh bearer token only
/// when a request is about to leave the device.
protocol AgentGatewayAuthenticating {
    func sessionToken() async throws -> String?
    func authorizationHeader() async throws -> String?
}

struct ClerkGatewayAuthentication: AgentGatewayAuthenticating {
    func sessionToken() async throws -> String? {
        guard ClerkConfiguration.isConfigured else { return nil }
        return try await Clerk.shared.auth.getToken()
    }

    func authorizationHeader() async throws -> String? {
        guard let token = try await sessionToken() else {
            return nil
        }
        return "Bearer \(token)"
    }
}
