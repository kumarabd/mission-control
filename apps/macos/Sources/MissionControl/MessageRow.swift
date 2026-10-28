import AppKit
import SwiftUI
import SwiftStreamingMarkdown

struct MessageRow: View {
    let message: ConversationMessage
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user { Spacer(minLength: 90) }
            if message.role == .assistant {
                AssistantGlyph(size: 34, active: !message.isComplete)
            }
            VStack(alignment: .leading, spacing: 10) {
                if !message.progressText.isEmpty {
                    ProgressActivityView(text: message.progressText, isComplete: message.isComplete)
                }
                ForEach(message.tools) { tool in
                    ToolActivityView(tool: tool)
                }
                if !message.text.isEmpty {
                    if message.role == .assistant {
                        LiveMarkdownView(text: message.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(message.text)
                            .foregroundStyle(MissionTheme.ink)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if message.role == .assistant && message.tools.isEmpty {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small)
                        Text("Working…").foregroundStyle(MissionTheme.quietText)
                    }
                }
            }
            .padding(.horizontal, message.role == .user ? 14 : 0)
            .padding(.vertical, message.role == .user ? 10 : 2)
            .background(message.role == .user ? AnyShapeStyle(MissionTheme.raised) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if message.role == .user {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(MissionTheme.line)
                }
            }
            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: message.role == .user ? .bottomTrailing : .bottomLeading) {
            if isHovering, !message.text.isEmpty {
                MessageActions(text: message.text, failed: message.failed)
                    .offset(y: 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .padding(.bottom, isHovering && !message.text.isEmpty ? 22 : 0)
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy") { copy(message.text) }
        }
        .accessibilityElement(children: .contain)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// Bridges the gateway's growing response snapshots into the renderer's native
/// streaming API. The source object survives SwiftUI body updates for a message
/// row, so incoming deltas do not recreate the Markdown rendering pipeline.
private final class GatewayMarkdownSource: StreamedMarkdownSource {
    let text: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation
    private var latest = ""

    init() {
        let stream = AsyncStream.makeStream(
            of: String.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        text = stream.stream
        continuation = stream.continuation
    }

    func update(_ snapshot: String) {
        guard snapshot != latest else { return }
        latest = snapshot
        continuation.yield(snapshot)
    }

    deinit {
        continuation.finish()
    }
}

private struct LiveMarkdownView: View {
    let text: String
    @State private var source = GatewayMarkdownSource()

    var body: some View {
        StreamedMarkdownView(source: source)
            .onChange(of: text, initial: true) { _, snapshot in
                source.update(snapshot)
            }
    }
}

private struct MessageActions: View {
    let text: String
    let failed: Bool

    var body: some View {
        HStack(spacing: 4) {
            if failed {
                Label("Incomplete", systemImage: "exclamationmark.triangle.fill")
                    .font(.mission(.caption))
                    .foregroundStyle(MissionTheme.failure)
                    .padding(.horizontal, 6)
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy message")
            .accessibilityLabel("Copy message")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(MissionTheme.line.opacity(0.65)))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

private struct ProgressActivityView: View {
    let text: String
    let isComplete: Bool
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(text)
                .font(.mission(.callout))
                .foregroundStyle(MissionTheme.quietText)
                .textSelection(.enabled)
                .padding(.top, 6)
        } label: {
            HStack(spacing: 8) {
                if isComplete {
                    Image(systemName: "checkmark.circle")
                } else {
                    ProgressView().controlSize(.mini)
                }
                Text(isComplete ? "Work completed" : "Working")
                    .font(.mission(.callout, .medium))
            }
            .foregroundStyle(MissionTheme.quietText)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(MissionTheme.raised.opacity(0.72), in: MissionTheme.compactShape)
        .overlay(MissionTheme.compactShape.strokeBorder(MissionTheme.line.opacity(0.7)))
    }
}

private struct ToolActivityView: View {
    let tool: ToolActivity
    @State private var expanded = false

    private var isFinished: Bool { ["completed", "error", "cancelled"].contains(tool.status) }

    private var statusColor: Color {
        switch tool.status {
        case "completed": MissionTheme.tint
        case "error", "cancelled": MissionTheme.failure
        default: MissionTheme.telemetry
        }
    }

    private var duration: String? {
        guard let startedAt = tool.startedAt else { return nil }
        let end = tool.completedAt ?? .now
        let seconds = max(0, end.timeIntervalSince(startedAt))
        return seconds < 10 ? String(format: "%.1fs", seconds) : String(format: "%.0fs", seconds)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                if !tool.reason.isEmpty { detail("Reason", tool.reason) }
                if let arguments = tool.arguments { detail("Input", arguments.displayText) }
                if !tool.partialOutput.isEmpty { detail("Progress", tool.partialOutput) }
                if let result = tool.result { detail("Result", result.displayText) }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(MissionTheme.telemetry)
                Text(friendlyName(tool.name)).fontWeight(.medium)
                Spacer()
                if isFinished {
                    Image(systemName: tool.status == "completed" ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(statusColor)
                } else {
                    ProgressView().controlSize(.mini)
                }
                if let duration {
                    Text(duration)
                        .font(.missionMono(.caption)).monospacedDigit()
                        .foregroundStyle(MissionTheme.quietText)
                }
                Text(tool.status.capitalized)
                    .font(.mission(.caption))
                    .foregroundStyle(MissionTheme.quietText)
            }
        }
        .padding(10)
        .background(MissionTheme.raised, in: MissionTheme.compactShape)
        .overlay(MissionTheme.compactShape.strokeBorder(MissionTheme.line))
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title.lowercased()).font(.missionMono(.caption2)).foregroundStyle(MissionTheme.quietText)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .help("Copy \(title.lowercased())")
            }
            ScrollView(.horizontal) {
                Text(value)
                    .font(.missionMono(.caption))
                    .foregroundStyle(MissionTheme.ink)
                    .textSelection(.enabled)
            }
        }
    }

    private func friendlyName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
