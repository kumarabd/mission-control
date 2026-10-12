import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The home is a quiet assistant presence. Detailed work lives in its six spaces.
struct AssistantHomeView: View {
    let tasks: [MissionTask]
    let focus: MissionTask?
    let compact: Bool
    let ambient: Bool
    let onOpen: (DashboardSpace) -> Void
    let onAdd: () -> Void
    let onSettings: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var voice = AssistantVoiceCoordinator()
    @AppStorage("missionShowConversationText") private var showsConversationText = true
    @AppStorage("missionHandsFreeEnabled") private var handsFreeEnabled = true
    @State private var showingCaptureOptions = false
    @State private var showingLiveScanner = false
    @State private var showingCamera = false
    @State private var showingAttachmentImporter = false
    @State private var workspaceExpanded = false
    private let spaces: [DashboardSpace] = [.tasks, .projects, .garage, .systems, .health, .pantry, .wardrobe]

    var body: some View {
        GeometryReader { geometry in
            if compact && !typeSize.isAccessibilitySize {
                mobileAssistantHome(in: geometry.size)
            } else {
                ScrollView {
                    DashboardHeightLayout(minimumHeight: geometry.size.height, spacing: 12) {
                        heading.padding(.horizontal, 20).padding(.top, 8)
                        constellation(width: geometry.size.width, compact: false)
                            .layoutValue(key: DashboardExpandsVertically.self, value: true)
                    }.frame(maxWidth: .infinity)
                }.scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(MissionTheme.canvas.ignoresSafeArea())
        .confirmationDialog("Add to the assistant", isPresented: $showingCaptureOptions, titleVisibility: .visible) {
            Button("Scan live text or QR code", systemImage: "viewfinder") { showingLiveScanner = true }
            Button("Take photo and read text", systemImage: "camera") { showingCamera = true }
            Button("Choose image or PDF", systemImage: "paperclip") { showingAttachmentImporter = true }
        }
        .sheet(isPresented: $showingLiveScanner) {
            AssistantLiveScanner { payload in voice.presentAttachmentPayload(payload) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            AssistantCameraCapture(isPresented: $showingCamera) { image in analyze(image: image, source: "Camera photo") }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showingAttachmentImporter, allowedContentTypes: [.image, .pdf]) { result in
            guard case let .success(url) = result else { return }
            analyze(url: url, source: "Attached \(url.lastPathComponent)")
        }
        .onDrop(of: [UTType.image.identifier, UTType.pdf.identifier], isTargeted: nil) { providers in
            guard let provider = providers.first,
                  let identifier = provider.registeredTypeIdentifiers.first(where: { identifier in
                      guard let type = UTType(identifier) else { return false }
                      return type.conforms(to: .image) || type.conforms(to: .pdf)
                  }), let type = UTType(identifier) else { return false }
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, _ in
                guard let data else { return }
                Task { @MainActor in analyze(data: data, type: type, source: "Dropped attachment") }
            }
            return true
        }
        .onAppear {
            voice.updateGatewayAppActivity(
                scenePhase == .active,
                handsFreeEnabled: handsFreeEnabled
            )
        }
        .onChange(of: scenePhase) { _, phase in
            // Permission sheets temporarily make the app inactive. An active
            // hands-free session continues through a real background transition.
            if phase != .inactive {
                voice.updateGatewayAppActivity(
                    phase == .active,
                    handsFreeEnabled: handsFreeEnabled
                )
            }
        }
        .onChange(of: handsFreeEnabled) { _, enabled in
            voice.updateGatewayAppActivity(scenePhase == .active, handsFreeEnabled: enabled)
        }
    }

    /// Phone home keeps the assistant as the primary surface. The workspace is
    /// deliberately reachable from the thumb zone instead of surrounding it.
    private func mobileAssistantHome(in size: CGSize) -> some View {
        let diameter = min(max(210, size.width * 0.70), min(330, size.height * 0.43))
        return VStack(spacing: 0) {
            heading.padding(.horizontal, 20).padding(.top, 8)
            Spacer(minLength: 12)
            VStack(spacing: 18) {
                AssistantPresence(ambient: ambient, diameter: diameter,
                                  voiceState: voice.state, onVoiceTap: voice.toggle,
                                  onCapture: { showingCaptureOptions = true },
                                  onAttach: { showingAttachmentImporter = true })
                briefing
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 24)
            }
            Spacer(minLength: 12)
            WorkspaceDrawer(spaces: spaces, isExpanded: $workspaceExpanded, onOpen: onOpen)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private var heading: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(alignment: .top, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center) {
                        clock(context.date)
                        Spacer(minLength: 20)
                        weather
                    }
                    VStack(alignment: .leading, spacing: 8) { clock(context.date); weather }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    showsConversationText.toggle()
                } label: {
                    Image(systemName: showsConversationText ? "eye" : "eye.slash")
                        .foregroundStyle(MissionTheme.quietText)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(showsConversationText ? "Hide spoken and response text" : "Show spoken and response text")
                .accessibilityHint("Keeps the assistant status visible")
                Menu {
                    Button("Add task", systemImage: "plus", action: onAdd)
                    Toggle("Hands-free continuation", isOn: $handsFreeEnabled)
                    Button("Appearance and motion", systemImage: "slider.horizontal.3", action: onSettings)
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(MissionTheme.quietText)
                        .frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Home controls")
            }
        }
    }

    private func clock(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(date, format: .dateTime.hour().minute())
                .font(.mission(compact ? .title : .largeTitle, .light)).monospacedDigit()
            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private var weather: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Label("21° · Clear", systemImage: "sun.max.fill")
                .font(.mission(.subheadline)).foregroundStyle(MissionTheme.attention)
            Text("Sample weather").font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
        }.fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sample weather, 21 degrees and clear. Weather is not connected.")
    }

