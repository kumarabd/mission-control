import SwiftUI

/// Semantic styling primitives used throughout Mission Control.
/// All colors adapt to the system appearance and accessibility settings.
enum MissionTheme {
    static let tint = Color.cyan
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let quietText = Color(uiColor: .secondaryLabel)

    static let cardShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    static let compactShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
}

struct MissionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(.regularMaterial, in: MissionTheme.cardShape)
            .overlay {
                MissionTheme.cardShape
                    .strokeBorder(.primary.opacity(0.06))
            }
            .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
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
                .font(.title3.weight(.bold))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MissionTheme.quietText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
