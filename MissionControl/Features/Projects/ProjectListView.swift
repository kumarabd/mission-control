import SwiftUI

struct ProjectListView: View {
    let repositories: [GitHubRepository]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Projects", detail: "\(repositories.count) active")
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(repositories) { repository in ProjectCardView(repository: repository) }
            }
        }
    }

    private var columns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]
    }
}
