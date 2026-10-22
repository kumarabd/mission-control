import SwiftUI

struct MemoryView: View {
    var onSettings: () -> Void = {}
    var refreshToken = 0
    @Environment(Life.self) private var life
    @Environment(AuthService.self) private var auth
    @Environment(ChatModel.self) private var chat
    @Environment(\.scenePhase) private var scenePhase
    @State private var section: SemanticMemory.Section = .reflections
    @State private var query = ""
    @State private var model = MemoryModel()
    @State private var localRecords = false
    @State private var selectedID: String?
    @State private var selectedLens: SemanticMemory.Lens?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    /// A split view only while the list and detail both have room. At
    /// accessibility text sizes the iPad falls back to the phone's single column.
    private var usesSplit: Bool { sizeClass == .regular && !typeSize.isAccessibilitySize }

    private var service: MemoryService {
        #if DEBUG
        if Config.devEngine { return .devSample }
        #endif
        return MemoryService(baseURL: Config.routerBaseURL + "/brain", token: { [auth] in await auth.token() })
    }
    var body: some View {
        NavigationStack {
            Group {
                if usesSplit {
                    HStack(spacing: 0) {
                        memoryList.frame(width: 400)
                        Divider()
                        NavigationStack {
                            if let lens = selectedLens {
                                WorldLensDetail(lens: lens, service: service, initialItem: model.lensState(lens).item, onDiscuss: { discuss(lens) }).id(lens.id)
                            } else if let item = model.items.first(where: { $0.id == selectedID }) {
                                SemanticMemoryDetail(item: item, service: service, onDiscuss: { discuss(item) }).id(item.id)
                            } else {
                                ContentUnavailableView("Select a lens or insight", systemImage: "brain.head.profile", description: Text("The standing lenses and what your assistant remembers appear here."))
                            }
                        }
                    }
                } else {
                    memoryList.readableWidth()
                }
            }
            .screenBackground()
            .navigationTitle("Memory")
            .searchable(text: $query, prompt: "Search \(section.title.lowercased())")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AppMark() }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Discuss memory", systemImage: "bubble.left") { discuss() }.frame(minWidth: 44, minHeight: 44)
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
            }
            .navigationDestination(isPresented: $localRecords) { LocalMemoryRecords() }
            .refreshable {
                await reload()
                await model.loadLenses(service: service, force: true)
            }
            .task { await model.loadLenses(service: service) }
            .task(id: "\(section.rawValue):\(query):\(refreshToken)") {
                if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
                guard !Task.isCancelled else { return }; await reload()
            }
            .task(id: refreshToken) { if refreshToken > 0 { await model.loadLenses(service: service, force: true) } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await reload()
                        await model.loadLenses(service: service, force: true)
                    }
                }
            }
            .onChange(of: selectedID) { _, id in if id != nil { selectedLens = nil } }
        }
    }
    private var memoryList: some View {
        List(selection: $selectedID) {
            Section {
                ForEach(Array(SemanticMemory.Lens.allCases.enumerated()), id: \.element.id) { index, lens in
                    lensRow(lens, index: index)
                }
            } header: {
                SectionHeading("Your world", detail: "Kept current")
            } footer: {
                Text("Three standing views your assistant keeps up to date. They change as it learns more.")
                    .font(.mission(.footnote))
            }
            .listRowBackground(Tok.surface)
            Section {
                Picker("Memory view", selection: $section) {
                    ForEach(SemanticMemory.Section.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            if let failure = model.failure {
                Section {
                    Text(failure).font(.mission(.body)).foregroundStyle(Tok.muted)
                    Button("Try again") { Task { await reload() } }.frame(minHeight: 44)
                }.listRowBackground(Tok.surface)
            }
            if model.loading && model.items.isEmpty {
                Section { ProgressView("Loading memory…").frame(minHeight: 80).frame(maxWidth: .infinity) }.listRowBackground(Tok.surface)
            } else if model.loaded && model.items.isEmpty && model.failure == nil {
                Section {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(emptyTitle).font(.mission(.headline, .medium))
                        Text(query.isEmpty ? "Your assistant's remembered context and understanding will appear here as it develops." : "Try another word or clear your search.")
                            .font(.mission(.body)).foregroundStyle(Tok.muted)
                        if query.isEmpty { Button("Talk with your assistant") { discuss() }.frame(minHeight: 44) }
                    }.padding(.vertical, Space.s)
                }.listRowBackground(Tok.surface)
            }
            if !model.items.isEmpty {
                Section {
                    ForEach(model.items) { item in
                        if usesSplit { itemRow(item).tag(item.id) }
                        else { NavigationLink { SemanticMemoryDetail(item: item, service: service, onDiscuss: { discuss(item) }) } label: { itemRow(item) } }
                    }
                    if model.hasMore { Button(model.loading ? "Loading…" : "More insights") { Task { await reload(more: true) } }.frame(minHeight: 44).disabled(model.loading) }
                } footer: { Text("From your assistant's memory. Interpretations can change as more context is learned.").font(.mission(.footnote)) }
                .listRowBackground(Tok.surface)
            }
            if let retrievedAt = model.retrievedAt {
                Section { Text("Checked \(retrievedAt.formatted(date: .abbreviated, time: .shortened))").font(.mission(.caption)).foregroundStyle(Tok.muted) }.listRowBackground(Color.clear)
            }
            if !life.search("").isEmpty {
                Section { Button("Previously saved on this device") { localRecords = true }.frame(minHeight: 44) }.listRowBackground(Tok.surface)
            }
        }
        .scrollContentBackground(.hidden)
    }
    @ViewBuilder
    private func lensRow(_ lens: SemanticMemory.Lens, index: Int) -> some View {
        let row = WorldLensRow(lens: lens, state: model.lensState(lens), index: index, showsChevron: usesSplit)
        if usesSplit {
            Button {
                selectedID = nil
                selectedLens = lens
            } label: { row }
            .buttonStyle(MissionPressStyle())
            .listRowBackground(selectedLens == lens ? Tok.accent.opacity(0.08) : Tok.surface)
        } else {
            NavigationLink {
                WorldLensDetail(lens: lens, service: service, initialItem: model.lensState(lens).item, onDiscuss: { discuss(lens) })
            } label: { row }
        }
    }
    private func itemRow(_ item: SemanticMemory.Item) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(item.label).font(.missionMono(.caption)).foregroundStyle(Tok.accent)
            Text(item.title).font(.mission(.headline, .medium))
            if let content = item.content, !content.isEmpty { Text(content).font(.mission(.subheadline)).foregroundStyle(Tok.muted).lineLimit(3) }
            else { Text("No summary is available yet.").font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
            if let date = item.updatedAt { Text("Updated \(date.formatted(date: .abbreviated, time: .omitted))").font(.mission(.caption)).foregroundStyle(Tok.muted) }
        }.padding(.vertical, Space.s)
    }
    private var emptyTitle: String {
        if !query.isEmpty { return "No matching memory" }
        if !model.bankAvailable { return "Your memory isn't ready here yet" }
        return section == .reflections ? "Insights will take shape here" : "Your personal understanding is taking shape"
    }
    private func reload(more: Bool = false) async { await model.load(service: service, section: section, query: query, more: more) }
    /// Asking about memory starts the conversation in Chat, with the item's context in the box.
    private func discuss(_ item: SemanticMemory.Item? = nil) {
        let context = item.map { "About memory item \($0.id), ‘\($0.title)’: " } ?? "About what you remember and understand about me: "
        chat.request(draft: context)
    }
    private func discuss(_ lens: SemanticMemory.Lens) {
        chat.request(draft: "About what you remember and understand about my \(lens.title.lowercased()): ")
    }
}
private struct SemanticMemoryDetail: View {
    let item: SemanticMemory.Item
    var service: MemoryService
    var onDiscuss: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text(item.label).font(.missionMono(.caption)).foregroundStyle(Tok.accent)
                if let date = item.updatedAt { Text("Updated \(date.formatted(date: .abbreviated, time: .shortened))").font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
                SemanticItemBody(item: item, service: service, onDiscuss: onDiscuss)
            }.padding(Space.l).frame(maxWidth: 720).frame(maxWidth: .infinity, alignment: .leading)
        }.screenBackground().navigationTitle(item.title).navigationBarTitleDisplayMode(.inline)
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
