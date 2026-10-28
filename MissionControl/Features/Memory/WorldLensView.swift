import SwiftUI

/// The World lens: the person's entities, what is known about each, and how they relate, drawn as a diagram.
/// Everything shown is a projection from agent-brain's `/semantic/world`. Entity types and attribute names are
/// free text the assistant chose, so this view displays them and never switches on them.

// MARK: - Colour by type

/// One colour per type, assigned in alphabetical order so two types on screen never share one (up to six; after that
/// colours repeat). An entity with no type reads neutral.
struct WorldColors {
    private static let palette: [Color] = [Tok.accent, Tok.live, Tok.warn, Tok.critical, Tok.success, Tok.scheduled]
    let types: [String]
    init(graph: SemanticWorld.Graph) { types = Array(Set(graph.nodes.compactMap(\.typeName))).sorted() }
    func color(for type: String?) -> Color {
        guard let type, let index = types.firstIndex(of: type) else { return Tok.muted }
        return Self.palette[index % Self.palette.count]
    }
}

struct WorldNodeID: Identifiable, Hashable { let id: String }

// MARK: - Row in the Memory list

struct WorldRow: View {
    let state: MemoryModel.WorldState
    var showsChevron = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            MissionIconBadge(symbol: "point.3.connected.trianglepath.dotted", padding: 10)
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text("World").font(.mission(.headline, .medium)).layoutPriority(1)
                    Spacer(minLength: Space.s)
                    status.fixedSize()
                }
                Text("The people, places and things in your life, and how they connect.")
                    .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary { Text(summary).font(.mission(.footnote)).foregroundStyle(Tok.muted).lineLimit(2) }
            }
            if showsChevron {
                Image(systemName: "chevron.right").font(.mission(.footnote, .semibold)).foregroundStyle(Tok.muted).accessibilityHidden(true)
            }
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 8)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion { appeared = true } else { withAnimation(.easeOut(duration: 0.35)) { appeared = true } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("World. The people, places and things in your life, and how they connect. \(summary ?? accessibilityState)")
    }

    private var accessibilityState: String {
        switch state {
        case .loading: "Loading."
        case .empty: "Nothing here yet."
        case .failed: "Unavailable."
        default: ""
        }
    }

    @ViewBuilder private var status: some View {
        switch state {
        case .loading: ProgressView().controlSize(.mini)
        case .ready(let graph): Text("\(graph.nodes.count) \(graph.nodes.count == 1 ? "entity" : "entities")").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
        case .empty: Text("Forming").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
        case .failed: Text("Unavailable").font(.missionMono(.caption)).foregroundStyle(Tok.warn)
        case .idle: EmptyView()
        }
    }

    private var summary: String? {
        guard case .ready(let graph) = state else { return nil }
        let names = graph.nodes.prefix(3).map(\.label).joined(separator: ", ")
        let relations = graph.edges.count
        return "\(names)\(graph.nodes.count > 3 ? " and more" : ""). \(relations) \(relations == 1 ? "relation" : "relations")."
    }
}

// MARK: - Screen

private let worldUntypedKey = "__untyped__"

private struct WorldLegendType: Identifiable {
    let key: String
    let label: String
    let type: String?
    let color: Color
    let count: Int
    var id: String { key }
}

struct WorldScreen: View {
    var service: MemoryService
    var initial: MemoryModel.WorldState
    var onDiscuss: (String?) -> Void

    enum Mode: String, CaseIterable, Identifiable { case diagram = "Diagram", list = "List"; var id: String { rawValue } }

    @State private var state: MemoryModel.WorldState
    @State private var mode: Mode = .diagram
    @State private var selectedID: String?
    @State private var detail: WorldNodeID?
    @State private var hiddenTypes: Set<String> = []
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var usesLegendGrid: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    init(service: MemoryService, initial: MemoryModel.WorldState, onDiscuss: @escaping (String?) -> Void) {
        self.service = service; self.initial = initial; self.onDiscuss = onDiscuss
        _state = State(initialValue: initial.graph == nil ? .loading : initial)
    }

