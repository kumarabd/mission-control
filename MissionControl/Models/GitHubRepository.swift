import Foundation

struct GitHubRepository: Identifiable, Hashable {
    let id: Int64
    let name: String
    let description: String?
    let htmlURL: URL
    let pushedAt: Date?
}
