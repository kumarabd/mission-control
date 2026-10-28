import SwiftUI

/// The native half of the Living Atlas grammar. Shape says what kind of entity
/// it is, size says how connected it is, and the orbit marks a hub. It mirrors
/// the web's `worldGraphShapes.ts` / `worldGraphMarks.tsx` contract.
enum WorldMarkShape {
    case circle, diamond, hexagon, square, octagon, pentagon, dashed
}

enum WorldMarkKind {
    case organization, team, place, project, tool, event, person, concept, other
}

enum WorldMarks {
    static func kind(for type: String?) -> WorldMarkKind {
        guard let type else { return .other }
        let name = type.lowercased()
        if matches("organi[sz]ation|company|business", name) { return .organization }
        if matches("team|club|group", name) { return .team }
        if matches("place|location|city|country|island|venue|address|street", name) { return .place }
        if matches("project|initiative|session|conversation|thread", name) { return .project }
        if matches("tool|api|service|mcp|model|skill|library", name) { return .tool }
        if matches("event|meeting|match|fixture|appointment", name) { return .event }
        if matches("person|people|athlete|player|user|actor|author|contact", name) { return .person }
        if matches("concept|idea|theme|topic|goal|habit", name) { return .concept }
        return .other
    }

    static func shape(for type: String?) -> WorldMarkShape {
        switch kind(for: type) {
        case .organization, .team: .octagon
        case .place: .diamond
        case .project: .hexagon
        case .tool: .square
        case .event: .pentagon
        case .person: .circle
        case .concept: .dashed
        case .other: type == nil || type!.lowercased().contains("unknown") ? .dashed : .circle
        }
    }

    static func symbol(for kind: WorldMarkKind) -> String {
        switch kind {
        case .organization: "building.2"
        case .team: "person.3"
        case .place: "mappin"
        case .project: "square.stack.3d.up"
        case .tool: "wrench.and.screwdriver"
        case .event: "calendar"
        case .person: "person"
        case .concept: "sparkles"
        case .other: "circle.dotted"
        }
    }

    static func markSize(degree: Int) -> CGFloat {
        40 + CGFloat(min(degree, 10)) * 1.2
    }

    static func orbitSize(degree: Int) -> CGFloat {
        max(markSize(degree: degree) + 10, 56 + CGFloat(min(degree, 10)) * 0.6)
    }

    private static func matches(_ pattern: String, _ value: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

/// The seal silhouettes in a 48 × 48 drawing space, scaled into the mark.
struct WorldMarkPath: Shape {
    let shape: WorldMarkShape

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 48
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.midX + (x - 24) * scale, y: rect.midY + (y - 24) * scale)
        }
        func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
            var path = Path()
            let mapped = points.map { point($0.0, $0.1) }
            path.addLines(mapped)
            path.closeSubpath()
            return path
        }

        switch shape {
        case .circle, .dashed:
            return Path(ellipseIn: CGRect(x: rect.midX - 21 * scale, y: rect.midY - 21 * scale,
                                          width: 42 * scale, height: 42 * scale))
        case .square:
            return Path(roundedRect: CGRect(x: rect.midX - 19 * scale, y: rect.midY - 19 * scale,
                                            width: 38 * scale, height: 38 * scale),
                        cornerRadius: 9 * scale)
        case .diamond:
            return polygon([(24, 3), (45, 24), (24, 45), (3, 24)])
        case .hexagon:
            return polygon([(24, 3), (42, 13.5), (42, 34.5), (24, 45), (6, 34.5), (6, 13.5)])
        case .octagon:
            return polygon([(16, 4), (32, 4), (44, 16), (44, 32), (32, 44), (16, 44), (4, 32), (4, 16)])
        case .pentagon:
            return polygon([(24, 3), (45, 18), (37, 42), (11, 42), (3, 18)])
        }
    }
}

struct WorldMark: View {
    let type: String?
    let color: Color
    let degree: Int
    var selected = false
    var hovered = false
    var size: CGFloat?
    var showsIcon = true
    var showsDegree = true
    var showsOrbit = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var glyphSize: CGFloat { size ?? WorldMarks.markSize(degree: degree) }
    private var orbitDiameter: CGFloat { max(glyphSize + 10, WorldMarks.orbitSize(degree: degree)) }
    private var box: CGFloat { showsOrbit ? max(glyphSize, orbitDiameter) + 4 : glyphSize }
    private var shape: WorldMarkShape { WorldMarks.shape(for: type) }
    private var showsOrbitRing: Bool { showsOrbit && (selected || degree >= 4) }
    private var iconSize: CGFloat { max(13, (glyphSize * (shape == .diamond ? 0.31 : 0.36)).rounded()) }

    var body: some View {
        ZStack {
            if showsOrbitRing {
                if selected {
                    WorldOrbit(color: color, diameter: orbitDiameter)
                } else {
                    Circle()
                        .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(width: orbitDiameter, height: orbitDiameter)
                }
            }
            if selected && !reduceMotion {
                WorldBloom(color: color, diameter: orbitDiameter)
            }
            glyph
        }
        .frame(width: box, height: box)
        .accessibilityHidden(true)
    }

    private var glyph: some View {
        ZStack {
            WorldMarkPath(shape: shape)
                .fill(color.opacity(selected ? 0.2 : 0.1))
            WorldMarkPath(shape: shape)
                .stroke(color.opacity(selected ? 1 : 0.72),
                        style: StrokeStyle(lineWidth: selected ? 2 : 1.5,
                                           dash: shape == .dashed ? [4, 4] : []))
            if showsIcon {
                Image(systemName: WorldMarks.symbol(for: WorldMarks.kind(for: type)))
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .frame(width: glyphSize, height: glyphSize)
        .overlay(alignment: .topTrailing) {
            if showsDegree, degree > 0 {
                Text("\(degree)")
                    .font(.missionMono(.caption2))
                    .foregroundStyle(Tok.muted)
                    .padding(.horizontal, 3)
                    .frame(minWidth: 15, minHeight: 15)
                    .background(Tok.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Tok.hairline))
                    .offset(x: 4, y: -4)
            }
        }
        .scaleEffect(selected ? 1.05 : hovered ? 1.02 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8), value: selected)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
    }
}

/// The one authored moment: selecting an entity sends a satellite around its
/// orbit. It runs only while the mark is selected, and never under Reduce Motion.
private struct WorldOrbit: View {
    let color: Color
    let diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle = 0.0

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .stroke(color.opacity(0.95), style: StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .offset(y: -3)
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(angle))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WorldBloom: View {
    let color: Color
    let diameter: CGFloat
    @State private var bloom = false

    var body: some View {
        Circle()
            .stroke(color.opacity(bloom ? 0 : 0.5), lineWidth: 1.5)
            .frame(width: diameter, height: diameter)
            .scaleEffect(bloom ? 1.42 : 0.72)
            .onAppear {
                withAnimation(.easeOut(duration: 0.78)) { bloom = true }
            }
            .allowsHitTesting(false)
    }
}
