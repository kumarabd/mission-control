import AuthenticationServices
import ClerkKit
import Foundation
import Observation

enum AuthState: Equatable {
    case loading
    case signedOut
    case signedIn(userId: String, email: String?)
}

/// Identity for the whole app. Signing in is Clerk, the same identity the router verifies, so the same person lands
/// on the same workspace as in Treasure and AutoTelemetry. There is no guest mode: the records live on the server.
@MainActor @Observable
final class AuthService {
    /// Clerk couldn't finish starting (offline first launch): show the sign-in screen rather than a blank one.
    private var loadTimedOut = false

    init() {
        if Config.devEngine { return }   // developer mode: no Clerk, a fixed local user
        ClerkConfiguration.configure()
        Task {
            try? await Task.sleep(for: .seconds(8))
            loadTimedOut = true
        }
    }

    var state: AuthState {
        if Config.devEngine { return .signedIn(userId: "dev_user", email: "dev@local") }
        if let user = Clerk.shared.user {
            return .signedIn(userId: user.id, email: user.primaryEmailAddress?.emailAddress)
        }
        return Clerk.shared.isLoaded || loadTimedOut ? .signedOut : .loading
    }

    var userId: String? { if case .signedIn(let id, _) = state { id } else { nil } }

    /// Opens Google sign-in (Clerk OAuth). Returns an error message to show, or nil on success.
    func signInWithGoogle() async -> String? {
        do {
            try await Clerk.shared.auth.signInWithOAuth(provider: .google)
            return nil
        } catch {
            if error is CancellationError || (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return nil }
            if let clerkError = error as? ClerkError, let message = clerkError.message { return "Google sign-in failed: \(message)" }
            return "Google sign-in failed: \(error.localizedDescription)"
        }
    }

    /// Signing out clears everything the app kept on this phone for this person.
    func signOut() async {
        LocalState.wipe(owner: userId ?? "")
        try? await Clerk.shared.auth.signOut()
    }

    /// A session token for the router, or nil when not signed in or offline. [skipCache] forces a fresh one.
    func token(skipCache: Bool = false) async -> String? {
        if Config.devEngine { return "dev" }
        guard Clerk.shared.session != nil else { return nil }
        return try? await Clerk.shared.auth.getToken(.init(skipCache: skipCache))
    }
}

enum LocalState {
    static func wipe(owner: String) {
        let fm = FileManager.default
        for dir in [FileManager.SearchPathDirectory.cachesDirectory, .applicationSupportDirectory] {
            try? fm.removeItem(at: fm.urls(for: dir, in: .userDomainMask)[0].appendingPathComponent("missioncontrol", isDirectory: true))
        }
        UserDefaults.standard.removeObject(forKey: "onboarding.submitted.\(owner)")
    }
}
