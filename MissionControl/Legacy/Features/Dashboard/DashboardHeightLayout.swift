import SwiftUI

/// Distributes spare height without ever compressing text or touch targets.
enum DashboardHeightAllocation {
    static func heights(_ natural: [CGFloat], minimumHeight: CGFloat, spacing: CGFloat,
                        expanding indices: [Int]) -> [CGFloat] {
        let eligible = Set(indices.filter { natural.indices.contains($0) })
        guard !eligible.isEmpty else { return natural }
        let total = natural.reduce(0, +) + spacing * CGFloat(max(0, natural.count - 1))
        let extra = max(0, minimumHeight - total) / CGFloat(eligible.count)
        return natural.enumerated().map { index, height in
            height + (eligible.contains(index) ? extra : 0)
        }
    }
}

struct DashboardExpandsVertically: LayoutValueKey {
    static let defaultValue = false
}

/// The dashboard gives spare viewport height to the timeline. The timeline uses
/// the same layout to share that space between its lanes, extending their rails.
/// Overflow retains its intrinsic height and is handled by the outer ScrollView.
struct DashboardHeightLayout: Layout {
    var minimumHeight: CGFloat = 0
    var spacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
            ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let heights = allocatedHeights(width: width, height: proposal.height, subviews: subviews)
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let heights = allocatedHeights(width: bounds.width, height: bounds.height, subviews: subviews)
        var y = bounds.minY
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                       proposal: ProposedViewSize(width: bounds.width, height: heights[index]))
            y += heights[index] + spacing
        }
    }

    private func allocatedHeights(width: CGFloat, height: CGFloat?, subviews: Subviews) -> [CGFloat] {
        let natural = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        let expanding = subviews.indices.filter { subviews[$0][DashboardExpandsVertically.self] }
        let available = height.flatMap { $0.isFinite ? $0 : nil } ?? 0
        return DashboardHeightAllocation.heights(natural, minimumHeight: max(minimumHeight, available),
                                                spacing: spacing, expanding: expanding)
    }
}