    private func constellation(width: CGFloat, compact: Bool) -> some View {
        AssistantConstellationLayout(compact: compact) {
            VStack(spacing: 24) {
                AssistantPresence(ambient: ambient,
                                  diameter: compact ? min(180, width * 0.44) : min(340, width * 0.38),
                                  voiceState: voice.state, onVoiceTap: voice.toggle,
                                  onCapture: { showingCaptureOptions = true },
                                  onAttach: { showingAttachmentImporter = true })
                briefing
            }
            ForEach(spaces) { spaceButton($0) }
        }
    }

    private func spaceButton(_ space: DashboardSpace) -> some View {
        Button { onOpen(space) } label: {
            VStack(spacing: 7) {
                Image(systemName: space.symbol).font(.mission(.title2, .light))
                    .foregroundStyle(space.accent).padding(18)
                    .background(space.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 23))
                    .overlay { RoundedRectangle(cornerRadius: 23).strokeBorder(space.accent.opacity(0.30)) }
                    .overlay(alignment: .topTrailing) {
                        if space == .tasks {
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                let schedule = DayTaskSchedule(tasks: tasks, now: context.date)
                                let count = schedule.earlier.count + schedule.remainingToday.filter { $0.scheduledAt! < schedule.minuteEnd }.count
                                if count > 0 {
                                    Text(count > 99 ? "99+" : "\(count)")
                                        .font(.mission(.caption2, .semibold)).padding(5)
                                        .foregroundStyle(MissionTheme.actionInk)
                                        .background(MissionTheme.attention, in: Capsule())
                                        .accessibilityLabel("\(count) planned tasks need attention")
                                }
                            }
                        }
                    }
                Text(space.title).font(.mission(.caption, .medium)).foregroundStyle(MissionTheme.ink)
            }.frame(maxWidth: .infinity, minHeight: 80).contentShape(Rectangle())
        }.buttonStyle(MissionPressStyle()).accessibilityHint("Opens \(space == .tasks ? "your day timeline" : space.title)")
    }

    private var briefing: some View {
        Group {
            if voice.state == .idle && voice.message.isEmpty {
                scheduledBriefing
            } else {
                voiceBriefing
            }
        }
    }

    private var scheduledBriefing: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let schedule = DayTaskSchedule(tasks: tasks, now: context.date)
            Button { onOpen(.tasks) } label: {
                VStack(spacing: 7) {
                    Text(message(schedule: schedule))
                        .font(.mission(.title3)).foregroundStyle(MissionTheme.ink)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, minHeight: 88).padding(.vertical, 10)
                    .contentShape(Rectangle())
            }.buttonStyle(MissionPressStyle()).accessibilityHint("Opens your tasks and timeline")
        }
    }

    private var voiceBriefing: some View {
        VStack(spacing: 7) {
            if showsConversationText && !voice.progressNarration.isEmpty {
                Label {
                    Text(voice.progressNarration)
                        .italic()
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "ellipsis.circle")
                }
                .font(.mission(.caption))
                .foregroundStyle(MissionTheme.quietText)
                .multilineTextAlignment(.center)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if showsConversationText {
                if !voice.conversationText.displayedUserText.isEmpty {
                    conversationLine("YOU", text: voice.conversationText.displayedUserText)
                }
                if !voice.conversationText.assistantText.isEmpty {
                    conversationLine("ASSISTANT", text: voice.conversationText.assistantText)
                }
                if voice.state == .unavailable || voice.state == .idle {
                    Text(voice.message).font(.mission(.body)).foregroundStyle(MissionTheme.ink)
                        .multilineTextAlignment(.center)
                }
            }
            if voice.state == .preparing || voice.state == .listening
                || voice.state == .processing || voice.state == .speaking {
                Button(voiceActionTitle, action: voice.toggle)
                    .font(.mission(.caption, .semibold)).frame(minHeight: 44)
                    .accessibilityLabel(voiceActionTitle)
            }
        }.frame(maxWidth: .infinity, minHeight: 88).padding(.vertical, 10)
    }

    private func conversationLine(_ label: String, text: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
            Text(text).font(.mission(.body)).foregroundStyle(MissionTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    private var voiceActionTitle: String {
        switch voice.state {
        case .preparing, .listening, .processing, .speaking: "End conversation"
        case .idle, .unavailable: "Try again"
        }
    }

    private func message(schedule: DayTaskSchedule) -> String {
        if let task = schedule.remainingToday.first, let date = task.scheduledAt {
            if date < schedule.minuteEnd { return "It’s time for \(task.title)." }
            return "\(task.title) is at \(date.formatted(date: .omitted, time: .shortened))."
        }
        if !schedule.earlier.isEmpty {
            return schedule.earlier.count == 1 ? "You have one earlier task to check in on."
                : "You have \(schedule.earlier.count) earlier tasks to check in on."
        }
        if let focus, !focus.isCompleted, focus.scheduledAt == nil {
            return "Your focus for today: \(focus.title)."
        }
        if let task = schedule.later.first, let date = task.scheduledAt {
            return "Next up: \(task.title), \(date.formatted(date: .abbreviated, time: .shortened))."
        }
        return "Your day has room. Add something you’d like to move forward."
    }

    private func analyze(url: URL, source: String) {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer { if canAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let type = UTType(filenameExtension: url.pathExtension) ?? .data
            voice.presentAttachmentPayload(try AttachmentAnalysisService.analyze(data: data, type: type, source: source))
        } catch {
            voice.presentAttachmentPayload("\(source)\n\n\(error.localizedDescription)")
        }
    }

    private func analyze(image: UIImage, source: String) {
        do {
            voice.presentAttachmentPayload(try AttachmentAnalysisService.analyze(image: image, source: source))
        } catch {
            voice.presentAttachmentPayload("\(source)\n\n\(error.localizedDescription)")
        }
    }

    private func analyze(data: Data, type: UTType, source: String) {
        do {
            voice.presentAttachmentPayload(try AttachmentAnalysisService.analyze(data: data, type: type, source: source))
        } catch {
            voice.presentAttachmentPayload("\(source)\n\n\(error.localizedDescription)")
        }
    }
}

private struct WorkspaceDrawer: View {
    let spaces: [DashboardSpace]
    @Binding var isExpanded: Bool
    let onOpen: (DashboardSpace) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(MissionTheme.line)
                .frame(width: 38, height: 5)
                .padding(.top, 10)
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.mission(.caption, .bold))
                    Text(isExpanded ? "Close workspace" : "Explore workspace")
                        .font(.mission(.subheadline, .semibold))
                    Spacer()
                    Text("\(spaces.count)")
                        .font(.mission(.caption, .semibold))
                        .foregroundStyle(MissionTheme.quietText)
                }
                .foregroundStyle(MissionTheme.ink)
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Double tap or swipe down to close." : "Double tap or swipe up to open.")

            if isExpanded {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                        ForEach(spaces) { space in
                            Button {
                                onOpen(space)
                                setExpanded(false)
                            } label: {
                                VStack(spacing: 7) {
                                    MissionIconBadge(symbol: space.symbol, color: space.accent, padding: 13)
                                    Text(space.title)
                                        .font(.mission(.caption, .medium))
                                        .foregroundStyle(MissionTheme.ink)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 78)
                            }
                            .buttonStyle(MissionPressStyle())
                            .accessibilityHint("Opens \(space.title)")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: 246)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(MissionTheme.surface.opacity(0.96), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .strokeBorder(MissionTheme.line.opacity(0.9))
                .allowsHitTesting(false)
        }
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            if value.translation.height < -24 { setExpanded(true) }
            if value.translation.height > 24 { setExpanded(false) }
        })
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: setExpanded(true)
            case .decrement: setExpanded(false)
            @unknown default: break
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: isExpanded)
    }

    private func toggle() { setExpanded(!isExpanded) }
    private func setExpanded(_ value: Bool) { isExpanded = value }
}


