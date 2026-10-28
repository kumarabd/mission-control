import ClerkKit
import SwiftUI

/// The desktop command surface. It mirrors the web's ⌘K palette: go anywhere,
/// switch the Memory lens, start the next record, change appearance, or jump
/// straight to a goal or task by name.
struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(AppLock.self) private var lock
    @Environment(Clerk.self) private var clerk
    @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.system.rawValue

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var confirmSignOut = false
    @FocusState private var searchFocused: Bool

    private struct PaletteCommand: Identifiable {
        enum Group: String { case navigate = "Navigate", actions = "Actions", appearance = "Appearance", goals = "Goals", tasks = "Tasks", ask = "Ask" }
        let id: String
        let title: String
        let subtitle: String?
        let symbol: String
        let group: Group
        let keywords: String
        let run: () -> Void
    }

    private var commands: [PaletteCommand] {
        let base = baseCommands
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return base }
        let matchingBase = base.filter { $0.keywords.lowercased().contains(trimmed) || $0.title.lowercased().contains(trimmed) }
        var items = matchingBase + recordCommands.filter {
            $0.title.lowercased().contains(trimmed) || $0.keywords.lowercased().contains(trimmed)
        }
        // The field says "Search or ask": unmatched text becomes a prompt for
        // the assistant instead of a dead end.
        let prompt = query.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(
            PaletteCommand(
                id: "ask",
                title: "Ask your assistant",
                subtitle: prompt,
                symbol: "sparkles",
                group: .ask,
                keywords: prompt,
                run: {
                    workspace.chat.request(draft: prompt)
                    workspace.destination = .chat
                }
            )
        )
        return items
    }

    private var baseCommands: [PaletteCommand] {
        var items: [PaletteCommand] = [
            command("today", "Today", "What is on today", "sun.max", .navigate) {
                workspace.destination = .today
            },
            command("goals", "Goals", "Goals, tasks and events", "chart.line.uptrend.xyaxis", .navigate) {
                workspace.destination = .goals
            },
            command("chat", "Chat", "Talk with your assistant", "bubble.left", .navigate) {
                workspace.destination = .chat
            },
            command("memory-world", "Memory · World", "Entities and how they connect", "point.3.connected.trianglepath.dotted", .navigate) {
                workspace.memoryLens = .world
                workspace.destination = .memory
            },
            command("memory-about", "Memory · About you", "The understanding that is still forming", "person.text.rectangle", .navigate) {
                workspace.memoryLens = .aboutYou
                workspace.destination = .memory
            },
            command("notifications", "Notifications", "What your assistant sent", "tray", .navigate) {
                workspace.destination = .notifications
            },
            command("settings", "Settings", "Account, agents, models and connections", "gearshape", .navigate) {
                workspace.destination = .settings
            },
        ]
        items += [
            command("new-task", "New task", "Add a task to today", "checklist", .actions) {
                workspace.requestNewItem(.task)
            },
            command("new-event", "New event", "Put something on the calendar", "calendar.badge.plus", .actions) {
                workspace.requestNewItem(.event)
            },
            command("new-goal", "New goal", "Start a goal with the assistant", "flag", .actions) {
                workspace.discuss("I want to ")
            },
            command("refresh", "Refresh workspace", "Read the latest records", "arrow.clockwise", .actions) {
                Task { await workspace.refresh() }
            },
            command("web", "Open the web console", "Continue in the browser", "safari", .actions) {
                if let url = URL(string: "https://mission-control.nighthawklabs.org") { openURL(url) }
            },
        ]
        for choice in AppearanceChoice.allCases {
            items.append(contentsOf: [
                PaletteCommand(
                    id: "appearance-\(choice.rawValue)",
                    title: "Appearance · \(choice.title)",
                    subtitle: choice.rawValue == appearanceRaw ? "Current" : nil,
                    symbol: choice.symbol,
                    group: .appearance,
                    keywords: "theme appearance \(choice.title) \(choice.rawValue)",
                    run: { appearanceRaw = choice.rawValue }
                ),
            ])
        }
        if lock.enabled {
            items.append(command("lock", "Lock Mission Control", "Require Touch ID or password", "lock.shield", .appearance) {
                lock.lockNow()
            })
        }
        if clerk.user != nil {
            items.append(command("signout", "Sign out", "End this session on this Mac", "rectangle.portrait.and.arrow.right", .appearance) {
                confirmSignOut = true
            })
        }
        return items
    }

    private var recordCommands: [PaletteCommand] {
        var items: [PaletteCommand] = []
        for goal in workspace.life.goals.prefix(8) {
            items.append(
                PaletteCommand(
                    id: "goal-\(goal.id)",
                    title: goal.title,
                    subtitle: "Goal · \(goal.progress.done) of \(goal.progress.total) tasks done",
                    symbol: "flag",
                    group: .goals,
                    keywords: goal.title,
                    run: {
                        workspace.destination = .goals
                        workspace.pendingGoalID = goal.id
                    }
                )
            )
        }
        for task in workspace.life.openTasks.prefix(8) {
            let detail = task.minutes.map { "Task · \($0) min" } ?? "Open task"
            items.append(
                PaletteCommand(
                    id: "task-\(task.id)",
                    title: task.title,
                    subtitle: detail,
                    symbol: "checklist",
                    group: .tasks,
                    keywords: task.title,
                    run: {
                        workspace.destination = .today
                        workspace.pendingItem = ItemRef(id: task.id)
                    }
                )
            )
        }
        return items
    }

    private func command(
        _ id: String,
        _ title: String,
        _ subtitle: String?,
        _ symbol: String,
        _ group: PaletteCommand.Group,
        run: @escaping () -> Void
    ) -> PaletteCommand {
        PaletteCommand(id: id, title: title, subtitle: subtitle, symbol: symbol, group: group,
                       keywords: "\(title) \(subtitle ?? "")", run: run)
    }

    private func matchesGroupBoundary(_ index: Int) -> Bool {
        index == 0 || commands[index - 1].group != commands[index].group
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.s) {
                Image(systemName: "magnifyingglass")
                    .font(.mission(.body))
                    .foregroundStyle(Tok.muted)
                    .accessibilityHidden(true)
                TextField("Go to a screen or record…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.mission(.title3))
                    .focused($searchFocused)
                    .onSubmit(runSelected)
                    .onKeyPress(.downArrow) {
                        move(1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        move(-1)
                        return .handled
                    }
                Text("esc")
                    .font(.missionMono(.caption2))
                    .foregroundStyle(Tok.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Tok.raised, in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, Space.l)
            .frame(minHeight: 56)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if commands.isEmpty {
                            VStack(spacing: Space.s) {
                                Text("No matches.").font(.mission(.body)).foregroundStyle(Tok.muted)
                                Text("Try a screen name, a goal, or a task.")
                                    .font(.mission(.caption)).foregroundStyle(Tok.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 46)
                        } else {
                            ForEach(Array(commands.enumerated()), id: \.element.id) { index, item in
                                if matchesGroupBoundary(index) {
                                    Text(item.group.rawValue.uppercased())
                                        .font(.missionMono(.caption2, .medium))
                                        .tracking(0.9)
                                        .foregroundStyle(Tok.muted)
                                        .padding(.horizontal, Space.m)
                                        .padding(.top, index == 0 ? Space.s : Space.m)
                                        .padding(.bottom, 3)
                                }
                                Button {
                                    selectedIndex = index
                                    run(item)
                                } label: {
                                    HStack(spacing: Space.s) {
                                        Image(systemName: item.symbol)
                                            .font(.mission(.body))
                                            .foregroundStyle(index == selectedIndex ? Tok.accent : Tok.muted)
                                            .frame(width: 22)
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.title)
                                                .font(.mission(.callout, .medium))
                                                .foregroundStyle(Tok.text)
                                                .lineLimit(1)
                                            if let subtitle = item.subtitle {
                                                Text(subtitle)
                                                    .font(.mission(.caption))
                                                    .foregroundStyle(Tok.muted)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, Space.m)
                                    .padding(.vertical, 8)
                                    .background(
                                        index == selectedIndex ? Tok.accent.opacity(0.1) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in if hovering { selectedIndex = index } }
                                .id(index)
                            }
                        }
                    }
                    .padding(6)
                }
                .onChange(of: selectedIndex) { _, index in
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(index, anchor: .center) }
                }
            }

            Divider()
            HStack(spacing: Space.m) {
                Text("↑↓ move").font(.missionMono(.caption2)).foregroundStyle(Tok.muted)
                Text("↵ open").font(.missionMono(.caption2)).foregroundStyle(Tok.muted)
                Spacer()
                Text("\(commands.count) \(commands.count == 1 ? "command" : "commands")")
                    .font(.missionMono(.caption2)).foregroundStyle(Tok.muted)
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
        }
        .frame(width: 640, height: 520)
        .background(Tok.surface)
        .onAppear { searchFocused = true }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .confirmationDialog("Sign out of Mission Control?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    try? await clerk.auth.signOut()
                    dismiss()
                }
            }
        } message: {
            Text("This ends your session on this Mac.")
        }
    }

    private func move(_ delta: Int) {
        guard !commands.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), commands.count - 1)
    }

    private func runSelected() {
        guard commands.indices.contains(selectedIndex) else { return }
        run(commands[selectedIndex])
    }

    private func run(_ item: PaletteCommand) {
        item.run()
        if item.id != "signout" { dismiss() }
    }
}
