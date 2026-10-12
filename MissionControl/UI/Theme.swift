import SwiftUI

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// New screens read the original Mission Control palette (sage green on warm neutrals) through these names.
enum Tok {
    static let background = MissionTheme.canvas
    static let surface = MissionTheme.surface
    static let raised = MissionTheme.raised
    static let hairline = MissionTheme.line
    static let text = MissionTheme.ink
    static let muted = MissionTheme.quietText
    static let accent = MissionTheme.tint
    static let onAccent = MissionTheme.actionInk
    static let live = MissionTheme.telemetry
    static let warn = MissionTheme.attention
    static let critical = MissionTheme.failure
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mission(.headline, .medium))
            .foregroundStyle(Tok.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Tok.accent.opacity(enabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func field() -> some View {
        padding(.horizontal, 14).frame(minHeight: 52)
            .background(Tok.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
