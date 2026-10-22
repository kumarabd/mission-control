import SwiftUI

enum Space {
    static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24
}

extension View {
    /// Every productivity screen sits on the canvas, edge to edge.
    func screenBackground() -> some View { background(Tok.background.ignoresSafeArea()) }
    /// On a wide screen (iPad) a list or column of text reads best at a measure, centred on the canvas, not run edge to edge.
    /// A no-op on iPhone, where the screen is already narrower than the cap.
    func readableWidth(_ max: CGFloat = 720) -> some View { frame(maxWidth: max).frame(maxWidth: .infinity) }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mission(.headline, .medium))
            .foregroundStyle(Tok.accent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Tok.accent.opacity(0.12), in: MissionTheme.cardShape)
            .overlay { MissionTheme.cardShape.strokeBorder(Tok.accent.opacity(0.25)) }
            .opacity(enabled ? (configuration.isPressed ? 0.78 : 1) : 0.4)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A short selectable choice, e.g. "10 min / 20 min / 45 min". Selection is shown by fill and a checkmark, not colour alone.
struct Chip: View {
    let title: String
    var symbol: String?
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if selected { Image(systemName: "checkmark").font(.mission(.caption, .semibold)) }
                else if let symbol { Image(systemName: symbol).font(.mission(.caption, .medium)) }
                Text(title).font(.mission(.subheadline, .medium))
            }
            .padding(.horizontal, Space.l).frame(minHeight: 44)
            .foregroundStyle(selected ? Tok.onAccent : Tok.text)
            .background(selected ? Tok.accent : Tok.raised, in: Capsule())
        }
        .buttonStyle(MissionPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// What a screen shows before it has content: says what the screen is for and offers the first step.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: symbol).font(.mission(.largeTitle)).foregroundStyle(Tok.accent).accessibilityHidden(true)
            Text(title).font(.mission(.title3, .medium)).multilineTextAlignment(.center)
            Text(message).font(.mission(.body)).foregroundStyle(Tok.muted).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(PrimaryButtonStyle()).padding(.top, Space.s)
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// Progress as a bar with its value in words, so it reads without the colour.
struct MissionProgressBar: View {
    let fraction: Double
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tok.raised)
                    Capsule().fill(Tok.accent).frame(width: geo.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 8)
            Text(label).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(min(max(fraction, 0), 1) * 100)) percent")
    }
}

