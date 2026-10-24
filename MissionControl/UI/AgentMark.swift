import SwiftUI

/// The assistant's sigil: a breathing halo, two counter-rotating orbit arcs, and five voice bars in the middle. It is
/// drawn, not photographed — every part scales with `size`, so it stays crisp from a 24-point avatar to the full voice
/// card, and each voice state moves at its own pace.
///
/// Three ways to draw it:
/// - `animated: true` — phases come from the display clock (the voice overlay, CarPlay's voice image frames).
/// - `phase: <seconds>` — one still frame at that moment, for rendering to an image (CarPlay's list and grid art).
/// - neither — a calm still at a fixed, pleasing frame (avatars).
struct AgentMark: View {
    var state: AssistantVoiceCoordinator.State = .idle
    var size: CGFloat = 44
    var animated = false
    var phase: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let phase {
                content(at: phase)
            } else if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    content(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                content(at: 0.35)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: One frame

    private func content(at time: Double) -> some View {
        let motion = motion
        let beat = sin(2 * .pi * motion.speed * time)
        return ZStack {
            RadialGradient(colors: [Tok.accent.opacity(0.30), Tok.accent.opacity(0.02)],
                           center: .center, startRadius: 0, endRadius: size * 0.52)
                .scaleEffect(1 + 0.05 * beat)

            orbit(from: 0.03, to: 0.34, inset: 0.075, opacity: 0.75,
                  degrees: 18 + 360 * motion.ringSpeed * time)
            orbit(from: 0.52, to: 0.86, inset: 0.17, opacity: 0.32,
                  degrees: -30 - 360 * motion.ringSpeed * 0.7 * time)

            HStack(alignment: .center, spacing: size * 0.06) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Tok.accent)
                        .opacity(0.68 + 0.32 * (1 - abs(Double(index) - 2) / 2))
                        .frame(width: size * 0.065, height: barHeight(index, time: time))
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func orbit(from: CGFloat, to: CGFloat, inset: CGFloat, opacity: Double, degrees: Double) -> some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(Tok.accent.opacity(opacity),
                    style: StrokeStyle(lineWidth: max(1.2, size * 0.022), lineCap: .round))
            .padding(size * inset)
            .rotationEffect(.degrees(degrees))
    }

    private func barHeight(_ index: Int, time: Double) -> CGFloat {
        let motion = motion
        let wave = CGFloat(sin(2 * .pi * motion.speed * time + Double(index) * 0.55))
        let height = motion.base[index] + motion.amplitude * wave
        return size * max(0.07, height)
    }

    // MARK: Motion per state

    private struct Motion {
        var speed: Double          // bar cycles per second
        var amplitude: CGFloat     // how far a bar strays from its base, as a fraction of size
        var base: [CGFloat]        // the five bar heights, as fractions of size
        var ringSpeed: Double      // orbit revolutions per second
    }

    private var motion: Motion {
        switch state {
        case .idle:
            Motion(speed: 0.45, amplitude: 0.025, base: [0.18, 0.30, 0.42, 0.30, 0.18], ringSpeed: 0.10)
        case .preparing:
            Motion(speed: 1.0, amplitude: 0.04, base: [0.12, 0.20, 0.30, 0.20, 0.12], ringSpeed: 0.50)
        case .listening:
            Motion(speed: 0.9, amplitude: 0.07, base: [0.20, 0.40, 0.28, 0.38, 0.18], ringSpeed: 0.26)
        case .processing:
            Motion(speed: 1.4, amplitude: 0.05, base: [0.14, 0.22, 0.44, 0.22, 0.14], ringSpeed: 0.65)
        case .speaking:
            Motion(speed: 1.8, amplitude: 0.10, base: [0.28, 0.44, 0.34, 0.48, 0.26], ringSpeed: 0.42)
        case .unavailable:
            Motion(speed: 0.45, amplitude: 0, base: [0.18, 0.30, 0.42, 0.30, 0.18], ringSpeed: 0.10)
        }
    }
}
