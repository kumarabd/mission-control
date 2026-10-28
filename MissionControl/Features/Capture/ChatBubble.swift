import SwiftUI
import UIKit

/// Who a message is from, for the picture beside it.
struct ChatParty: Equatable {
    var name: String
    var imageURL: String?
    /// Agents without a picture show the assistant's mark; people fall back to their initials.
    var isAgent: Bool = false
}

/// One message of the thread: yours on the right, the assistant's (set as markdown) on the left, each with the sender's
/// picture beside the last message of a run. A message in a run sits
/// close under the one before it, and the last of a run carries the time. Yours also says where it stands: faded while
/// sending, and, if it never got there, red with a way to send it again.
struct ChatBubble: View {
    let item: ChatTranscript.Item
    var groupedAbove = false
    var showsTime = false
    var showsAvatar = false
    var agent = ChatParty(name: "Assistant")
    var you = ChatParty(name: "You")
    var onRetry: () -> Void = {}
    var onExpand: (ChatTranscript.Item) -> Void = { _ in }

    var body: some View {
        VStack(alignment: item.role == .you ? .trailing : .leading, spacing: 3) {
            HStack(alignment: .bottom, spacing: Space.s) {
                if item.role == .you { Spacer(minLength: 24) }
                else { avatar(agent) }
                Group {
                    if item.role == .assistant {
                        AssistantMessage(id: item.id, text: shown, streaming: item.streaming)
                    } else {
                        Text(item.text).font(.mission(.body)).foregroundStyle(Tok.text).textSelection(.enabled)
                    }
                }
                .padding(Space.m)
                .background(item.role == .you ? Tok.accent.opacity(0.14) : Tok.surface, in: MissionTheme.cardShape)
                .overlay { MissionTheme.cardShape.strokeBorder(item.delivery == .failed ? Tok.critical.opacity(0.6) : Tok.hairline) }
                .opacity(item.delivery == .sending ? 0.6 : 1)
                .contextMenu {
                    if item.role == .assistant {
                        Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") { onExpand(item) }
                    }
                    Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = shown }
                    if item.delivery == .failed { Button("Send again", systemImage: "arrow.clockwise", action: onRetry) }
                }
                if item.role == .assistant { Spacer(minLength: 24) }
                else { avatar(you) }
            }
            footer.padding(item.role == .you ? .trailing : .leading, Self.avatarSize + Space.s)
        }
        .padding(.top, groupedAbove ? -Space.s + 2 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel((item.role == .you ? "You: " : "\(agent.name): ") + spoken + (item.delivery == .failed ? ". Not delivered." : ""))
        .accessibilityAction(named: "Send again") { if item.delivery == .failed { onRetry() } }
        .accessibilityAction(named: "Expand message") { if item.role == .assistant { onExpand(item) } }
    }

    /// What is read aloud: what the bubble shows (the condensed text for a long reply), as words without markdown symbols.
    private var spoken: String {
        guard item.role == .assistant else { return item.text }
        let compact = !item.streaming && MessageCondenser.isLong(shown)
        return MessageCondenser.spoken(compact ? MessageCondenser.shared.cached(shown) ?? MessageCondenser.preview(shown) : shown)
    }

    /// The assistant's text without the tool-call transport it may be carrying.
    private var shown: String { item.role == .assistant ? ToolCallText.stripped(item.text) : item.text }

    /// The picture at the end of a run; the rest of the run keeps the same gap so the bubbles stay in line.
    @ViewBuilder private func avatar(_ party: ChatParty) -> some View {
        if showsAvatar { AvatarView(name: party.name, url: party.imageURL, size: Self.avatarSize, agent: party.isAgent).transition(.scale.combined(with: .opacity)) }
        else { Color.clear.frame(width: Self.avatarSize, height: Self.avatarSize) }
    }
    static let avatarSize: CGFloat = 30

    @ViewBuilder private var footer: some View {
        switch item.delivery {
        case .failed:
            Button(action: onRetry) {
                Label("Not delivered \u{00B7} Send again", systemImage: "exclamationmark.circle")
                    .font(.mission(.caption)).foregroundStyle(Tok.critical)
            }
            .buttonStyle(.plain).frame(minHeight: 28)
        case .sending:
            Text("Sending\u{2026}").font(.mission(.caption)).foregroundStyle(Tok.muted)
        case .sent:
            if showsTime, let at = item.at {
                Text(at, format: .dateTime.hour().minute()).font(.mission(.caption)).foregroundStyle(Tok.muted)
            }
        }
    }
}

/// A day heading between messages from different days.
struct ChatDayHeading: View {
    let day: Date
    var body: some View {
        Text(Self.title(day))
            .font(.mission(.caption, .medium)).foregroundStyle(Tok.muted)
            .frame(maxWidth: .infinity).padding(.vertical, Space.xs)
            .accessibilityAddTraits(.isHeader)
    }

    static func title(_ day: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) { return "Yesterday" }
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: now)
        return day.formatted(sameYear ? .dateTime.weekday(.wide).month(.abbreviated).day() : .dateTime.month(.abbreviated).day().year())
    }
}

/// Three dots that rise and fall while the assistant is writing. Still under Reduce Motion.
struct TypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Tok.muted).frame(width: 7, height: 7)
                        .offset(y: reduceMotion ? 0 : -3 * max(0, sin(t * 6 - Double(i) * 0.7)))
                }
            }
        }
        .padding(.horizontal, Space.m).padding(.vertical, 14)
        .background(Tok.surface, in: MissionTheme.cardShape)
        .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
        .accessibilityElement(children: .ignore).accessibilityLabel("The assistant is writing")
    }
}
