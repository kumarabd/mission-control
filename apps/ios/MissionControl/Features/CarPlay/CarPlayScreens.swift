import CarPlay
import UIKit

/// The assistant screen: the voice control is the point, with just enough of the day and the goals underneath that a
/// driver can see what is coming without leaving it. Everything updates in place; the template itself never changes.
@MainActor
final class CarPlayRootScreen {
    let template: CPListTemplate
    private let voice: AssistantVoiceCoordinator
    private let workspace: CarPlayWorkspace
    private static let wordsKey = "missionShowConversationText"

    var showsWords: Bool {
        get { (UserDefaults.standard.object(forKey: Self.wordsKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.wordsKey); refresh() }
    }

    var talk: () -> Void = {}
    var openToday: () -> Void = {}
    var openItem: (Wire.DayEntry) -> Void = { _ in }
    var openGoal: (Wire.Goal) -> Void = { _ in }
    var retry: () -> Void = {}

    init(voice: AssistantVoiceCoordinator, workspace: CarPlayWorkspace) {
        self.voice = voice
        self.workspace = workspace
        template = CPListTemplate(title: "Mission Control", sections: [])
        template.trailingNavigationBarButtons = [
            CPBarButton(title: "Today") { [weak self] _ in self?.openToday() },
            CPBarButton(title: UserDefaults.standard.object(forKey: Self.wordsKey) as? Bool ?? true ? "Hide words" : "Show words") { [weak self] _ in
                guard let self else { return }
                showsWords.toggle()
            },
        ]
        refresh()
    }

    func refresh() {
        template.updateSections(sections())
        template.trailingNavigationBarButtons = [
            CPBarButton(title: "Today") { [weak self] _ in self?.openToday() },
            CPBarButton(title: showsWords ? "Hide words" : "Show words") { [weak self] _ in self?.showsWords.toggle() },
        ]
        if #available(iOS 26.0, *) {
            template.headerGridButtons = gridButtons()
        }
    }

    // MARK: Sections

    private func sections() -> [CPListSection] {
        var sections: [CPListSection] = []

        let status = CPListItem(text: statusTitle, detailText: statusDetail,
                                image: AgentMarkArtwork.image(state: voice.state, size: AgentMarkArtwork.rowSize))
        status.handler = { [weak self] _, completion in
            self?.talk()
            completion()
        }
        sections.append(CPListSection(items: [status], header: "NOW", sectionIndexTitle: nil))

        if showsWords {
            var words: [CPListItem] = []
            let spoken = CarPlayText.compact(voice.conversationText.displayedUserText)
            let reply = CarPlayText.compact(voice.conversationText.assistantText)
            if !spoken.isEmpty { words.append(CPListItem(text: spoken, detailText: "You said")) }
            if !reply.isEmpty { words.append(CPListItem(text: reply, detailText: "Mission Control")) }
            if !words.isEmpty {
                sections.append(CPListSection(items: words, header: "CONVERSATION", sectionIndexTitle: nil))
            }
        }

        let next = workspace.nextEntries
        if !next.isEmpty {
            sections.append(CPListSection(items: next.map(entryItem), header: "TODAY", sectionIndexTitle: nil))
        }

        let goals = Array(workspace.openGoals.prefix(3))
        if !goals.isEmpty {
            let items = goals.map { goal -> CPListItem in
                let detail = goal.progress.total > 0
                    ? "\(goal.progress.done) of \(goal.progress.total) steps"
                    : goal.next.map { "Next: \($0.title)" } ?? "No steps yet"
                let item = CPListItem(text: goal.title, detailText: detail, image: UIImage(systemName: "target"))
                item.handler = { [weak self] _, completion in
                    self?.openGoal(goal)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: items, header: "GOALS", sectionIndexTitle: nil))
        }

        if let failure = workspace.failure {
            let item = CPListItem(text: "Couldn’t load your workspace", detailText: failure,
                                  image: UIImage(systemName: "wifi.exclamationmark"))
            item.handler = { [weak self] _, completion in
                self?.retry()
                completion()
            }
            sections.append(CPListSection(items: [item], header: "WORKSPACE", sectionIndexTitle: nil))
        }

        return sections
    }