/// The icons use the full available screen height. The center column measures
/// both the assistant and its message, so longer messages grow into scrolling
/// content instead of overlapping the lower controls.
private struct AssistantConstellationLayout: Layout {
    let compact: Bool
    private var positions: [UnitPoint] {
        compact
            ? [.init(x: 0.13, y: 0.15), .init(x: 0.10, y: 0.50), .init(x: 0.13, y: 0.85),
               .init(x: 0.87, y: 0.15), .init(x: 0.90, y: 0.50), .init(x: 0.87, y: 0.85)]
            : [.init(x: 0.25, y: 0.15), .init(x: 0.10, y: 0.50), .init(x: 0.25, y: 0.85),
               .init(x: 0.75, y: 0.15), .init(x: 0.90, y: 0.50), .init(x: 0.75, y: 0.85)]
    }
    private var iconWidth: CGFloat { compact ? 84 : 116 }

    private func centerWidth(_ width: CGFloat) -> CGFloat {
        // Leave a clear gutter between the message and the lower icon pair.
        compact
            ? min(240, max(150, width - iconWidth * 2 - 24))
            : min(520, max(180, width * 0.5 - iconWidth - 20))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 800
        let centerHeight = subviews.first?.sizeThatFits(.init(width: centerWidth(width), height: nil)).height ?? 0
        let iconHeight = subviews.dropFirst().map { $0.sizeThatFits(.init(width: iconWidth, height: nil)).height }.max() ?? 0
        let availableHeight = proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? 0
        return CGSize(width: width, height: max(460, centerHeight + 40, (iconHeight + 24) / 0.30, availableHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if let center = subviews.first {
            let size = center.sizeThatFits(.init(width: centerWidth(bounds.width), height: nil))
            center.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                         proposal: .init(width: centerWidth(bounds.width), height: size.height))
        }
        for (view, point) in zip(subviews.dropFirst(), positions) {
            let size = view.sizeThatFits(.init(width: iconWidth, height: nil))
            view.place(at: CGPoint(x: bounds.minX + bounds.width * point.x, y: bounds.minY + bounds.height * point.y),
                       anchor: .center, proposal: .init(width: iconWidth, height: size.height))
        }
    }
}
