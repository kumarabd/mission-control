import Foundation

struct SessionSummary: Codable, Identifiable, Hashable {
    let sessionID: String
    let parentSessionID: String?
    let createdAt: Date
    let updatedAt: Date
    var title: String
    var preview: String
    var isRunning: Bool

    var id: String { sessionID }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case parentSessionID = "parent_session_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case title, preview
        case isRunning = "is_running"
    }

    static func main(now: Date = .now) -> Self {
        .init(
            sessionID: "main",
            parentSessionID: nil,
            createdAt: now,
            updatedAt: now,
            title: "Main conversation",
            preview: "",
            isRunning: false
        )
    }

    /// A new conversation is deliberately a root session. Branching an
    /// existing chat is always an explicit fork action.
    static func newConversation(sessionID: String, now: Date = .now) -> Self {
        .init(
            sessionID: sessionID,
            parentSessionID: nil,
            createdAt: now,
            updatedAt: now,
            title: "New conversation",
            preview: "",
            isRunning: false
        )
    }

    /// A child of an existing conversation. Its first message creates the
    /// branch on the gateway, the same as the web client's fork.
    static func forked(from parent: SessionSummary, sessionID: String, now: Date = .now) -> Self {
        .init(
            sessionID: sessionID,
            parentSessionID: parent.sessionID,
            createdAt: now,
            updatedAt: now,
            title: "Fork of \(parent.title)",
            preview: "",
            isRunning: false
        )
    }
}

enum ConnectionState: Equatable {
    case connecting
    case live
    case reconnecting
    case offline(String?)
}

enum AssistantState: String {
    case ready = "Ready"
    case thinking = "Thinking"
    case responding = "Responding"
}

struct ConversationMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
    }

    let id: String
    let turnSequence: Int
    let sequence: Int
    let role: Role
    var text: String
    var progressText: String = ""
    var tools: [ToolActivity] = []
    var isComplete = false
    var failed = false
}

struct ToolActivity: Identifiable, Equatable {
    let id: String
    let name: String
    var status: String
    var arguments: JSONValue?
    var result: JSONValue?
    var partialOutput: String
    var reason: String
    var startedAt: Date?
    var completedAt: Date?
}

struct GatewayQuestion: Equatable {
    struct Option: Codable, Identifiable, Equatable {
        let id: String
        let label: String
    }

    let requestID: String
    let kind: String
    let prompt: String
    let options: [Option]
    let allowsFreeText: Bool
}

/// A skill task's place in its steps. It belongs to the task, not to a turn:
/// the turn that started it may already have ended.
struct TaskProgress: Identifiable, Equatable {
    let taskID: String
    let skill: String
    let step: Int
    let total: Int
    let title: String
    let state: String

    var id: String { taskID }
    var isRunning: Bool { state == "running" }
    var label: String { skill.replacingOccurrences(of: "-", with: " ").capitalized }
}

indirect enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var displayText: String {
        guard let data = try? JSONEncoder.pretty.encode(self),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}

private extension JSONEncoder {
    static let pretty: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
}

struct GatewayFrame: Decodable {
    let type: String
    let turnSequence: Int?
    let throughTurnSequence: Int?
    let sequence: Int?
    let messageSequence: Int?
    let role: String?
    let content: String?
    let clientMessageID: String?
    let text: String?
    let replace: Bool?
    let progress: Bool?
    let requestID: String?
    let kind: String?
    let prompt: String?
    let options: [GatewayQuestion.Option]?
    let allowsFreeText: Bool?
    let status: String?
    let state: String?
    let message: String?
    let taskID: String?
    let skill: String?
    let step: Int?
    let total: Int?
    let title: String?
    let toolCallID: String?
    let toolName: String?
    let arguments: JSONValue?
    let result: JSONValue?
    let partialOutput: String?
    let reason: String?
    let startedAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case type, role, content, text, replace, progress, kind, prompt, options, status, state, message
        case result, arguments, reason, skill, step, total, title
        case taskID = "task_id"
        case turnSequence = "turn_seq"
        case throughTurnSequence = "through_turn_seq"
        case sequence = "seq"
        case messageSequence = "message_seq"
        case clientMessageID = "client_msg_id"
        case requestID = "request_id"
        case allowsFreeText = "allow_free_text"
        case toolCallID = "tool_call_id"
        case toolName = "tool_name"
        case partialOutput = "partial_output"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct PollResponse: Decodable {
    struct Turn: Decodable {
        let turnSequence: Int
        let status: String
        let userContent: String
        let content: String

        enum CodingKeys: String, CodingKey {
            case status, content
            case turnSequence = "turn_seq"
            case userContent = "user_content"
        }
    }

    let turns: [Turn]?
    let pendingInput: PendingQuestion?

    struct PendingQuestion: Decodable {
        let requestID: String
        let kind: String
        let prompt: String
        let options: [GatewayQuestion.Option]
        let allowsFreeText: Bool

        enum CodingKeys: String, CodingKey {
            case kind, prompt, options
            case requestID = "request_id"
            case allowsFreeText = "allow_free_text"
        }
    }

    enum CodingKeys: String, CodingKey {
        case turns
        case pendingInput = "pending_input"
    }
}