    var body: some View {
        Group {
            switch state {
            case .ready(let graph):
                content(graph)
            case .loading, .idle:
                ProgressView("Reading your world…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView {
                    Label("Your world is still forming", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text("As conversations mention people, places and things, your assistant builds a picture of each and how they connect. It appears here.")
                } actions: {
                    Button("Talk with your assistant", systemImage: "bubble.left") { onDiscuss(nil) }.frame(minHeight: 44)
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't load your world", systemImage: "wifi.exclamationmark")
                } description: { Text(message) } actions: {
                    Button("Try again") { Task { await load(force: true) } }.frame(minHeight: 44)
                }
            }
        }
        .screenBackground()
        .navigationTitle("World")
        .inlineNavigationTitle()
        .toolbar {
            if state.graph != nil {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $mode) { ForEach(Mode.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented).frame(maxWidth: 220)
                }
            }
        }
        .task { await load(force: false) }
        .refreshable { await load(force: true) }
    }

    @ViewBuilder private func content(_ graph: SemanticWorld.Graph) -> some View {
        let useList = mode == .list || typeSize.isAccessibilitySize
        let visible = visibleGraph(graph)
        let colors = WorldColors(graph: graph)
        VStack(spacing: 0) {
            legend(graph, visible: visible, colors: colors)
            if visible.nodes.isEmpty, !graph.nodes.isEmpty {
                ContentUnavailableView {
                    Label("No entities in this filter", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Show all types to see your world again.")
                } actions: {
                    Button("Show all") { resetTypes(graph) }.frame(minHeight: 44)
                }
            } else if useList {
                WorldList(graph: visible, colors: colors, onOpen: { detail = WorldNodeID(id: $0) })
            } else {
#if os(macOS)
                HStack(spacing: 0) {
                    WorldDiagram(graph: visible, colors: colors, selectedID: $selectedID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let id = selectedID, let node = visible.nodes.first(where: { $0.id == id }) {
                        WorldEntityCard(node: node, graph: visible, colors: colors, service: service, compact: false,
                                        onSelect: { selectedID = $0 }, onClose: { selectedID = nil },
                                        onDiscuss: { onDiscuss(node.label) })
                            .frame(width: 320)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .background(Tok.surface)
                            .overlay(alignment: .leading) { Divider() }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
#else
                WorldDiagram(graph: visible, colors: colors, selectedID: $selectedID)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if let id = selectedID, let node = visible.nodes.first(where: { $0.id == id }) {
                            WorldEntityCard(node: node, graph: visible, colors: colors, service: service, compact: true,
                                            onSelect: { selectedID = $0 }, onClose: { selectedID = nil },
                                            onDiscuss: { onDiscuss(node.label) })
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
#endif
            }
            if graph.truncated {
                Text("Showing the \(graph.nodes.count) best-connected. Others appear as they gain relations.")
                    .font(.mission(.footnote)).foregroundStyle(Tok.muted).padding(Space.s)
            }
        }
        .sheet(item: $detail) { ref in
            NavigationStack {
                ScrollView {
                    if let node = visible.nodes.first(where: { $0.id == ref.id }) {
                        WorldEntityCard(node: node, graph: visible, colors: colors, service: service, compact: false,
                                        onSelect: { detail = WorldNodeID(id: $0) }, onClose: { detail = nil },
                                        onDiscuss: { onDiscuss(node.label) })
                            .padding(Space.l)
                    }
                }
                .screenBackground().inlineNavigationTitle()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { detail = nil }.frame(minWidth: 44, minHeight: 44) } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func legend(_ graph: SemanticWorld.Graph, visible: SemanticWorld.Graph, colors: WorldColors) -> some View {
        let types = legendTypes(graph, colors: colors)
        return VStack(alignment: .leading, spacing: 4) {
            if usesLegendGrid {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 152), spacing: Space.s)], alignment: .leading, spacing: Space.s) {
                    ForEach(types) { item in
                        legendChip(item, graph: graph)
                    }
                    if !hiddenTypes.isEmpty { showAllButton(graph) }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(types) { item in
                            legendChip(item, graph: graph)
                        }
                        if !hiddenTypes.isEmpty { showAllButton(graph) }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.vertical, Space.s)
                }
            }
            Text(countLine(graph, visible: visible))
                .font(.missionMono(.caption))
                .foregroundStyle(Tok.muted)
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.s)
        }
    }

    @ViewBuilder private func legendChip(_ item: WorldLegendType, graph: SemanticWorld.Graph) -> some View {
        let hidden = hiddenTypes.contains(item.key)
        Button { toggleType(item.key, graph: graph) } label: {
            HStack(spacing: Space.xs) {
                WorldMark(
                    type: item.type,
                    color: item.color,
                    degree: 0,
                    size: 16,
                    showsIcon: false,
                    showsDegree: false,
                    showsOrbit: false
                )
                Text(item.label)
                    .font(.missionMono(.caption))
                    .foregroundStyle(hidden ? Tok.muted : Tok.text)
                    .lineLimit(1)
                Text("\(item.count)")
                    .font(.missionMono(.caption2))
                    .foregroundStyle(hidden ? Tok.muted : item.color)
                    .lineLimit(1)
            }
            .padding(.horizontal, Space.s)
            .padding(.vertical, 5)
            .background(hidden ? Tok.raised : item.color.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(hidden ? Tok.hairline : item.color.opacity(0.4)))
            .opacity(hidden ? 0.62 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.label), \(plural(item.count, "entity", "entities"))")
        .accessibilityValue(hidden ? "Hidden" : "Shown")
        .accessibilityAddTraits(hidden ? [] : .isSelected)
        .help(hidden ? "Show \(item.label)" : "Hide \(item.label)")
    }

    private func showAllButton(_ graph: SemanticWorld.Graph) -> some View {
        Button("Show all") { resetTypes(graph) }
            .font(.missionMono(.caption))
            .foregroundStyle(Tok.accent)
            .buttonStyle(.plain)
            .padding(.horizontal, Space.s)
            .frame(minHeight: 30)
    }

    private func legendTypes(_ graph: SemanticWorld.Graph, colors: WorldColors) -> [WorldLegendType] {
        let counts = Dictionary(grouping: graph.nodes, by: { typeKey($0) }).mapValues(\.count)
        var items = colors.types.map { type in
            WorldLegendType(key: type, label: type, type: type, color: colors.color(for: type), count: counts[type] ?? 0)
        }
        if let untyped = counts[worldUntypedKey] {
            items.append(WorldLegendType(key: worldUntypedKey, label: "no type", type: nil, color: Tok.muted, count: untyped))
        }
        return items
    }

    private func visibleGraph(_ graph: SemanticWorld.Graph) -> SemanticWorld.Graph {
        guard !hiddenTypes.isEmpty else { return graph }
        var visible = graph
        visible.nodes = graph.nodes.filter { !hiddenTypes.contains(typeKey($0)) }
        let ids = Set(visible.nodes.map(\.id))
        visible.edges = graph.edges.filter { ids.contains($0.from) && ids.contains($0.to) }
        return visible
    }

    private func typeKey(_ node: SemanticWorld.Node) -> String { node.typeName ?? worldUntypedKey }

    private func toggleType(_ key: String, graph: SemanticWorld.Graph) {
        if hiddenTypes.contains(key) { hiddenTypes.remove(key) } else { hiddenTypes.insert(key) }
        pruneSelection(graph)
    }

    private func resetTypes(_ graph: SemanticWorld.Graph) {
        hiddenTypes.removeAll()
        pruneSelection(graph)
    }

    private func pruneSelection(_ graph: SemanticWorld.Graph) {
        if let id = selectedID, let node = graph.nodes.first(where: { $0.id == id }), hiddenTypes.contains(typeKey(node)) {
            selectedID = nil
        }
        if let ref = detail, let node = graph.nodes.first(where: { $0.id == ref.id }), hiddenTypes.contains(typeKey(node)) {
            detail = nil
        }
    }

    private func countLine(_ graph: SemanticWorld.Graph, visible: SemanticWorld.Graph) -> String {
        let relations = plural(visible.edges.count, "relation", "relations")
        if hiddenTypes.isEmpty {
            return "\(plural(graph.nodes.count, "entity", "entities")) · \(relations)"
        }
        return "\(visible.nodes.count) of \(plural(graph.nodes.count, "entity", "entities")) · \(visible.edges.count) of \(plural(graph.edges.count, "relation", "relations"))"
    }

    private func plural(_ count: Int, _ one: String, _ many: String) -> String {
        "\(count) \(count == 1 ? one : many)"
    }

    private func load(force: Bool) async {
        let cached = state.graph
        if cached == nil { state = .loading }
        do {
            let graph = try await service.world()
            state = graph.bankAvailable && !graph.nodes.isEmpty ? .ready(graph) : .empty
        } catch {
            guard !Task.isCancelled else { if cached == nil { state = initial }; return }
            if cached == nil { state = .failed((error as? MemoryReadError)?.message ?? "Couldn't load your world.") }
        }
    }
}

// MARK: - Diagram

struct WorldDiagram: View {
    let graph: SemanticWorld.Graph
    let colors: WorldColors
    @Binding var selectedID: String?
    @State private var zoom: CGFloat = 0
    @State private var baseZoom: CGFloat = 1
    @State private var hoveredID: String?
    @State private var pressedID: String?
    @State private var dragID: String?
    @State private var dragWeights: [String: CGFloat] = [:]
    @State private var dragReleaseWeights: [String: CGFloat] = [:]
    @State private var dragOrigins: [String: CGSize] = [:]
    @State private var dragTranslation = CGSize.zero
    @State private var offsets: [String: CGSize] = [:]
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    private var focusID: String? { selectedID }

    /// The layout is computed once per graph and screen shape, not on every redraw.
    private final class LayoutCache { var key = ""; var result: WorldLayout.Result? }
    @State private var cache = LayoutCache()

    private func layout(for size: CGSize) -> WorldLayout.Result {
        // Lean the picture toward the screen: tall on a phone held upright, wide on an iPad.
        let aspect = min(1.6, max(0.6, size.height > 0 ? size.width / size.height : 1))
        let key = graph.nodes.map(\.id).joined(separator: ",") + "|" + graph.edges.map(\.id).joined(separator: ",") + "|\(Int(aspect * 10))"
        if cache.key == key, let result = cache.result { return result }
        let result = WorldLayout.layout(ids: graph.nodes.map(\.id), edges: graph.edges.map { ($0.from, $0.to) }, aspect: aspect)
        cache.key = key; cache.result = result
        return result
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = layout(for: proxy.size)
            // Fit to the width, but never smaller than is readable; the rest scrolls.
            let fit = min(1, max(0.6, proxy.size.width / max(layout.size.width, 1)))
            let scale = zoom == 0 ? fit : zoom
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Tok.graphCanvas
                    edgesLayer(layout: layout, offsets: offsets)
                    if let label = layout.isolatedLabel {
                        Text("not yet related").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                            .position(label)
                    }
                    ForEach(Array(graph.nodes.enumerated()), id: \.element.id) { index, node in
                        if let center = layout.centers[node.id] {
                            let dragging = dragID == node.id
                            let offset = offsets[node.id] ?? .zero
                            WorldNodeCard(
                                node: node,
                                color: colors.color(for: node.typeName),
                                relations: relationCount(node.id),
                                selected: selectedID == node.id,
                                hovered: hoveredID == node.id,
                                pressed: pressedID == node.id,
                                dragging: dragging,
                                neighbor: dragID != nil && dragWeights[node.id] != nil && !dragging,
                                dimmed: focusID != nil && !isNear(node.id),
                                showsLabel: selectedID == node.id || hoveredID == node.id || pressedID == node.id || dragging
                            )
                            .onHover { hovering in
                                hoveredID = hovering ? node.id : (hoveredID == node.id ? nil : hoveredID)
                            }
                            .onLongPressGesture(minimumDuration: 0.12, maximumDistance: 12, pressing: { pressing in
                                if pressing {
                                    pressedID = node.id
                                } else if pressedID == node.id {
                                    pressedID = nil
                                }
                            }, perform: {})
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                                    .onChanged { value in
                                        if dragID != node.id { beginDrag(node.id) }
                                        updateDrag(value.translation, scale: scale)
                                    }
                                    .onEnded { _ in endDrag() }
                            )
                            .onTapGesture {
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                                    selectedID = selectedID == node.id ? nil : node.id
                                }
                            }
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.96)
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(min(index, 8)) * 0.015),
                                value: appeared
                            )
                            .position(x: center.x + offset.width, y: center.y + offset.height)
                            .zIndex(dragging ? 10 : 0)
                        }
                    }
                }
                .frame(width: layout.size.width, height: layout.size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: layout.size.width * scale, height: layout.size.height * scale, alignment: .topLeading)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: focusID)
                .onAppear {
                    guard !appeared else { return }
                    if reduceMotion { appeared = true } else { withAnimation(.easeOut(duration: 0.35)) { appeared = true } }
                }
            }
            // A large world is wider than the panel: open on the middle of the
            // picture rather than its empty top-left corner.
            .defaultScrollAnchor(.center)
            .simultaneousGesture(MagnifyGesture().onChanged { zoom = min(2.2, max(0.35, baseZoom * $0.magnification)) }.onEnded { _ in baseZoom = zoom })
            .overlay(alignment: .topTrailing) { zoomControls(fit: fit, scale: scale) }
            .onChange(of: fit) { _, _ in if zoom == 0 { baseZoom = 1 } }
        }
    }

    private func beginDrag(_ id: String) {
        guard dragID != id else { return }
        var drag: [String: CGFloat] = [id: 1]
        var release: [String: CGFloat] = [id: 1]
        var direct = Set<String>()
        for edge in graph.edges {
            if edge.from == id { direct.insert(edge.to) }
            if edge.to == id { direct.insert(edge.from) }
        }
        direct.remove(id)
        for neighbor in direct {
            drag[neighbor] = 0.6
            release[neighbor] = 1
        }
        var second = Set<String>()
        for neighbor in direct {
            for edge in graph.edges where edge.from == neighbor || edge.to == neighbor {
                let other = edge.from == neighbor ? edge.to : edge.from
                if other != id, !direct.contains(other) { second.insert(other) }
            }
        }
        for other in second.sorted() where drag.count < 40 {
            drag[other] = 0.28
            release[other] = 0.6
        }
        dragWeights = drag
        dragReleaseWeights = release
        dragOrigins = drag.keys.reduce(into: [:]) { origins, nodeID in
            origins[nodeID] = offsets[nodeID] ?? .zero
        }
        dragID = id
        dragTranslation = .zero
        pressedID = nil
    }

    private func updateDrag(_ translation: CGSize, scale: CGFloat) {
        guard scale > 0 else { return }
        dragTranslation = CGSize(width: translation.width / scale, height: translation.height / scale)
        var next = offsets
        for (nodeID, weight) in dragWeights {
            let origin = dragOrigins[nodeID] ?? .zero
            next[nodeID] = CGSize(
                width: origin.width + dragTranslation.width * weight,
                height: origin.height + dragTranslation.height * weight
            )
        }
        offsets = next
    }

    private func endDrag() {
        guard let id = dragID else { return }
        let translation = dragTranslation
        let releaseWeights = dragReleaseWeights
        let origins = dragOrigins
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72)) {
            var next = offsets
            for (nodeID, weight) in releaseWeights {
                let origin = origins[nodeID] ?? .zero
                next[nodeID] = CGSize(
                    width: origin.width + translation.width * weight,
                    height: origin.height + translation.height * weight
                )
            }
            offsets = next
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            guard dragID == id else { return }
            dragID = nil
            dragWeights = [:]
            dragReleaseWeights = [:]
            dragOrigins = [:]
        }
    }

    private func zoomControls(fit: CGFloat, scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Button { setZoom(scale * 1.25) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                .accessibilityLabel("Zoom in")
            Divider().frame(width: 28)
            Button { setZoom(scale / 1.25) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                .accessibilityLabel("Zoom out")
            Divider().frame(width: 28)
            Button { zoom = 0; baseZoom = 1 } label: { Image(systemName: "arrow.up.left.and.down.right.magnifyingglass").frame(width: 44, height: 44) }
                .accessibilityLabel("Fit to screen")
        }
        .foregroundStyle(Tok.accent)
        .background(Tok.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Tok.hairline) }
        .padding(Space.s)
    }

    private func setZoom(_ value: CGFloat) { zoom = min(2.2, max(0.35, value)); baseZoom = zoom }

    private func relationCount(_ id: String) -> Int { graph.edges.filter { $0.from == id || $0.to == id }.count }

    /// The focused node and the nodes it is related to stay bright; the rest recede.
    private func isNear(_ id: String) -> Bool {
        guard let focused = focusID else { return true }
        return id == focused || graph.edges.contains { ($0.from == focused && $0.to == id) || ($0.to == focused && $0.from == id) }
    }

    private func edgesLayer(layout: WorldLayout.Result, offsets: [String: CGSize]) -> some View {
        Canvas { context, _ in
            func shifted(_ id: String) -> CGPoint? {
                guard let center = layout.centers[id] else { return nil }
                let offset = offsets[id] ?? .zero
                return CGPoint(x: center.x + offset.width, y: center.y + offset.height)
            }
            let focus = dragID ?? focusID
            let half = CGSize(width: WorldLayout.nodeSize.width / 2 + 3, height: WorldLayout.nodeSize.height / 2 + 3)
            // A hub's dozen relation labels would pile up; the entity panel
            // already lists every relation, so label only readable fan-outs.
            let focusRelations = focus.map { id in
                graph.edges.filter { $0.from == id || $0.to == id }.count
            } ?? 0
            let labelsFit = focusRelations <= 10
            var perPair: [String: Int] = [:]
            var totals: [String: Int] = [:]
            for edge in graph.edges { totals[pairKey(edge), default: 0] += 1 }
            for edge in graph.edges {
                guard let a = shifted(edge.from), let b = shifted(edge.to), a != b else { continue }
                let key = pairKey(edge)
                let i = perPair[key, default: 0]; perPair[key] = i + 1
                let incident = focus == nil || edge.from == focus || edge.to == focus
                let active = focus != nil && incident
                let color = active ? Tok.accent : Tok.hairline
                let opacity: CGFloat = focus != nil && !incident ? 0.2 : active ? 1 : 0.75
                let start = border(a, toward: b, half: half), end = border(b, toward: a, half: half)
                let angle = atan2(end.y - start.y, end.x - start.x)
                let spread = CGFloat(totals[key, default: 1] - 1) / 2
                let control = CGPoint(
                    x: (start.x + end.x) / 2 - sin(angle) * (18 + (CGFloat(i) - spread) * 24),
                    y: (start.y + end.y) / 2 + cos(angle) * (18 + (CGFloat(i) - spread) * 24)
                )
                var line = Path(); line.move(to: start); line.addQuadCurve(to: end, control: control)
                context.stroke(line, with: .color(color.opacity(opacity)), lineWidth: active ? 2.2 : 1.2)

                // Arrowhead follows the curve's final tangent.
                let tangent = atan2(end.y - control.y, end.x - control.x)
                var head = Path()
                head.move(to: end)
                head.addLine(to: CGPoint(x: end.x - 10 * cos(tangent - 0.4), y: end.y - 10 * sin(tangent - 0.4)))
                head.addLine(to: CGPoint(x: end.x - 10 * cos(tangent + 0.4), y: end.y - 10 * sin(tangent + 0.4)))
                head.closeSubpath()
                context.fill(head, with: .color(color.opacity(opacity)))

                // Labels only for the focused entity: the whole graph stays uncluttered until asked.
                guard focus != nil, incident, labelsFit, dragID == nil else { continue }
                let mid = CGPoint(
                    x: 0.25 * start.x + 0.5 * control.x + 0.25 * end.x,
                    y: 0.25 * start.y + 0.5 * control.y + 0.25 * end.y
                )
                let text = context.resolve(Text(edge.phrase).font(.missionMono(.caption)).foregroundStyle(Tok.text))
                let size = text.measure(in: CGSize(width: 200, height: 30))
                let pill = CGRect(x: mid.x - size.width / 2 - 5, y: mid.y - size.height / 2 - 2, width: size.width + 10, height: size.height + 4)
                let pillPath = Path(roundedRect: pill, cornerRadius: 6)
                context.fill(pillPath, with: .color(Tok.surface.opacity(0.96)))
                context.stroke(pillPath, with: .color(Tok.hairline.opacity(0.75)), lineWidth: 1)
                context.draw(text, at: mid)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pairKey(_ edge: SemanticWorld.Edge) -> String { edge.from < edge.to ? edge.from + "|" + edge.to : edge.to + "|" + edge.from }

    /// Where the line from a card's centre toward another point leaves the card's rectangle.
    private func border(_ center: CGPoint, toward: CGPoint, half: CGSize) -> CGPoint {
        let dx = toward.x - center.x, dy = toward.y - center.y
        guard dx != 0 || dy != 0 else { return center }
        let scale = min(dx == 0 ? .infinity : half.width / abs(dx), dy == 0 ? .infinity : half.height / abs(dy))
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }
}

private struct WorldNodeCard: View {
    let node: SemanticWorld.Node
    let color: Color
    let relations: Int
    let selected: Bool
    let hovered: Bool
    let pressed: Bool
    let dragging: Bool
    let neighbor: Bool
    let dimmed: Bool
    var showsLabel = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 5) {
            WorldMark(
                type: node.typeName,
                color: color,
                degree: relations,
                selected: selected,
                hovered: hovered || dragging
            )
            .rotationEffect(.degrees(dragging ? -3 : 0))
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.76), value: dragging)
            Text(node.label)
                .font(.mission(.caption, .semibold))
                .foregroundStyle(Tok.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .frame(maxWidth: 128)
                .background(Tok.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selected || hovered || dragging ? color : Tok.hairline, lineWidth: 1)
                }
                .shadow(color: selected || dragging ? color.opacity(0.18) : .clear, radius: 8, y: 3)
                .opacity(showsLabel ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: showsLabel)
        }
        .frame(width: WorldLayout.nodeSize.width, height: WorldLayout.nodeSize.height)
        .scaleEffect(dragging ? 1.06 : neighbor ? 1.02 : pressed ? 1.03 : 1)
        .opacity(dimmed ? 0.42 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.label), \(node.typeName ?? "unknown type"), \(relations) \(relations == 1 ? "relation" : "relations")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78), value: dragging)
    }
}

