import SwiftUI

/// A voice session takes over the chat: the assistant's mark, alive, over a dimmed thread — the phone's version of the
/// CarPlay voice screen, same artwork and same states, with the live words beneath it. Semi-transparent on purpose:
/// the conversation stays visible behind the card, but the assistant is what is happening.
struct VoiceOverlay: View {
    let state: AssistantVoiceCoordinator.State
    let userWords: String
    let reply: String
    let onEnd: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringPulse = false

    var body: some View {
        ZStack {
            Tok.background.opacity(0.62)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}   // the thread behind is not tappable while the assistant has the conversation
            card.padding(Space.l)
        }
        .accessibilityAddTraits(.isModal)
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private var card: some View {
        VStack(spacing: Space.l) {
            ZStack {
                Circle()
                    .strokeBorder(Tok.accent.opacity(0.4), lineWidth: 1)
                    .frame(width: 170, height: 170)
                    .scaleEffect(ringPulse ? 1.16 : 0.95)
                    .opacity(ringPulse ? 0.12 : 0.55)
                Circle()
                    .fill(Tok.accent.opacity(0.08))
                    .frame(width: 170, height: 170)
                AgentMark(state: state, size: 176, animated: true)
                    .frame(width: 176, height: 176)
            }
            .frame(height: 190)
            .accessibilityHidden(true)

            Text(status)
                .font(.mission(.title3, .medium))
                .foregroundStyle(Tok.text)
                .multilineTextAlignment(.center)
                .accessibilityLabel(status)

            if !userWords.isEmpty {
                words("You", userWords, muted: true)
            }
            if !reply.isEmpty {
                words("Mission Control", reply, muted: false)
            }

            Button(role: .destructive, action: onEnd) {
                Label("End voice", systemImage: "stop.circle.fill")
                    .font(.mission(.headline, .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Tok.critical)
        }
        .padding(Space.xl)
        .frame(maxWidth: 440)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(Tok.hairline)
        }
        .shadow(color: .black.opacity(0.18), radius: 30, y: 12)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { ringPulse = true }
        }
    }

    private func words(_ who: String, _ text: String, muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(who)
                .font(.mission(.caption, .semibold))
                .foregroundStyle(Tok.muted)
            Text(text)
                .font(.mission(muted ? .callout : .body))
                .foregroundStyle(muted ? Tok.muted : Tok.text)
                .lineLimit(muted ? 3 : 5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var status: String {
        switch state {
        case .preparing: return "Getting ready…"
        case .listening: return "Listening…"
        case .processing: return "Thinking…"
        case .speaking: return "Speaking…"
        case .idle, .unavailable: return ""
        }
    }
}
