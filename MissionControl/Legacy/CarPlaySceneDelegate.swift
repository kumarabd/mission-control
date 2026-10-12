import CarPlay
import Combine
import UIKit

/// Driver-safe companion to the iPhone assistant. CarPlay reserves the screen
/// for system templates, so this deliberately carries the Mission Control mark,
/// colors, voice state, and one live exchange rather than recreating the phone UI.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private static let conversationTextVisibilityKey = "missionShowConversationText"
    private var interfaceController: CPInterfaceController?
    // Automotive surfaces remain visually expressive but silent: they must not
    // compete with navigation, alerts, or the driver's chosen audio.
    private let voice = AssistantVoiceCoordinator(playsStartupCue: false)
    private var observers = Set<AnyCancellable>()

    private var sessionItem: CPListItem?
    private var transcriptItem: CPListItem?
    private var responseItem: CPListItem?
    private var rootTemplate: CPListTemplate?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        voice.updateGatewayAppActivity(true)
        observeVoice()
        showMissionControl()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController: CPInterfaceController
    ) {
        observers.removeAll()
        voice.cancel()
        rootTemplate = nil
        sessionItem = nil
        transcriptItem = nil
        responseItem = nil
        self.interfaceController = nil
    }

    private func observeVoice() {
        observers.removeAll()
        Publishers.Merge4(
            voice.$state.map { _ in () },
            voice.$transcript.map { _ in () },
            voice.$message.map { _ in () },
            voice.$conversationText.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.refreshVoiceSurface() }
        .store(in: &observers)
    }

    private func showMissionControl() {
        guard let interfaceController else { return }

        let session = CPListItem(
            text: statusTitle,
            detailText: statusDetail,
            image: MissionCarPlayAgentMark.image(for: voice.state)
        )
        session.handler = { [weak self] _, completion in
            self?.toggleVoiceInteraction()
            completion()
        }

        let transcript = CPListItem(
            text: "Your words will appear here",
            detailText: "Live transcription",
            image: UIImage(systemName: "text.bubble")
        )
        transcript.isEnabled = false

        let response = CPListItem(
            text: "Mission Control is ready",
            detailText: "Tap the agent mark to begin.",
            image: UIImage(systemName: "waveform")
        )
        response.isEnabled = false

        let template = CPListTemplate(
            title: "Mission Control",
            sections: [
                CPListSection(items: [session]),
                CPListSection(items: [transcript, response], header: "CONVERSATION", sectionIndexTitle: nil)
            ]
        )

        // iOS 26's header grid is the system-approved prominent tappable
        // affordance for this category. It gives the assistant a recognizable,
        // touch-sized presence without introducing custom CarPlay UI.
        if #available(iOS 26.0, *) {
            template.headerGridButtons = headerButtons()
        }

        sessionItem = session
        transcriptItem = transcript
        responseItem = response
        rootTemplate = template
        interfaceController.setRootTemplate(template, animated: true)
    }

    @available(iOS 26.0, *)
    private func agentButton() -> CPGridButton {
        CPGridButton(
            titleVariants: [isVoiceActive ? "End session" : "Talk to Mission Control", isVoiceActive ? "End" : "Talk"],
            image: MissionCarPlayAgentMark.image(for: voice.state)
        ) { [weak self] _ in
            self?.toggleVoiceInteraction()
        }
    }

    @available(iOS 26.0, *)
    private func conversationTextButton() -> CPGridButton {
        CPGridButton(
            titleVariants: [showsConversationText ? "Hide words" : "Show words", showsConversationText ? "Hide" : "Show"],
            image: UIImage(systemName: showsConversationText ? "eye.slash" : "eye")!
        ) { [weak self] _ in
            guard let self else { return }
            UserDefaults.standard.set(!self.showsConversationText, forKey: Self.conversationTextVisibilityKey)
            self.refreshVoiceSurface()
        }
    }

    @available(iOS 26.0, *)
    private func headerButtons() -> [CPGridButton] {
        [agentButton(), conversationTextButton()]
    }

    private func refreshVoiceSurface() {
        guard sessionItem != nil else { return }
        sessionItem?.setText(statusTitle)
        sessionItem?.setDetailText(statusDetail)
        sessionItem?.setImage(MissionCarPlayAgentMark.image(for: voice.state))

        transcriptItem?.setText(transcriptTitle)
        transcriptItem?.setDetailText(transcriptDetail)
        responseItem?.setText(responseTitle)
        responseItem?.setDetailText(responseDetail)

        if #available(iOS 26.0, *) {
            rootTemplate?.headerGridButtons = headerButtons()
        }
    }

    private func toggleVoiceInteraction() {
        switch voice.state {
        case .idle, .unavailable:
            voice.toggle()
        case .preparing, .listening, .processing, .speaking:
            voice.cancel()
        }
    }

    private var isVoiceActive: Bool {
        switch voice.state {
        case .idle, .unavailable: false
        case .preparing, .listening, .processing, .speaking: true
        }
    }

    private var statusTitle: String {
        switch voice.state {
        case .idle: "Tap the agent to talk"
        case .preparing: "Mission Control is preparing"
        case .listening: "Mission Control is listening"
        case .processing: "Mission Control is thinking"
        case .speaking: "Mission Control is speaking"
        case .unavailable: "Voice is unavailable"
        }
    }

    private var statusDetail: String {
        switch voice.state {
        case .idle: "Ask for a briefing or an answer."
        case .listening: "Speak naturally. Your words appear below."
        case .processing: "Your request is on its way."
        case .speaking: "Keep your attention on the road."
        case .unavailable: voice.message.isEmpty ? "Tap the agent to try again." : compact(voice.message)
        case .preparing: "Starting the voice session."
        }
    }

    private var transcriptTitle: String {
        guard showsConversationText else { return "Spoken text is hidden" }
        let text = voice.conversationText.displayedUserText
        return text.isEmpty ? "Your words will appear here" : compact(text)
    }

    private var transcriptDetail: String {
        guard showsConversationText else { return "Tap Show words to enable." }
        return voice.conversationText.displayedUserText.isEmpty ? "Live transcription" : "You said"
    }

    private var responseTitle: String {
        guard showsConversationText else { return "Mission Control is still active" }
        let text = voice.conversationText.assistantText
        if !text.isEmpty { return compact(text) }
        if voice.state == .processing { return "Mission Control is working" }
        if voice.state == .speaking { return "Mission Control is replying" }
        return "Mission Control is ready"
    }

    private var responseDetail: String {
        guard showsConversationText else { return "Responses remain audible." }
        if !voice.conversationText.assistantText.isEmpty { return "Response" }
        if voice.state == .idle { return "Tap the agent mark to begin." }
        return statusDetail
    }

    private func compact(_ text: String) -> String {
        let singleLine = text
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: #"\\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard singleLine.count > 150 else { return singleLine }
        return String(singleLine.prefix(147)) + "…"
    }

    private var showsConversationText: Bool {
        // The phone's @AppStorage uses true as the initial value. Preserve that
        // default until someone explicitly chooses to hide spoken text.
        (UserDefaults.standard.object(forKey: Self.conversationTextVisibilityKey) as? Bool) ?? true
    }
}

