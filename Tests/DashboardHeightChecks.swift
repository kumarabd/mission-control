import Foundation

@main
struct DashboardHeightChecks {
    static func main() {
        func check(_ natural: [CGFloat], viewport: CGFloat, spacing: CGFloat = 0,
                   expanding: [Int], expected: [CGFloat], _ name: String) {
            let actual = DashboardHeightAllocation.heights(natural, minimumHeight: viewport,
                                                          spacing: spacing, expanding: expanding)
            precondition(actual.count == expected.count, name)
            precondition(zip(actual, expected).allSatisfy { abs($0 - $1) < 0.001 }, "\(name): \(actual)")
            precondition(zip(actual, natural).allSatisfy { $0 >= $1 }, "Must not shrink content: \(name)")
        }

        check([160, 300, 44], viewport: 800, spacing: 10, expanding: [1],
              expected: [160, 576, 44], "Only timeline absorbs remaining screen")
        check([46, 62, 62, 62, 56], viewport: 576, expanding: [1, 2, 3],
              expected: [46, 158, 158, 158, 56], "Sparse lanes reach bottom, header stays compact")
        check([46, 62, 62, 62, 62, 62, 56], viewport: 460, expanding: [1, 2, 3, 4, 5],
              expected: [46, 71.6, 71.6, 71.6, 71.6, 71.6, 56], "More lanes tighten spacing")
        check([46, 62, 62, 62, 56], viewport: 288, expanding: [1, 2, 3],
              expected: [46, 62, 62, 62, 56], "Exact fit")
        check([46, 62, 62, 62, 56], viewport: 240, expanding: [1, 2, 3],
              expected: [46, 62, 62, 62, 56], "Short landscape screen overflows naturally")
        check([80, 180, 120, 140, 260], viewport: 600, expanding: [1, 2, 3],
              expected: [80, 180, 120, 140, 260], "Large type and expanded completed keep full height")
        let many = Array(repeating: CGFloat(62), count: 100)
        check(many, viewport: 800, expanding: Array(0..<99), expected: many, "No item cap")
        check([], viewport: 800, expanding: [], expected: [], "Empty layout")
        check([56], viewport: 100, expanding: [0, 0, -1, 2], expected: [100], "Safe expansion indices")
        print("Dashboard height checks passed (9 scenarios).")
    }
}
