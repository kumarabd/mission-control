import Foundation

enum Config {
    /// The router's public address (Info.plist `RouterBaseURL`).
    ///
    /// Xcode's generated Info.plist does not emit custom keys such as
    /// `RouterBaseURL` for the macOS target, so macOS reads the app's own
    /// configuration (which falls back to the checked-in router and still
    /// honours `ROUTER_BASE_URL`).
    static let routerBaseURL: String = {
        #if os(macOS)
        return AppConfiguration.routerBaseURL.absoluteString
        #else
        return info("RouterBaseURL")
        #endif
    }()

    /// DEBUG builds only: `-dev-engine` skips Clerk and the router and signs in a fixed local user.
    /// Release builds ignore the flag entirely.
    static var devEngine: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-dev-engine")
        #else
        return false
        #endif
    }

    private static func info(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}
