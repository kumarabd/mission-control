import SwiftUI

/// The desktop page header: a mono eyebrow, a large title, one quiet sentence
/// and the actions that belong to the surface. It is the macOS counterpart of
/// the web's `Screen` header, so both clients carry the same hierarchy.
struct ConsolePageHeader<Actions: View>: View {
    var eyebrow: String?
    var title: String
    var description: String?
    @ViewBuilder var actions: () -> Actions

    init(
        _ title: String,
        eyebrow: String? = nil,
        description: String? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.description = description
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Space.l) {
            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.missionMono(.caption, .medium))
                        .tracking(1.2)
                        .foregroundStyle(Tok.muted)
                }
                Text(title)
                    .font(.mission(.largeTitle, .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(Tok.text)
                if let description {
                    Text(description)
                        .font(.mission(.body))
                        .foregroundStyle(Tok.muted)
                        .lineLimit(2)
                        .frame(maxWidth: 620, alignment: .leading)
                }
            }
            Spacer(minLength: Space.l)
            HStack(spacing: Space.s) { actions() }
                .fixedSize()
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.l)
        .padding(.bottom, Space.m)
        .accessibilityElement(children: .contain)
    }
}

extension ConsolePageHeader where Actions == EmptyView {
    init(_ title: String, eyebrow: String? = nil, description: String? = nil) {
        self.init(title, eyebrow: eyebrow, description: description) { EmptyView() }
    }
}

/// A compact fact on a page: label, value, and one line of context.
struct ConsoleStat: View {
    let label: String
    let value: String
    var hint: String?
    var symbol: String
    var tint: Color = Tok.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Space.xs) {
                Text(label.uppercased())
                    .font(.missionMono(.caption2, .medium))
                    .tracking(0.7)
                    .foregroundStyle(Tok.muted)
                Spacer(minLength: 0)
                Image(systemName: symbol)
                    .font(.mission(.caption))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(.mission(.title2, .semibold))
                .monospacedDigit()
                .foregroundStyle(Tok.text)
            if let hint {
                Text(hint)
                    .font(.mission(.caption))
                    .foregroundStyle(Tok.muted)
                    .lineLimit(1)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tok.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Tok.hairline)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A section-level failure or notice with a retry, not a blank panel.
struct ConsoleNotice: View {
    let title: String
    var message: String?
    var retryTitle = "Try again"
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: "exclamationmark.triangle")
                .font(.mission(.body))
                .foregroundStyle(Tok.warn)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.mission(.callout, .medium))
                if let message {
                    Text(message).font(.mission(.caption)).foregroundStyle(Tok.muted)
                }
            }
            Spacer(minLength: Space.s)
            if let retry {
                Button(retryTitle, action: retry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(Space.m)
        .background(Tok.warn.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Tok.warn.opacity(0.25))
        }
        .accessibilityElement(children: .contain)
    }
}

/// Loading placeholders that keep the page shape while the first read lands.
struct ConsoleSkeletonRows: View {
    var count = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: Space.m) {
                    Circle().fill(Tok.raised).frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(Tok.raised).frame(height: 9).frame(maxWidth: index == 1 ? 190 : 250, alignment: .leading)
                        Capsule().fill(Tok.raised.opacity(0.7)).frame(width: 120, height: 7)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.m)
                if index < count - 1 { Divider().padding(.leading, 42) }
            }
        }
        .opacity(pulse ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel("Loading")
    }
}

/// A hover tone for rows and cards on the desktop. Movement is tiny; the state
/// is the point.
struct HoverHighlight: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    var radius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(hovered ? Tok.raised.opacity(0.62) : .clear, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
    }
}

extension View {
    func hoverHighlight(radius: CGFloat = 8) -> some View {
        modifier(HoverHighlight(radius: radius))
    }
}

/// A card that owns a list or a timeline; rows sit flush to its edges.
struct ConsolePanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(Tok.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Tok.hairline)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
