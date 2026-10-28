import SwiftUI

struct MemoryView: View {
    var onSettings: () -> Void = {}
    var refreshToken = 0
    @Environment(Life.self) private var life
    @Environment(AuthService.self) private var auth
    @Environment(ChatModel.self) private var chat
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = MemoryModel()
    @State private var localRecords = false
    @State private var selection: MemorySelection = .world
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The iPad gives the graph the full Memory surface; the World/About you
    /// lenses live in a compact picker instead of a 400 pt list column.
    /// Accessibility text sizes fall back to the phone's list.
    private var usesExpanded: Bool { sizeClass == .regular && !typeSize.isAccessibilitySize }

    private var service: MemoryService {
        #if DEBUG
        if Config.devEngine { return .devSample }
        #endif
        return MemoryService(baseURL: Config.routerBaseURL + "/brain", token: { [auth] in await auth.token() })
    }

    var body: some View {
        NavigationStack {
            Group {
                if usesExpanded {
                    VStack(spacing: 0) {
                        lensPicker
                        switch selection {
                        case .world:
                            WorldScreen(service: service, initial: model.world, onDiscuss: discussWorld)
                        case .aboutYou:
                            AboutYouComingSoon { discuss() }
                        }
                    }
                } else {
                    memoryList.readableWidth()
                }
            }
            .screenBackground()
            .navigationTitle("Memory")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AppMark() }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Discuss memory", systemImage: "bubble.left") { discuss() }.frame(minWidth: 44, minHeight: 44)
                    if usesExpanded && !life.search("").isEmpty {
                        Button("Saved on this device", systemImage: "internaldrive") { localRecords = true }
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
            }
            .navigationDestination(isPresented: $localRecords) { LocalMemoryRecords() }
            .refreshable { await model.loadWorld(service: service, force: true) }
            .task { await model.loadWorld(service: service) }
            .task(id: refreshToken) { if refreshToken > 0 { await model.loadWorld(service: service, force: true) } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.loadWorld(service: service, force: true) } }
            }
        }
    }

    private var lensPicker: some View {
        Picker("Memory lens", selection: $selection) {
            ForEach(MemorySelection.allCases) { lens in
                Text(lens.title).tag(lens)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memoryList: some View {
        List {
            Section {
                worldRow
            } header: {
                SectionHeading("Your world", detail: "Kept current")
            } footer: {
                Text("The people, places and things your assistant knows about, and how they connect. It changes as it learns more.")
                    .font(.mission(.footnote))
            }
            .listRowBackground(Tok.surface)

            Section {
                aboutYouRow
            } header: {
                SectionHeading("More")
            }
            .listRowBackground(Tok.surface)

            if !life.search("").isEmpty {
                Section { Button("Previously saved on this device") { localRecords = true }.frame(minHeight: 44) }.listRowBackground(Tok.surface)
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var worldRow: some View {
        NavigationLink {
            WorldScreen(service: service, initial: model.world, onDiscuss: discussWorld)
        } label: {
            WorldRow(state: model.world, showsChevron: false)
        }
    }

    @ViewBuilder
    private var aboutYouRow: some View {
        let row = HStack(alignment: .top, spacing: Space.m) {
            MissionIconBadge(symbol: "person.text.rectangle", padding: 10)
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text("About you").font(.mission(.headline, .medium))
                    Spacer(minLength: Space.s)
                    Text("Coming soon").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                }
                Text("Who you are, what you know and how you like to work.")
                    .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
            }
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
        NavigationLink {
            AboutYouComingSoon { discuss() }
        } label: { row }
    }

    /// Asking about memory starts the conversation in Chat.
    private func discuss() {
        chat.request(draft: "About what you remember and understand about me: ")
    }
    private func discussWorld(_ entity: String?) {
        chat.request(draft: entity.map { "About \($0) in my world: " } ?? "About the people, places and things in my world: ")
    }
}

private enum MemorySelection: String, CaseIterable, Identifiable {
    case world, aboutYou

    var id: String { rawValue }
    var title: String {
        switch self {
        case .world: "World"
        case .aboutYou: "About you"
        }
    }
}

private struct AboutYouComingSoon: View {
    var onDiscuss: () -> Void

    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(Tok.accent.opacity(0.8))
                .accessibilityHidden(true)
            Text("About you is coming soon").font(.mission(.title3, .medium))
            Text("When it is ready, your assistant's understanding of who you are and how you like to work will appear here. Until then, ask it directly in Chat.")
                .font(.mission(.body)).foregroundStyle(Tok.muted)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            Button("Talk with your assistant", action: onDiscuss).frame(minHeight: 44)
        }
        .padding(Space.xl).frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .navigationTitle("About you").navigationBarTitleDisplayMode(.inline)
    }
}
struct EntityMemoryDetail: View {
    var entity: SemanticMemory.Entity
    var service: MemoryService
    @State private var page: EntityMemory.Page?
    @State private var failure: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let page {
                    if page.items.isEmpty {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("Nothing remembered yet").font(.mission(.headline, .medium))
                            Text("Your assistant hasn't connected \(entity.name) to anything else yet.")
                                .font(.mission(.body)).foregroundStyle(Tok.muted)
                        }
                    } else {
                        ForEach(page.items) { item in
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(item.label).font(.missionMono(.caption)).foregroundStyle(Tok.accent)
                                Text(item.text).font(.mission(.body))
                                Text(item.mentionTime.formatted(date: .abbreviated, time: .omitted))
                                    .font(.mission(.caption)).foregroundStyle(Tok.muted)
                            }.accessibilityElement(children: .combine)
                        }
                        if page.hasMore {
                            Text("Showing the most recent memory connected to \(entity.name).")
                                .font(.mission(.footnote)).foregroundStyle(Tok.muted)
                        }
                    }
                } else if let failure {
                    Text(failure).font(.mission(.body))
                    Button("Try again") { Task { await load() } }.frame(minHeight: 44)
                } else {
                    ProgressView("Loading related memory…")
                }
            }.padding(Space.l).frame(maxWidth: 720).frame(maxWidth: .infinity, alignment: .leading)
        }.screenBackground().navigationTitle(entity.name).navigationBarTitleDisplayMode(.inline).task { await load() }
    }
    private func load() async {
        failure = nil
        do { page = try await service.entityFacts(entityID: entity.id) }
        catch { if !Task.isCancelled { failure = (error as? MemoryReadError)?.message ?? "Couldn't load related memory." } }
    }
}
private struct LocalMemoryRecords: View {
    @Environment(Life.self) private var life
    var body: some View {
        List {
            ForEach(life.search("")) { item in
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(item.text).font(.mission(.body))
                    if let reason = item.reason { Text(reason).font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
                    Text(item.date.formatted(date: .abbreviated, time: .omitted)).font(.mission(.caption)).foregroundStyle(Tok.muted)
                }
            }.listRowBackground(Tok.surface)
        }.scrollContentBackground(.hidden).screenBackground().navigationTitle("Saved on this device")
    }
}

struct SemanticSourceDetail: View {
    var parent: String
    var source: SemanticMemory.Source
    var service: MemoryService
    @State private var item: SemanticMemory.Item?
    @State private var failure: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let item {
                    if let date = item.updatedAt { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.mission(.caption)).foregroundStyle(Tok.muted) }
                    if let content = item.content { MarkdownView(text: content) }
                    else { Text("No readable content is available.") }
                    if item.truncated { Text("This is a shortened view.").font(.mission(.footnote)).foregroundStyle(Tok.muted) }
                } else if let failure {
                    Text(failure).font(.mission(.body))
                    Button("Try again") { Task { await load() } }.frame(minHeight: 44)
                } else { ProgressView("Loading supporting memory…") }
            }.padding(Space.l).frame(maxWidth: .infinity, alignment: .leading)
        }.screenBackground().navigationTitle(source.title).navigationBarTitleDisplayMode(.inline).task { await load() }
    }
    private func load() async {
        failure = nil
        do { item = try await service.source(parent: parent, id: source.id) }
        catch { if !Task.isCancelled { failure = (error as? MemoryReadError)?.message ?? "Couldn't load this source." } }
    }
}