    @available(iOS 26.0, *)
    private func gridButtons() -> [CPGridButton] {
        let active = voice.state != .idle && voice.state != .unavailable
        let talk = CPGridButton(
            titleVariants: active ? ["End voice", "End"] : ["Talk", "Talk to Mission Control"],
            image: AgentMarkArtwork.image(state: voice.state, size: AgentMarkArtwork.gridSize)
        ) { [weak self] _ in self?.talk() }
        let today = CPGridButton(
            titleVariants: ["Today", "What's on today"],
            image: UIImage(systemName: "list.bullet")!
        ) { [weak self] _ in self?.openToday() }
        return [talk, today]
    }

    // MARK: Rows

    private func entryItem(_ entry: Wire.DayEntry) -> CPListItem {
        let item = CPListItem(text: entry.item.title, detailText: CarPlayText.entryDetail(entry),
                              image: UIImage(systemName: CarPlayText.symbol(for: entry)))
        item.handler = { [weak self] _, completion in
            self?.openItem(entry)
            completion()
        }
        return item
    }

    private var statusTitle: String {
        switch voice.state {
        case .idle: return "Tap the mark to talk"
        case .preparing: return "Getting ready"
        case .listening: return "Listening…"
        case .processing: return "Thinking…"
        case .speaking: return "Speaking…"
        case .unavailable: return "Voice is unavailable"
        }
    }

    private var statusDetail: String {
        switch voice.state {
        case .idle: return "Ask about today, change a plan, or just talk."
        case .preparing: return "Starting the voice session."
        case .listening: return "Speak naturally — your words appear below."
        case .processing: return "Your request is on its way."
        case .speaking: return "Keep your attention on the road."
        case .unavailable: return CarPlayText.compact(voice.message.isEmpty ? "Tap the mark to try again." : voice.message)
        }
    }
}

/// The full day, pushed from the assistant screen. Three template levels are all this category allows, so an item
/// opens read-only details with the two actions a driver may need; anything more is a conversation.
@MainActor
enum CarPlayScreens {
    static func today(_ workspace: CarPlayWorkspace,
                      retry: @escaping () -> Void,
                      open: @escaping (Wire.DayEntry, @escaping () -> Void) -> Void) -> CPListTemplate {
        var sections: [CPListSection] = []

        func section(_ header: String, _ entries: [Wire.DayEntry]) {
            guard !entries.isEmpty else { return }
            let items = entries.map { entry -> CPListItem in
                let item = CPListItem(text: entry.item.title, detailText: CarPlayText.entryDetail(entry),
                                      image: UIImage(systemName: CarPlayText.symbol(for: entry)))
                item.handler = { _, completion in open(entry, completion) }
                return item
            }
            sections.append(CPListSection(items: items, header: header, sectionIndexTitle: nil))
        }

        section("OVERDUE", workspace.overdueEntries)
        section("AT A TIME", workspace.timedEntries)
        section("FOR TODAY", workspace.anytimeEntries)
        section("DONE", Array(workspace.doneEntries.prefix(6)))

        if let failure = workspace.failure, sections.isEmpty {
            let item = CPListItem(text: "Couldn’t load your day", detailText: failure,
                                  image: UIImage(systemName: "wifi.exclamationmark"))
            item.handler = { _, completion in retry(); completion() }
            sections.append(CPListSection(items: [item], header: "TODAY", sectionIndexTitle: nil))
        }

        if sections.isEmpty {
            let item = CPListItem(text: "Nothing on today", detailText: "Ask Mission Control to add something.")
            item.isEnabled = false
            sections.append(CPListSection(items: [item], header: "TODAY", sectionIndexTitle: nil))
        }

        let template = CPListTemplate(title: "Today", sections: sections)
        template.trailingNavigationBarButtons = [
            CPBarButton(image: UIImage(systemName: "arrow.clockwise")!) { _ in retry() },
        ]
        return template
    }

