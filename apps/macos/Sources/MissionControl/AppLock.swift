import Foundation
import LocalAuthentication
import Observation

/// The desktop equivalent of the phone's Face ID lock and the web's platform
/// authenticator: Touch ID or the login password covers the workspace while
/// the app is away.
@MainActor @Observable
final class AppLock {
    static let defaultsKey = "appLock.enabled"

    private(set) var enabled: Bool
    private(set) var locked: Bool

    init() {
        let on = UserDefaults.standard.bool(forKey: Self.defaultsKey)
        enabled = on
        locked = on
    }

    /// Turning the lock on checks that this Mac can actually authenticate
    /// before storing the preference; a control that cannot unlock is worse
    /// than no control.
    func setEnabled(_ on: Bool) async -> String? {
        if on {
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                return error?.localizedDescription ?? "This Mac can't use Touch ID or the login password."
            }
        }
        enabled = on
        UserDefaults.standard.set(on, forKey: Self.defaultsKey)
        locked = on
        return nil
    }

    func didLeave() {
        if enabled { locked = true }
    }

    /// Lock immediately from the command palette or the account menu.
    func lockNow() {
        if enabled { locked = true }
    }

    /// Returns an error message when authentication did not succeed.
    func unlock() async -> String? {
        guard enabled else { locked = false; return nil }
        let context = LAContext()
        context.localizedCancelTitle = "Keep locked"
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Mission Control")
            if ok { locked = false; return nil }
            return "Mission Control stays locked."
        } catch {
            return error.localizedDescription
        }
    }
}
