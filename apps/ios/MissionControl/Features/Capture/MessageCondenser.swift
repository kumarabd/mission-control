import Foundation
import FoundationModels
import CryptoKit

/// Condenses a long assistant reply to a sentence or two, on the phone, with Apple's on-device model. Nothing leaves
/// the device, and when the model is unavailable (or declines) the message is simply drawn in full.
@MainActor
final class MessageCondenser {
    static let shared = MessageCondenser()
    /// Above this length a reply is worth condensing; shorter ones already fit a glance (or a spoken line).
    nonisolated static let compactLength = 200
    /// Long by length, or by shape: a short list or several paragraphs still takes a screen.
    nonisolated static func isLong(_ text: String) -> Bool {
        text.count > compactLength || text.split(whereSeparator: \.isNewline).filter { !$0.allSatisfy(\.isWhitespace) }.count > 3
    }

    /// Summaries by the digest of the message they condense, kept on disk: a long reply never changes once it is said, so
    /// it is condensed once, not on every launch or every time its row is rebuilt.
    private var cache: [String: String]
    private static let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("message-summaries.json")
    private static func key(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    /// A condensed message is a sentence or two. The model sometimes hands the message back whole; that is not a summary.
    nonisolated static let maxSummary = 280
    private init() {
        let kept = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: Self.file))) ?? [:]
        cache = kept.filter { $0.value.count <= Self.maxSummary }
    }
    private var inFlight: [String: Task<String?, Never>] = [:]
    private let cacheLimit = 200

    /// A summary already made, so a row that scrolls back into view draws it at once instead of flashing the preview.
    func cached(_ text: String) -> String? { cache[Self.key(text)] }

    func summary(of text: String) async -> String? {
        if let cached = cached(text) { return cached }
        if let running = inFlight[text] { return await running.value }

        let task = Task { await Self.condense(text) }
        inFlight[text] = task
        let result = await task.value
        inFlight[text] = nil
        // Too long to be a summary (or just the message again): keep the plain preview instead, so it is not asked again.
        let kept = result.flatMap { $0.count <= Self.maxSummary && $0 != text ? $0 : nil } ?? Self.preview(text)
        if cache.count >= cacheLimit { cache.removeAll() }
        cache[Self.key(text)] = kept
        try? JSONEncoder().encode(cache).write(to: Self.file, options: .atomic)
        return kept
    }

    /// One or two plain sentences, carrying the point and any concrete names, numbers or dates. No model, no summary.
    private static func condense(_ text: String) async -> String? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return nil }

        let session = LanguageModelSession(instructions: """
            You rewrite one message from an assistant in a chat as the short chat reply that assistant would say next \
            in the conversation. Make it conversational: first person ("I"), speaking to "you", the way you'd say it \
            in the thread — not a report, a summary, or third-person narration. Keep only what matters to them: what \
            you did or found, what they need to know, what you need from them, and any concrete names, numbers, times \
            or dates. Drop reasoning, decisions, process, tool names and explanations of how or why. One or two short \
            conversational sentences, no greeting, no list. You may put **bold** on the few names, numbers, times or dates that matter, and nothing else. Never add anything that is not in the \
            message. If nothing in it matters to them, say so briefly in that voice.
            """)
        do {
            let response = try await session.respond(to: String(text.prefix(6000)))
            let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return summary.isEmpty ? nil : summary
        } catch {
            return nil
        }
    }

    /// Markdown as it should be read aloud: the words, without the symbols that draw them.
    nonisolated static func spoken(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"```[\s\S]*?```"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"!?\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*(?:[-*+]|\d+\.)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[#>*_`~|]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What to show while the model is thinking — or instead of it, on a device without Apple Intelligence.
    nonisolated static func preview(_ text: String) -> String {
        let plain = text
            .replacingOccurrences(of: #"```[\s\S]*?```"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[#>*_`~]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = 240
        guard plain.count > 160 else { return plain }
        let head = String(plain.prefix(limit))
        if let end = head.lastIndex(where: { ".!?".contains($0) }),
           head.distance(from: head.startIndex, to: end) > 80 {
            return String(head[...end])
        }
        if let space = head.lastIndex(of: " ") { return String(head[..<space]) + "…" }
        return head + "…"
    }
}