    static func item(_ entry: Wire.DayEntry,
                     goalTitle: String?,
                     complete: @escaping (Bool) async -> Bool,
                     snooze: @escaping () async -> Bool) -> CPInformationTemplate {
        var rows: [CPInformationItem] = []
        rows.append(.init(title: "Status", detail: CarPlayText.status(entry)))
        rows.append(.init(title: "When", detail: CarPlayText.when(entry)))
        if let minutes = entry.item.minutes { rows.append(.init(title: "Length", detail: "\(minutes) minutes")) }
        if let recurrence = entry.item.recurrence { rows.append(.init(title: "Repeats", detail: CarPlayText.recurrence(recurrence))) }
        if let goalTitle, !goalTitle.isEmpty { rows.append(.init(title: "Goal", detail: goalTitle)) }
        if let alert = entry.item.alertBeforeMinutes { rows.append(.init(title: "Alert", detail: alert > 0 ? "\(alert) minutes before" : "At the time")) }
        if !entry.item.notes.isEmpty { rows.append(.init(title: "Notes", detail: CarPlayText.compact(entry.item.notes, limit: 240))) }

        var actions: [CPTextButton] = []
        if entry.item.isTask {
            actions.append(CPTextButton(title: entry.isDone ? "Reopen" : "Mark done",
                                        textStyle: entry.isDone ? .normal : .confirm) { _ in
                Task { @MainActor in _ = await complete(!entry.isDone) }
            })
            if !entry.isDone {
                actions.append(CPTextButton(title: "Snooze 1 hour", textStyle: .normal) { _ in
                    Task { @MainActor in _ = await snooze() }
                })
            }
        }

        return CPInformationTemplate(title: entry.item.title, layout: .leading, items: rows, actions: actions)
    }

    static func goal(_ goal: Wire.Goal) -> CPInformationTemplate {
        var rows: [CPInformationItem] = []
        if goal.progress.total > 0 {
            rows.append(.init(title: "Progress", detail: "\(goal.progress.done) of \(goal.progress.total) steps done"))
        } else {
            rows.append(.init(title: "Progress", detail: "No steps set up yet"))
        }
        if let next = goal.next {
            rows.append(.init(title: "Next step", detail: "\(next.title) · \(CarPlayText.when(next))"))
        }
        if let endsOn = goal.endsOn { rows.append(.init(title: "Ends", detail: endsOn)) }
        if !goal.notes.isEmpty { rows.append(.init(title: "Notes", detail: CarPlayText.compact(goal.notes, limit: 240))) }
        return CPInformationTemplate(title: goal.title, layout: .leading, items: rows, actions: [])
    }
}

/// Small shared formatting for the car: one line, short, and never a wall of text at a glance.
private enum CarPlayText {
    static func compact(_ text: String, limit: Int = 120) -> String {
        let single = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return single.count > limit ? String(single.prefix(limit - 3)) + "…" : single
    }

    static func symbol(for entry: Wire.DayEntry) -> String {
        if entry.isDone { return "checkmark.circle.fill" }
        if entry.overdue || (entry.item.isTask && entry.at < Date()) { return "exclamationmark.circle" }
        if entry.item.isEvent { return "calendar" }
        if entry.item.isPriority { return "flag.fill" }
        return "circle"
    }

    static func entryDetail(_ entry: Wire.DayEntry) -> String {
        var parts: [String] = []
        if entry.overdue { parts.append("Overdue") }
        else if entry.item.at == nil { parts.append("Anytime") }
        else { parts.append(entry.at.formatted(date: .omitted, time: .shortened)) }
        parts.append(entry.isDone ? "Done" : (entry.item.isEvent ? "Event" : "Task"))
        if entry.item.repeats { parts.append("Repeats") }
        if entry.item.isPriority && !entry.isDone { parts.append("Priority") }
        return parts.joined(separator: " · ")
    }

    static func status(_ entry: Wire.DayEntry) -> String {
        if entry.isDone { return "Done" }
        if entry.item.isEvent { return entry.state == "past" ? "Earlier" : "Coming up" }
        return entry.overdue ? "Overdue" : "Open"
    }

    static func when(_ entry: Wire.DayEntry) -> String {
        guard entry.item.at != nil else { return "Anytime today" }
        return entry.at.formatted(date: .abbreviated, time: .shortened)
    }

    static func when(_ item: Wire.Item) -> String {
        guard let at = item.at else { return "Anytime" }
        return at.formatted(date: .abbreviated, time: .shortened)
    }

    static func recurrence(_ recurrence: Wire.Recurrence) -> String {
        switch recurrence.freq {
        case "daily": return recurrence.interval == 1 ? "Every day" : "Every \(recurrence.interval ?? 2) days"
        case "weekly":
            if let days = recurrence.weekdays, !days.isEmpty {
                let names = days.compactMap { Calendar.current.weekdaySymbols[safe: $0 - 1] }
                return "Weekly on " + names.joined(separator: ", ")
            }
            return "Every week"
        case "monthly": return "Every month"
        case "yearly": return "Every year"
        default: return recurrence.freq.capitalized
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
