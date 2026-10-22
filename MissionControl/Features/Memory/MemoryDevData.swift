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
            case "/v1/explorer/semantic":
                page = samplePage(section: section)
            default:
                return (Data(), HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!)
            }
            return (try Wire.encoder.encode(page), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    )

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
        case SemanticMemory.Lens.persona.rawValue:
            items = [item("lens:persona", "lens", "Persona", """
            # Persona

            You are a founder and engineer building agent infrastructure. You move quickly, prefer direct language, and think in systems.

            - **Work:** product and engineering, close to the code.
            - **Rhythm:** short check-ins, decisions in the morning, deep work when the day allows.
            - **Communication:** plain, specific, no ceremony.
            """, days: 1)]
        case SemanticMemory.Lens.intent.rawValue:
            items = [item("lens:intent", "lens", "Intent", """
            # Intent

            You are designing a composable semantic memory layer for agents, and deciding how much of it the current system already provides.

            - **Now:** evaluate the existing memory surface against the proposed architecture.
            - **Next:** pull persona, intent, and constraints into a study view.
            - **Not now:** build guarantees the system does not need yet.
            """, days: 1)]
        case SemanticMemory.Lens.constraints.rawValue:
            items = [item("lens:constraints", "lens", "Constraints", """
            # Constraints

            - **Time:** short sessions between other work; decisions need to be quick.
            - **Stack:** Postgres, pgvector, Temporal, SwiftUI.
            - **Principle:** avoid speculative complexity; keep the current system's behaviour.
            - **Privacy:** personal memory stays read-only on the phone.
            """, days: 2)]
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
