import SwiftUI

struct ProjectListView: View {
    let repositories: [GitHubRepository]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.headline)
            LazyVStack(spacing: 12) {
                ForEach(repositories) { repository in ProjectCardView(repository: repository) }
            }
        }
    }
}
