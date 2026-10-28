import AppKit
import CoreText
import SwiftUI

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

/// Registers the bundled Hanken Grotesk and IBM Plex Mono faces at launch.
enum MissionFonts {
    static func register() {
        #if SWIFT_PACKAGE
        let bundles = [Bundle.module, Bundle.main]
        #else
        let bundles = [Bundle.main]
        #endif
        for bundle in bundles {
            for url in bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
