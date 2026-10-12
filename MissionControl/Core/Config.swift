import Foundation

enum Config {
    /// The router's public address (Info.plist `RouterBaseURL`).
    static let routerBaseURL: String = info("RouterBaseURL")

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
