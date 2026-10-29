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
        ClerkConfiguration.configure()
        if Config.devEngine { return }   // developer mode still needs the Clerk environment, but does not sign in
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

    /// Signs in with an email and password, for accounts that have one (the App Review demo account).
    /// Returns an error message to show, or nil on success.
    func signIn(email: String, password: String) async -> String? {
        do {
            try await Clerk.shared.auth.signInWithPassword(
                identifier: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            // A second factor stops here; the welcome screen has no way to complete it.
            guard Clerk.shared.user != nil else { return "This account needs extra verification. Use Google or Apple sign-in." }
            return nil
        } catch {
            if let clerkError = error as? ClerkError, let message = clerkError.message { return "Sign in failed: \(message)" }
            return "Sign in failed: \(error.localizedDescription)"
        }
    }

    /// Opens Sign in with Apple (Clerk). Returns an error message to show, or nil on success.
    func signInWithApple() async -> String? {
        do {
            try await Clerk.shared.auth.signInWithApple()
            return nil
        } catch {
            if error is CancellationError || (error as? ASAuthorizationError)?.code == .canceled { return nil }
            if let clerkError = error as? ClerkError, let message = clerkError.message { return "Apple sign-in failed: \(message)" }
            return "Apple sign-in failed: \(error.localizedDescription)"
        }
    }

    /// Signing out clears everything the app kept on this phone for this person.
    func signOut() async {
        await PushRegistrar.shared.unregister()   // while the session is still valid
        LocalState.wipe(owner: userId ?? "")
        try? await Clerk.shared.auth.signOut()
    }

    /// Deletes the Clerk account, then clears this phone. Returns an error message to show, or nil on success.
    func deleteAccount() async -> String? {
        guard let user = Clerk.shared.user else { return "You are not signed in." }
        await PushRegistrar.shared.unregister()   // while the session is still valid
        do {
            _ = try await user.delete()
        } catch {
            return "Couldn't delete your account: \(error.localizedDescription)"
        }
        LocalState.wipe(owner: user.id)
        try? await Clerk.shared.auth.signOut()
        return nil
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
