import SwiftUI
import UIKit

/// CarPlay takes images, not views. The mark is drawn once as a SwiftUI view and rendered here — a still per state
/// for list rows and grid buttons, and a short frame sequence for the voice-control template. The chat draws the same
/// view live, so the artwork can never drift between the two surfaces.
@MainActor
enum AgentMarkArtwork {
    static let rowSize: CGFloat = 44
    static let gridSize: CGFloat = 88
    private static let cache = NSCache<NSString, UIImage>()

    static func image(state: AssistantVoiceCoordinator.State, size: CGFloat) -> UIImage {
        let key = "still-\(state)-\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let asset = UIImageAsset()
        asset.register(render(state: state, size: size, phase: 0.35, scheme: .light),
                       with: UITraitCollection(userInterfaceStyle: .light))
        asset.register(render(state: state, size: size, phase: 0.35, scheme: .dark),
                       with: UITraitCollection(userInterfaceStyle: .dark))
        let image = asset.image(with: UITraitCollection.current)
        cache.setObject(image, forKey: key)
        return image
    }

    static func animatedImage(state: AssistantVoiceCoordinator.State, size: CGFloat = 140) -> UIImage {
        let key = "animated-\(state)-\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        // CarPlay plays an animated image only when each frame is shown for at least 0.3 s. Eight frames over 1.6 s was
        // 0.2 s each, so the system treated it as a still. Sixteen frames at 0.3 s each sits inside the rule, and the
        // extra keyframes keep the loop from reading as a stutter.
        let frames = 16
        let frameDuration: Double = 0.3
        let duration = Double(frames) * frameDuration
        let scheme: ColorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        let images = (0..<frames).map { frame in
            render(state: state, size: size, phase: Double(frame) * frameDuration, scheme: scheme)
        }
        // Return the animated image itself: wrapping it in a UIImageAsset can flatten it to one frame.
        let image = UIImage.animatedImage(with: images, duration: duration) ?? images[0]
        cache.setObject(image, forKey: key)
        return image
    }

    private static func render(state: AssistantVoiceCoordinator.State,
                               size: CGFloat,
                               phase: Double,
                               scheme: ColorScheme) -> UIImage {
        let renderer = ImageRenderer(content:
            AgentMark(state: state, size: size, phase: phase)
                .environment(\.colorScheme, scheme)
        )
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }
}
