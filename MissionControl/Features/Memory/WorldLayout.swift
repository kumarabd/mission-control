import CoreGraphics
import ForceGraph
import Foundation

/// Places the world's entities on a canvas. Foundation-only and deterministic: the same entities and relations
/// always land in the same places, so the picture does not shuffle on every refresh.
///
/// Entities that have relations are placed by a force simulation (related ones pull together, all repel). Entities
/// with no relation yet are laid out in a tidy grid underneath, so a long list of unrelated things never crowds the
/// connected part.
enum WorldLayout {
    static let nodeSize = CGSize(width: 140, height: 92)
    static let margin: CGFloat = 40

    struct Result: Equatable {
        /// Node centres, keyed by node id.
        var centers: [String: CGPoint]
        /// The canvas the centres fit in, including margins.
        var size: CGSize
        /// Where the grid of unrelated entities begins, or nil when there are none.
        var isolatedTop: CGFloat?
        /// Where the "not yet related" label belongs, or nil when there are no unrelated entities.
        var isolatedLabel: CGPoint?
    }

    /// - Parameters:
    ///   - ids: node ids, best connected first (the order the server returns them in).
    ///   - edges: (from, to) pairs. Pairs naming an unknown id, and self-loops, are ignored; repeats count once.
    ///   - aspect: the width to height the connected part should lean toward (1 is square; a phone held upright wants less, a
    ///     wide panel more). It shapes the picture; it never causes overlap.
    static func layout(ids: [String], edges: [(String, String)], aspect: CGFloat = 1) -> Result {
        let known = Set(ids)
        var seen = Set<String>()
        var pairs: [(Int, Int)] = []
        let index = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        for (a, b) in edges where a != b && known.contains(a) && known.contains(b) {
            let key = a < b ? a + "\u{1}" + b : b + "\u{1}" + a
            if seen.insert(key).inserted { pairs.append((index[a]!, index[b]!)) }
        }
        var degree = [Int](repeating: 0, count: ids.count)
        for (a, b) in pairs { degree[a] += 1; degree[b] += 1 }
        let connected = ids.indices.filter { degree[$0] > 0 }
        let isolated = ids.indices.filter { degree[$0] == 0 }

        var centers: [String: CGPoint] = [:]
        var width: CGFloat = 0, height: CGFloat = 0
        if !connected.isEmpty {
            let points = simulate(count: connected.count, pairs: pairs, local: Dictionary(uniqueKeysWithValues: connected.enumerated().map { ($1, $0) }), aspect: max(0.3, aspect))
            for (i, node) in connected.enumerated() { centers[ids[node]] = points[i] }
            let xs = points.map(\.x), ys = points.map(\.y)
            let half = CGSize(width: nodeSize.width / 2, height: nodeSize.height / 2)
            let minX = (xs.min() ?? 0) - half.width, minY = (ys.min() ?? 0) - half.height
            for key in centers.keys { centers[key]!.x += margin - minX; centers[key]!.y += margin - minY }
            width = (xs.max() ?? 0) + half.width - minX + 2 * margin
            height = (ys.max() ?? 0) + half.height - minY + 2 * margin
        }

        var isolatedTop: CGFloat?
        var isolatedLabel: CGPoint?
        if !isolated.isEmpty {
            let gap: CGFloat = 20
            let canvasWidth = max(width, 3 * nodeSize.width + 2 * gap + 2 * margin)
            let columns = max(1, Int((canvasWidth - 2 * margin + gap) / (nodeSize.width + gap)))
            let top = connected.isEmpty ? margin : height
            isolatedTop = top
            isolatedLabel = CGPoint(x: margin + 56, y: top + 10)
            let startY = top + 28 // room for the "not yet related" label
            for (i, node) in isolated.enumerated() {
                let row = i / columns, column = i % columns
                centers[ids[node]] = CGPoint(
                    x: margin + nodeSize.width / 2 + CGFloat(column) * (nodeSize.width + gap),
                    y: startY + nodeSize.height / 2 + CGFloat(row) * (nodeSize.height + gap)
                )
            }
            let rows = (isolated.count + columns - 1) / columns
            width = canvasWidth
            height = startY + CGFloat(rows) * (nodeSize.height + gap) - gap + margin
        }
        // Center the picture on the busiest neighbourhood, not the middle of
        // the bounding box: one far-flung outlier otherwise pushes the opening
        // viewport into an empty corner of a large world.
        if !centers.isEmpty {
            let points = Array(centers.values)
            var anchorIndex = connected.first
            for index in connected.dropFirst() where degree[index] > degree[anchorIndex!] {
                anchorIndex = index
            }
            let anchorID = anchorIndex.map { ids[$0] } ?? ids.first
            let anchor = anchorID.flatMap { centers[$0] } ?? .zero
            let halfWidth = (points.map { abs($0.x - anchor.x) }.max() ?? 0) + nodeSize.width / 2 + margin
            let halfHeight = (points.map { abs($0.y - anchor.y) }.max() ?? 0) + nodeSize.height / 2 + margin
            let dx = halfWidth - anchor.x, dy = halfHeight - anchor.y
            for key in centers.keys {
                centers[key]!.x += dx
                centers[key]!.y += dy
            }
            if isolatedTop != nil { isolatedTop! += dy }
            if isolatedLabel != nil {
                isolatedLabel!.x += dx
                isolatedLabel!.y += dy
            }
            width = halfWidth * 2
            height = halfHeight * 2
        }
        return Result(centers: centers, size: CGSize(width: max(width, 1), height: max(height, 1)),
                      isolatedTop: isolatedTop, isolatedLabel: isolatedLabel)
    }

    /// ForceGraph's deterministic Fruchterman–Reingold layout, then a few passes that push overlapping cards apart.
    private static func simulate(count n: Int, pairs: [(Int, Int)], local: [Int: Int], aspect: CGFloat) -> [CGPoint] {
        let ids = (0..<n).map(String.init)
        let graphEdges = pairs.compactMap { a, b -> GraphEdge<String>? in
            guard let la = local[a], let lb = local[b] else { return nil }
            return GraphEdge(ids[la], ids[lb])
        }
        let side = max(360, CGFloat(Double(n).squareRoot().rounded(.up)) * 110)
        let layout = ForceLayout(
            nodes: ids,
            edges: graphEdges,
            configuration: ForceLayoutConfiguration(
                iterations: 360,
                area: Double(side * side),
                gravity: 1.0,
                seed: 0x5EED
            )
        )
        let placed = layout.run()
        var position = (0..<n).map { i -> CGPoint in
            let point = placed[ids[i]] ?? .zero
            // ForceGraph is isotropic; lean the result toward the panel's shape.
            return CGPoint(x: point.x * aspect, y: point.y)
        }
        // Cards are rectangles, not points: separate any that still overlap along the shallower axis.
        let gapX: CGFloat = 16, gapY: CGFloat = 18
        for _ in 0..<40 {
            var moved = false
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let dx = position[j].x - position[i].x, dy = position[j].y - position[i].y
                    let overlapX = nodeSize.width + gapX - abs(dx), overlapY = nodeSize.height + gapY - abs(dy)
                    guard overlapX > 0, overlapY > 0 else { continue }
                    moved = true
                    if overlapX < overlapY {
                        let push = overlapX / 2 * (dx >= 0 ? 1 : -1)
                        position[i].x -= push; position[j].x += push
                    } else {
                        let push = overlapY / 2 * (dy >= 0 ? 1 : -1)
                        position[i].y -= push; position[j].y += push
                    }
                }
            }
            if !moved { break }
        }
        return position
    }
}
