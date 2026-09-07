import SwiftUI

struct ProjectCardView: View {
    let repository: GitHubRepository

    var body: some View {
        Link(destination: repository.htmlURL) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(Color.accentColor)
                    Text(repository.name).font(.headline)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
                if let description = repository.description {
                    Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                Label(lastActivity, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var lastActivity: String {
        guard let pushedAt = repository.pushedAt else { return "No recent activity" }
        return "Updated \(pushedAt.formatted(.relative(presentation: .named)))"
    }
}
