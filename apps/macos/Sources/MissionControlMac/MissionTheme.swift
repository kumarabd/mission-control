import AppKit
import CoreText
import SwiftUI

/// Desktop expression of the same semantic palette used by the iOS and
/// Android clients. Values adapt to light, dark, and increased-contrast modes.
enum MissionTheme {
    static let tint = adaptive(light: 0x4E6A37, dark: 0xA9C985, lightContrast: 0x1C2D12, darkContrast: 0xE5F4D6)
    static let canvas = adaptive(light: 0xF7F8F3, dark: 0x101211, lightContrast: 0xF5F4EF, darkContrast: 0x0B0D0C)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x191D1B, lightContrast: 0xFFFFFF, darkContrast: 0x151815)
    static let raised = adaptive(light: 0xE5E8DF, dark: 0x222824, lightContrast: 0xE0E5DA, darkContrast: 0x29302B)
    static let ink = adaptive(light: 0x18211B, dark: 0xE8EEE9, lightContrast: 0x11150D, darkContrast: 0xFFFFFF)
    static let quietText = adaptive(light: 0x566159, dark: 0xA8B2AA, lightContrast: 0x272D20, darkContrast: 0xDDE4DE)
    static let line = adaptive(light: 0xCED1C5, dark: 0x313A35, lightContrast: 0x6C7561, darkContrast: 0x89947B)
    static let actionInk = adaptive(light: 0xFFFFFF, dark: 0x20271C, lightContrast: 0xFFFFFF, darkContrast: 0x11170B)
    static let scheduled = adaptive(light: 0x1B3656, dark: 0xC6E2FF, lightContrast: 0x102E4C, darkContrast: 0xC5E1FF)
    static let attention = adaptive(light: 0x8A6619, dark: 0xF2C879, lightContrast: 0x503309, darkContrast: 0xFFE0A8)
    static let reminder = adaptive(light: 0x9A4C3E, dark: 0xE6A18C, lightContrast: 0x4A1A11, darkContrast: 0xFFD0BF)
    static let telemetry = adaptive(light: 0x2E6F7E, dark: 0x74B9C8, lightContrast: 0x103638, darkContrast: 0xCFFAF3)
    static let failure = Color(nsColor: .systemRed)

    static let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    static let compactShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    private static func adaptive(light: UInt32, dark: UInt32, lightContrast: UInt32, darkContrast: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastAqua,
                .darkAqua,
                .aqua,
            ])
            let value: UInt32
            switch match {
            case .accessibilityHighContrastDarkAqua: value = darkContrast
            case .accessibilityHighContrastAqua: value = lightContrast
            case .darkAqua: value = dark
            default: value = light
            }
            return NSColor(
                red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255,
                alpha: 1
            )
        })
    }
}

struct MissionCard<Content: View>: View {
    var tint = MissionTheme.surface
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .background(tint, in: MissionTheme.cardShape)
            .overlay(MissionTheme.cardShape.strokeBorder(MissionTheme.line))
    }
}

struct AssistantGlyph: View {
    var size: CGFloat = 42
    var active = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.20, style: .continuous)
                .stroke(MissionTheme.tint.opacity(0.68), lineWidth: 1)
                .frame(width: size * 0.72, height: size * 0.72)
                .rotationEffect(.degrees(28))
            RoundedRectangle(cornerRadius: size * 0.17, style: .continuous)
                .stroke(MissionTheme.tint.opacity(0.34), lineWidth: 1)
                .frame(width: size * 0.57, height: size * 0.61)
                .rotationEffect(.degrees(64))
            HStack(spacing: max(2, size * 0.045)) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(MissionTheme.tint)
                        .frame(width: max(2, size * 0.045), height: active ? size * (index.isMultiple(of: 2) ? 0.28 : 0.17) : size * 0.07)
                }
            }
        }
        .frame(width: size, height: size)
        .background(MissionTheme.tint.opacity(active ? 0.18 : 0.10), in: Circle())
        .overlay(Circle().strokeBorder(MissionTheme.tint.opacity(0.45)))
        .accessibilityHidden(true)
    }
}

/// Hanken Grotesk for text, IBM Plex Mono for small labels, matching the web console.
/// Registered at launch from the app bundle; falls back to the system font if missing.
enum MissionFonts {
    static func register() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

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
    }
}
