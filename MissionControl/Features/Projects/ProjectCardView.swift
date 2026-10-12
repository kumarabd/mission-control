import SwiftUI

struct ProjectCardView: View {
    let repository: GitHubRepository

    var body: some View {
        NavigationLink(value: repository) {
            MissionCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        MissionIconBadge(symbol: projectSymbol, color: projectTint)
                        Text(repository.name).font(.mission(.headline))
                        Spacer()
                        Image(systemName: "chevron.right").font(.mission(.caption, .medium)).foregroundStyle(MissionTheme.quietText)
                    }
                    if let description = repository.description {
                        Text(description).font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
                    }
                    HStack {
                        Label(lastActivity, systemImage: "clock")
                            .font(.mission(.caption, .medium))
                            .foregroundStyle(MissionTheme.quietText)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MissionPressStyle())
    }

    private var lastActivity: String {
        guard let pushedAt = repository.pushedAt else { return "No recent activity" }
        return "Last push \(pushedAt.formatted(.relative(presentation: .named)))"
    }

    private var projectTint: Color {
        MissionTheme.scheduled
    }

    private var projectSymbol: String {
        "folder"
    }
}
