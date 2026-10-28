import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Semantic styling primitives used throughout Mission Control.
/// All colors adapt to the system appearance and accessibility settings.
enum MissionTheme {
    static let tint = adaptive(light: 0x4E6A37, dark: 0xA9C985, lightContrast: 0x1C2D12, darkContrast: 0xE5F4D6)
    static let canvas = adaptive(light: 0xF7F8F3, dark: 0x101211, lightContrast: 0xF5F4EF, darkContrast: 0x111210)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x191D1B, lightContrast: 0xFFFFFF, darkContrast: 0x1C1E1A)
    static let raised = adaptive(light: 0xE5E8DF, dark: 0x222824, lightContrast: 0xE0E5DA, darkContrast: 0x292D25)
    static let ink = adaptive(light: 0x18211B, dark: 0xE8EEE9, lightContrast: 0x11150D, darkContrast: 0xFFFFFF)
    static let quietText = adaptive(light: 0x566159, dark: 0xA8B2AA, lightContrast: 0x272D20, darkContrast: 0xE3E6DA)
    static let line = adaptive(light: 0xCED1C5, dark: 0x313A35, lightContrast: 0x6C7561, darkContrast: 0x89947B)
    static let warm = attention
    static let actionInk = adaptive(light: 0xFFFFFF, dark: 0x18211B, lightContrast: 0xFFFFFF, darkContrast: 0x11170B)
    static let scheduled = adaptive(light: 0x1B3656, dark: 0xC6E2FF, lightContrast: 0x102E4C, darkContrast: 0xC5E1FF)
    static let attention = adaptive(light: 0x8A6619, dark: 0xF2C879, lightContrast: 0x503309, darkContrast: 0xFFE0A8)
    static let reminder = adaptive(light: 0x9A4C3E, dark: 0xE6A18C, lightContrast: 0x4A1A11, darkContrast: 0xFFD0BF)
    static let telemetry = adaptive(light: 0x2E6F7E, dark: 0x74B9C8, lightContrast: 0x103638, darkContrast: 0xCFFAF3)
    static let health = adaptive(light: 0x5A302B, dark: 0xF2CCC4, lightContrast: 0x472017, darkContrast: 0xFFD7CF)
    static let success = adaptive(light: 0x35734A, dark: 0x8FCE99, lightContrast: 0x1F4A2E, darkContrast: 0xB6E3BF)
    /// The graph pane's recessed surface, shared with the web graph canvas.
    static let graphCanvas = adaptive(light: 0xF1F3EC, dark: 0x151916, lightContrast: 0xEFF1E9, darkContrast: 0x0B0D0C)
    #if canImport(UIKit)
    static let failure = Color(uiColor: .systemRed)
    #else
    static let failure = Color(nsColor: .systemRed)
    #endif

    static let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    static let compactShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    private static func adaptive(light: UInt32, dark: UInt32, lightContrast: UInt32, darkContrast: UInt32) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            let high = traits.accessibilityContrast == .high
            let value = traits.userInterfaceStyle == .dark ? (high ? darkContrast : dark) : (high ? lightContrast : light)
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
        #else
        Color(nsColor: NSColor(name: nil) { appearance in
            let value: UInt32
            switch appearance.bestMatch(from: [.accessibilityHighContrastDarkAqua, .accessibilityHighContrastAqua, .darkAqua, .aqua]) {
            case .accessibilityHighContrastDarkAqua: value = darkContrast
            case .accessibilityHighContrastAqua: value = lightContrast
            case .darkAqua: value = dark
            default: value = light
            }
            return NSColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
        #endif
    }
}

/// Meaning stays consistent across timeline markers, lists, and details.
enum MissionTone: String, CaseIterable, Identifiable {
    case focus, scheduled, attention, reminder, completed
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .focus: MissionTheme.tint
        case .scheduled: MissionTheme.scheduled
        case .attention: MissionTheme.attention
        case .reminder: MissionTheme.reminder
        case .completed: MissionTheme.quietText
        }
    }
    var symbol: String {
        switch self {
        case .focus: "scope"
        case .scheduled: "calendar"
        case .attention: "exclamationmark.bubble"
        case .reminder: "bell"
        case .completed: "checkmark.circle"
        }
    }
    var label: String {
        switch self {
        case .focus: "Focus"
        case .scheduled: "Scheduled"
        case .attention: "Needs action"
        case .reminder: "Reminder"
        case .completed: "Completed"
        }
    }
}

struct MissionIconBadge: View {
    let symbol: String
    var color: Color = MissionTheme.tint
    var padding: CGFloat = 12
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        Image(systemName: symbol)
            .font(.mission(.body, .medium)).symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .padding(padding)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(contrast == .increased ? 1 : 0.22)) }
            .accessibilityHidden(true)
    }
}

struct MissionStatusLabel: View {
    let title: String
    let tone: MissionTone
    var body: some View {
        Label(title, systemImage: tone.symbol)
            .font(.missionMono(.caption, .medium)).foregroundStyle(tone.color)
    }
}

struct MissionCard<Content: View>: View {
    var tint: Color = MissionTheme.surface
    let content: Content

    init(tint: Color = MissionTheme.surface, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(tint, in: MissionTheme.cardShape)
            .overlay {
                MissionTheme.cardShape
                    .strokeBorder(MissionTheme.line)
            }
    }
}

struct MissionPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DashboardLabel: View {
    let title: String
    var body: some View {
        Text(title.lowercased()).font(.missionMono(.caption)).foregroundStyle(MissionTheme.quietText)
    }
}

struct SectionHeading: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.mission(.title3, .medium)).tracking(-0.3)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.missionMono(.subheadline))
                    .foregroundStyle(MissionTheme.quietText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Hanken Grotesk for text, IBM Plex Mono for small labels, matching the web console.
/// Both scale with Dynamic Type. Falls back to the system font if the files are missing.
extension Font {
    static func mission(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .custom("Hanken Grotesk", size: style.missionSize, relativeTo: style).weight(weight)
    }

    static func missionMono(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .custom(weight == .regular ? "IBMPlexMono" : "IBMPlexMono-Medium", size: style.missionSize, relativeTo: style)
    }
}

private extension Font.TextStyle {
    var missionSize: CGFloat {
        #if os(macOS)
        switch self {
        case .largeTitle: 30
        case .title: 26
        case .title2: 20
        case .title3: 17
        case .headline, .body: 14
        case .callout: 13
        case .subheadline: 12
        case .footnote, .caption: 11
        case .caption2: 10
        @unknown default: 14
        }
        #else
        switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
        #endif
    }
}