// MARK: - List

struct WorldList: View {
    let graph: SemanticWorld.Graph
    let colors: WorldColors
    var onOpen: (String) -> Void

    var body: some View {
        let groups = Dictionary(grouping: graph.nodes) { $0.typeName ?? "Other" }
        List {
            ForEach(groups.keys.sorted(), id: \.self) { type in
                Section {
                    ForEach(groups[type] ?? []) { node in
                        Button { onOpen(node.id) } label: {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(node.label).font(.mission(.headline, .medium))
                                if !node.sortedAttributes.isEmpty {
                                    Text(node.sortedAttributes.prefix(3).map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                                        .font(.mission(.subheadline)).foregroundStyle(Tok.muted).lineLimit(2)
                                }
                                let count = graph.edges.filter { $0.from == node.id || $0.to == node.id }.count
                                if count > 0 { Text("\(count) \(count == 1 ? "relation" : "relations")").font(.missionMono(.caption)).foregroundStyle(Tok.muted) }
                            }
                            .padding(.vertical, Space.xs).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 44)
                    }
                } header: {
                    HStack(spacing: Space.xs) {
                        WorldMark(
                            type: type == "Other" ? nil : type,
                            color: colors.color(for: type == "Other" ? nil : type),
                            degree: 0,
                            size: 14,
                            showsIcon: false,
                            showsDegree: false,
                            showsOrbit: false
                        )
                        Text(type)
                    }
                }
                .listRowBackground(Tok.surface)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - One entity

struct WorldEntityCard: View {
    let node: SemanticWorld.Node
    let graph: SemanticWorld.Graph
    let colors: WorldColors
    var service: MemoryService
    var compact: Bool
    var onSelect: (String) -> Void
    var onClose: () -> Void
    var onDiscuss: () -> Void

    private var nodes: [String: SemanticWorld.Node] { Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) }) }

    var body: some View {
        let color = colors.color(for: node.typeName)
        let relationCount = graph.edges.filter { $0.from == node.id || $0.to == node.id }.count
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.s) {
                WorldMark(
                    type: node.typeName,
                    color: color,
                    degree: relationCount,
                    size: 30,
                    showsDegree: false,
                    showsOrbit: false
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.label).font(.mission(.title3, .semibold))
                    Text(node.typeName ?? "No type yet").font(.missionMono(.caption)).foregroundStyle(color)
                }
                Spacer()
                if compact {
                    Button { onClose() } label: { Image(systemName: "xmark.circle.fill").font(.mission(.title3)).foregroundStyle(Tok.muted).frame(width: 44, height: 44) }
                        .accessibilityLabel("Close")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    if node.sortedAttributes.isEmpty {
                        Text("Nothing is known about \(node.label) yet beyond its name.").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    } else {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            ForEach(node.sortedAttributes, id: \.key) { attribute in
                                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                                    Text(attribute.key).font(.missionMono(.caption)).foregroundStyle(Tok.muted).frame(minWidth: 72, alignment: .leading)
                                    Text(attribute.value).font(.mission(.subheadline))
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    relations
                    HStack(spacing: Space.l) {
                        NavigationLink {
                            EntityMemoryDetail(entity: SemanticMemory.Entity(id: node.entityID, name: node.label), service: service)
                        } label: { Label("What I remember", systemImage: "text.book.closed") }
                        Button(action: onDiscuss) { Label("Discuss", systemImage: "bubble.left") }
                    }
                    .font(.mission(.subheadline, .medium)).frame(minHeight: 44)
                }
            }
            .frame(maxHeight: compact ? 220 : .infinity)
        }
        .padding(Space.l)
        .background(Tok.surface)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder private var relations: some View {
        let mine = graph.edges.filter { $0.from == node.id || $0.to == node.id }
        if !mine.isEmpty {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("relations").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                ForEach(mine) { edge in
                    let outgoing = edge.from == node.id
                    let otherID = outgoing ? edge.to : edge.from
                    if let other = nodes[otherID] {
                        Button { onSelect(otherID) } label: {
                            HStack(spacing: Space.s) {
                                Text(outgoing ? "\(edge.phrase) →" : "← \(edge.phrase)").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                                Text(other.label).font(.mission(.subheadline, .medium))
                                if edge.sourceCount > 0 {
                                    Text("\(edge.sourceCount) \(edge.sourceCount == 1 ? "fact" : "facts")").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityLabel(outgoing ? "\(node.label) \(edge.phrase) \(other.label)" : "\(other.label) \(edge.phrase) \(node.label)")
                    }
                }
            }
        }
    }
}
