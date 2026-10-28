import Foundation

/// The recent part of the conversation, kept on the phone so the chat opens with it at once, before the gateway has
/// answered. It is only the recent window (`ChatTranscript.window`): whatever was scrolled back to is not kept, so a fresh
/// start is always the last few messages. One file per person and agent, so a second account never sees the first one's and each agent keeps its own thread.
enum ChatStore {
    static let defaultAgent = "main"

    /// The default agent keeps the file name it always had; any other agent adds its id.
    static func url(owner: String, agent: String = defaultAgent, in directory: URL? = nil) -> URL {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let safe = owner.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        let suffix = agent == defaultAgent ? "" : "-" + String(agent.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" })
        return base.appendingPathComponent("chat-" + String(safe) + suffix + ".json")
    }

    /// What was kept, or nothing when there is no file. A file that cannot be read is an error to report, not an empty chat.
    static func load(owner: String, agent: String = defaultAgent, in directory: URL? = nil) throws -> [ChatTranscript.Item] {
        let file = url(owner: owner, agent: agent, in: directory)
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([ChatTranscript.Item].self, from: Data(contentsOf: file))
    }

    static func save(_ items: [ChatTranscript.Item], owner: String, agent: String = defaultAgent, in directory: URL? = nil) throws {
        let file = url(owner: owner, agent: agent, in: directory)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(items).write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func remove(owner: String, agent: String = defaultAgent, in directory: URL? = nil) {
        try? FileManager.default.removeItem(at: url(owner: owner, agent: agent, in: directory))
    }
}