/// A UIKit rendition of the phone app's two rings and five voice bars. The
/// template owns layout and accessibility; this only supplies brand artwork.
private enum MissionCarPlayAgentMark {
    static func image(for state: AssistantVoiceCoordinator.State) -> UIImage {
        let asset = UIImageAsset()
        asset.register(render(for: .light, state: state), with: UITraitCollection(userInterfaceStyle: .light))
        asset.register(render(for: .dark, state: state), with: UITraitCollection(userInterfaceStyle: .dark))
        return asset.image(with: UITraitCollection.current)
    }

    private static func render(for style: UIUserInterfaceStyle, state: AssistantVoiceCoordinator.State) -> UIImage {
        let size = CGSize(width: 150, height: 150)
        let traits = UITraitCollection(userInterfaceStyle: style)
        let tint = MissionCarPlayPalette.tint.resolvedColor(with: traits)
        let line = MissionCarPlayPalette.line.resolvedColor(with: traits)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            cg.setFillColor(tint.withAlphaComponent(0.14).cgColor)
            cg.fillEllipse(in: CGRect(x: 17, y: 17, width: 116, height: 116))
            cg.setStrokeColor(line.cgColor)
            cg.setLineWidth(1)
            cg.strokeEllipse(in: CGRect(x: 9, y: 9, width: 132, height: 132))

            let ringAngle: CGFloat = switch state {
            case .processing: .pi * 0.64
            case .speaking: .pi * 0.24
            default: .pi / 5
            }
            drawRing(in: cg, center: center, size: 88, cornerRadius: 28, angle: ringAngle, color: tint.withAlphaComponent(0.82))
            drawRing(in: cg, center: center, size: 72, cornerRadius: 22, angle: ringAngle + .pi * 0.16, color: tint.withAlphaComponent(0.46))

            let heights: [CGFloat] = switch state {
            case .preparing: [18, 30, 44, 30, 18]
            case .listening: [30, 62, 42, 58, 28]
            case .processing: [20, 34, 66, 34, 20]
            case .speaking: [46, 70, 52, 76, 42]
            case .idle, .unavailable: [28, 48, 68, 48, 28]
            }
            let barWidth: CGFloat = 10
            for (index, height) in heights.enumerated() {
                let x = center.x - 34 + CGFloat(index) * 17
                let rect = CGRect(x: x, y: center.y - height / 2, width: barWidth, height: height)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: barWidth / 2)
                cg.setFillColor(tint.cgColor)
                cg.addPath(path.cgPath)
                cg.fillPath()
            }
        }
    }

    private static func drawRing(in context: CGContext, center: CGPoint, size: CGFloat, cornerRadius: CGFloat, angle: CGFloat, color: UIColor) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle)
        context.translateBy(x: -center.x, y: -center.y)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(3)
        context.addPath(UIBezierPath(roundedRect: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size), cornerRadius: cornerRadius).cgPath)
        context.strokePath()
        context.restoreGState()
    }
}

private enum MissionCarPlayPalette {
    static let tint = adaptive(light: 0x4E6A37, dark: 0xA9C985, lightContrast: 0x1C2D12, darkContrast: 0xE5F4D6)
    static let line = adaptive(light: 0xCED1C5, dark: 0x313A35, lightContrast: 0x6C7561, darkContrast: 0x89947B)

    private static func adaptive(light: UInt32, dark: UInt32, lightContrast: UInt32, darkContrast: UInt32) -> UIColor {
        UIColor { traits in
            let highContrast = traits.accessibilityContrast == .high
            let value = traits.userInterfaceStyle == .dark
                ? (highContrast ? darkContrast : dark)
                : (highContrast ? lightContrast : light)
            return UIColor(
                red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255,
                alpha: 1
            )
        }
    }
}
