import SwiftUI

struct ProjectCardView: View {
    let repository: GitHubRepository

    var body: some View {
        Link(destination: repository.htmlURL) {
            MissionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(MissionTheme.tint)
                        Text(repository.name).font(.headline)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    if let description = repository.description {
                        Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack {
                        Label(lastActivity, systemImage: "clock")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(MissionTheme.quietText)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var lastActivity: String {
        guard let pushedAt = repository.pushedAt else { return "No recent activity" }
        return "Updated \(pushedAt.formatted(.relative(presentation: .named)))"
    }
}
