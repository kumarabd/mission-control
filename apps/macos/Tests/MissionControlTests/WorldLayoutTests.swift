import CoreGraphics
import XCTest
@testable import MissionControl

final class WorldLayoutTests: XCTestCase {
    func testEveryNodeIsPlacedInsideTheCanvasWithoutOverlap() {
        let ids = (0..<12).map { "e\($0)" }
        let edges = [("e0", "e1"), ("e0", "e2"), ("e1", "e3"), ("e4", "e5"), ("e5", "e6"), ("e6", "e4"), ("e7", "e0")]
        let result = WorldLayout.layout(ids: ids, edges: edges)
        XCTAssertEqual(result.centers.count, ids.count)

        let size = WorldLayout.nodeSize
        for (id, center) in result.centers {
            XCTAssertGreaterThanOrEqual(center.x - size.width / 2, 0, "\(id) outside horizontally")
            XCTAssertLessThanOrEqual(center.x + size.width / 2, result.size.width, "\(id) outside horizontally")
            XCTAssertGreaterThanOrEqual(center.y - size.height / 2, 0, "\(id) outside vertically")
            XCTAssertLessThanOrEqual(center.y + size.height / 2, result.size.height, "\(id) outside vertically")
        }

        let placed = Array(result.centers)
        for i in placed.indices {
            for j in placed.indices where j > i {
                let dx = abs(placed[i].value.x - placed[j].value.x)
                let dy = abs(placed[i].value.y - placed[j].value.y)
                XCTAssertTrue(dx >= size.width - 0.5 || dy >= size.height - 0.5,
                              "\(placed[i].key) overlaps \(placed[j].key)")
            }
        }
    }

    func testOpensOnTheMostConnectedEntity() {
        let ids = ["hub"] + (0..<8).map { "n\($0)" }
        let edges = (0..<8).map { ("hub", "n\($0)") }
        let result = WorldLayout.layout(ids: ids, edges: edges)
        let hub = try! XCTUnwrap(result.centers["hub"])
        XCTAssertEqual(hub.x, result.size.width / 2, accuracy: 0.5)
        XCTAssertEqual(hub.y, result.size.height / 2, accuracy: 0.5)
    }

    func testUnrelatedEntitiesSitBelowTheConnectedPart() {
        let ids = (0..<8).map { "e\($0)" }
        let result = WorldLayout.layout(ids: ids, edges: [("e0", "e1"), ("e1", "e2")])
        let top = try! XCTUnwrap(result.isolatedTop)
        XCTAssertNotNil(result.isolatedLabel)
        for id in ["e3", "e4", "e5", "e6", "e7"] {
            XCTAssertGreaterThan(result.centers[id]!.y, top)
        }
        for id in ["e0", "e1", "e2"] {
            XCTAssertLessThan(result.centers[id]!.y, top)
        }
    }

    func testDegenerateInputIsUsable() {
        XCTAssertTrue(WorldLayout.layout(ids: [], edges: []).centers.isEmpty)
        let one = WorldLayout.layout(ids: ["solo"], edges: [])
        XCTAssertNotNil(one.centers["solo"])
        XCTAssertGreaterThan(one.size.width, 0)
        XCTAssertGreaterThan(one.size.height, 0)

        let once = WorldLayout.layout(ids: ["a", "b"], edges: [("a", "b")])
        let thrice = WorldLayout.layout(ids: ["a", "b"], edges: [("a", "b"), ("b", "a"), ("a", "b")])
        XCTAssertEqual(once, thrice)
    }

    func testIsDeterministicAndShapedByAspect() {
        let ids = (0..<12).map { "e\($0)" }
        let edges = [("e0", "e1"), ("e0", "e2"), ("e1", "e3"), ("e4", "e5"), ("e5", "e6"), ("e6", "e4"), ("e7", "e0")]
        XCTAssertEqual(WorldLayout.layout(ids: ids, edges: edges), WorldLayout.layout(ids: ids, edges: edges))

        func shape(_ result: WorldLayout.Result) -> CGFloat {
            result.size.width / (result.isolatedTop ?? result.size.height)
        }
        let square = WorldLayout.layout(ids: ids, edges: edges, aspect: 1)
        let wide = WorldLayout.layout(ids: ids, edges: edges, aspect: 2)
        let tall = WorldLayout.layout(ids: ids, edges: edges, aspect: 0.6)
        XCTAssertGreaterThan(shape(wide), shape(square))
        XCTAssertLessThan(shape(tall), shape(square))
    }
}
