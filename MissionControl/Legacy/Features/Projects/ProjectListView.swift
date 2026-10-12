import SwiftUI

struct ProjectListView: View {
    let repositories: [GitHubRepository]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Projects", detail: "\(repositories.count) repositories")
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(repositories) { repository in ProjectCardView(repository: repository) }
            }
        }
    }

    private var columns: [GridItem] {
        horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom != .phone && !typeSize.isAccessibilitySize
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]
    }
}
