import AVFAudio
import Combine
import Foundation
import Speech

/// Read-only inventory for the single SpeechTranscriber path used by the app.
/// Refreshing never requests permission, activates audio, or installs a model.
@MainActor
final class SpeechCapabilityProbe: ObservableObject {
    struct Capability: Equatable {
        var availability: String
        var locale: String
        var model: String

        static let checking = Capability(
            availability: "Checking",
            locale: "—",
            model: "—"
        )
    }

    struct Snapshot: Equatable {
        var requestedLocale: String
        var microphonePermission: String
        var speechTranscriber: Capability
        var recommendation: String

        static let checking = Snapshot(
            requestedLocale: Locale.current.identifier,
            microphonePermission: "Checking",
            speechTranscriber: .checking,
            recommendation: "Checking this device"
        )
    }

    @Published private(set) var snapshot = Snapshot.checking
    @Published private(set) var isRefreshing = false

    var summary: String {
        isRefreshing ? "Checking" : snapshot.recommendation
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let requestedLocale = Locale.current
        let capability = await probeSpeechTranscriber(for: requestedLocale)
        snapshot = Snapshot(
            requestedLocale: requestedLocale.identifier,
            microphonePermission: Self.microphonePermissionDescription,
            speechTranscriber: capability,
            recommendation: Self.recommendation(for: capability)
        )

        #if DEBUG
        print("[SpeechProbe] locale=\(snapshot.requestedLocale) microphone=\(snapshot.microphonePermission)")
        print("[SpeechProbe] SpeechTranscriber availability=\(capability.availability) locale=\(capability.locale) model=\(capability.model)")
        #endif
    }

    private static var microphonePermissionDescription: String {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: "Not requested"
        case .denied: "Denied"
        case .granted: "Allowed"
        @unknown default: "Unknown"
        }
    }

    private func probeSpeechTranscriber(for requestedLocale: Locale) async -> Capability {
        guard SpeechTranscriber.isAvailable else {
            return Capability(
                availability: "Unavailable on this device",
                locale: "—",
                model: "Not supported"
            )
        }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            return Capability(
                availability: "Available",
                locale: "No compatible locale",
                model: "Not supported"
            )
        }

        let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        return Capability(
            availability: "Available",
            locale: locale.identifier,
            model: Self.description(for: await AssetInventory.status(forModules: [module]))
        )
    }

    private static func description(for status: AssetInventory.Status) -> String {
        switch status {
        case .unsupported: "Not supported"
        case .supported: "Installs on first use"
        case .downloading: "Installing"
        case .installed: "Installed"
        @unknown default: "Unknown"
        }
    }

    private static func recommendation(for capability: Capability) -> String {
        guard capability.availability == "Available" else { return "Unavailable" }
        switch capability.model {
        case "Installed": return "Ready"
        case "Installs on first use": return "Ready to install"
        case "Installing": return "Preparing"
        default: return "Unsupported locale"
        }
    }
}
