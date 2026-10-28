#if DEBUG
import Foundation

/// Developer-mode memory, so the Memory tab can be run and looked at without a
/// workspace. It mirrors the real `/semantic` wire shape exactly; only the
/// content is sample data. Never ships.
extension MemoryService {
    static let devSample = MemoryService(
        baseURL: "https://dev.local/brain",
        token: { "dev" },
        transport: { request in
            let url = request.url!
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let section = query.first { $0.name == "section" }?.value ?? "reflections"
            let page: SemanticMemory.Page
            switch url.path {
            case "/v1/explorer/memory/facts":
                return (try Wire.encoder.encode(EntityMemory.Page(bankAvailable: true, items: [], hasMore: false, limit: 20, offset: 0)),
                        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            case "/v1/explorer/semantic/world":
                return (try Wire.encoder.encode(sampleWorld()),
                        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            case "/v1/explorer/semantic":
                page = samplePage(section: section)
            default:
                return (Data(), HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!)
            }
            return (try Wire.encoder.encode(page), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    )

    /// A small believable world, so the diagram can be looked at without a workspace. Mirrors the real wire shape.
    private static func sampleWorld() -> SemanticWorld.Graph {
        func node(_ key: String, _ label: String, _ type: String?, _ attributes: [String: String], mentions: Int) -> SemanticWorld.Node {
            SemanticWorld.Node(id: "entity:" + key, kind: "entity", subtype: type, label: label, attributes: attributes.isEmpty ? nil : attributes, mentionCount: mentions)
        }
        func edge(_ from: String, _ predicate: String, _ to: String, facts: Int) -> SemanticWorld.Edge {
            SemanticWorld.Edge(from: "entity:" + from, to: "entity:" + to, type: "relation", label: predicate, sourceCount: facts)
        }
        return SemanticWorld.Graph(
            schemaVersion: 1, retrievedAt: Date(), bankAvailable: true,
            nodes: [
                node("you", "You", "person", ["role": "founder and engineer", "city": "Lisbon", "rhythm": "decides in the morning"], mentions: 42),
                node("agent-brain", "Agent Brain", "project", ["status": "active", "stack": "Postgres, Temporal"], mentions: 31),
                node("mission-control", "Mission Control", "project", ["platform": "iOS and iPad"], mentions: 18),
                node("dana", "Dana", "person", ["role": "designer"], mentions: 9),
                node("acme", "Acme", "company", ["industry": "logistics"], mentions: 7),
                node("lisbon", "Lisbon", "place", [:], mentions: 6),
                node("postgres", "Postgres", "tool", [:], mentions: 5),
                node("mara", "Mara", nil, [:], mentions: 2),
            ],
            edges: [
                edge("you", "builds", "agent-brain", facts: 12),
                edge("you", "builds", "mission-control", facts: 8),
                edge("you", "lives_in", "lisbon", facts: 3),
                edge("dana", "designs", "mission-control", facts: 4),
                edge("you", "works_with", "dana", facts: 5),
                edge("dana", "works_at", "acme", facts: 2),
                edge("agent-brain", "uses", "postgres", facts: 6),
            ],
            truncated: false, limit: 100
        )
    }

    private static func samplePage(section: String) -> SemanticMemory.Page {
        let now = Date()
        func item(_ id: String, _ kind: String, _ title: String, _ content: String, days: Int) -> SemanticMemory.Item {
            SemanticMemory.Item(
                id: id, kind: kind, title: title, content: content,
                updatedAt: now.addingTimeInterval(-Double(days) * 86_400), createdAt: now.addingTimeInterval(-Double(days + 2) * 86_400),
                availability: "ready", sourceStatus: "not_recorded", entities: [], truncated: false, sources: []
            )
        }
        let items: [SemanticMemory.Item]
        switch section {
        case "about_you":
            items = [item("model:about-you", "personal_model", "About you", """
            # About you

            You are building a memory system that can explain what it knows, why it believes it, and what it is still missing.
            """, days: 3)]
        default:
            items = [
                item("observation:1", "observation", "Reflection", "You prefer to understand the system before changing it. A smaller, verified step is worth more to you than a larger, speculative one.", days: 0),
                item("model:work-patterns", "mental_model", "Work patterns", "You think best in the morning, keep decisions small, and return to the same problem until its shape is clear.", days: 2),
            ]
        }
        return SemanticMemory.Page(
            schemaVersion: 1, section: section, retrievedAt: now, bankAvailable: true,
            items: items, hasMore: false, offset: 0, limit: 20
        )
    }
}
#endif
