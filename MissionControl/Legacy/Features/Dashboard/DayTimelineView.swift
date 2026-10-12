import SwiftUI

/// Explicit times form the agenda; flexible work stays outside its clock rail.
struct DayTimelineView: View {
    let tasks: [MissionTask]
    let focus: MissionTask?
    let onComplete: (MissionTask) -> Void
    let onSelectFocus: (MissionTask) -> Void
    let onOpen: (DashboardSpace) -> Void
    let onAdd: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCompleted = false
    @State private var editingTime: MissionTask?
    private var completed: [MissionTask] { tasks.filter(\.isCompleted) }

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now, by: 60)) { context in
            day(at: context.date)
        }
        .buttonStyle(MissionPressStyle())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: focus?.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: showCompleted)
        .sheet(item: $editingTime) { TaskTimingSheet(task: $0) }
    }

    private func day(at now: Date) -> some View {
        let schedule = DayTaskSchedule(tasks: tasks, now: now)
        // Focus highlights a task in its real timing group, never moves it to a fake time.
        let anytime = schedule.anytime.filter { $0.id == focus?.id }
            + schedule.anytime.filter { $0.id != focus?.id }

        return DashboardHeightLayout {
            HStack {
                Text("My day").font(.mission(.title3, .medium))
                Spacer()
                Button { onOpen(.schedule) } label: {
                    Image(systemName: "calendar.badge.clock").foregroundStyle(MissionTheme.scheduled)
                        .frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("View all planned times")
                Button { onOpen(.taskList) } label: {
                    Image(systemName: "checklist").foregroundStyle(MissionTheme.tint)
                        .frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Manage all tasks")
            }.padding(.horizontal, 12)

            sectionLabel("At a time", symbol: "clock", detail: "Planned")
            ForEach(schedule.earlier) { task in
                TimelineLane(symbol: "clock.arrow.circlepath", tone: .attention,
                             date: task.scheduledAt, now: now, continues: true) {
                    taskEntry(task, caption: "Earlier · still open", tone: .attention)
                }
            }

            HStack(spacing: 8) {
                Text(now, style: .time).monospacedDigit()
                Circle().fill(MissionTheme.tint).frame(width: 6, height: 6).accessibilityHidden(true)
                Text("Now").fontWeight(.semibold)
                Rectangle().fill(MissionTheme.tint.opacity(0.4)).frame(height: 1).accessibilityHidden(true)
            }
            .font(.mission(.caption)).foregroundStyle(MissionTheme.tint)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .accessibilityElement(children: .combine)

            ForEach(schedule.remainingToday) { task in
                TimelineLane(symbol: "clock", tone: .scheduled, date: task.scheduledAt, now: now,
                             continues: task.id != schedule.remainingToday.last?.id) {
                    taskEntry(task, caption: task.scheduledAt! < schedule.minuteEnd ? "This minute"
                              : (task.id == schedule.remainingToday.first?.id ? "Next" : "Planned"),
                              tone: .scheduled)
                }
            }

            if schedule.earlier.isEmpty && schedule.remainingToday.isEmpty {
                Button(action: onAdd) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle").foregroundStyle(MissionTheme.scheduled)
                        Text("No set times today").font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
                        Spacer(minLength: 0)
                        Image(systemName: "plus").foregroundStyle(MissionTheme.scheduled)
                    }.frame(minHeight: 44).padding(.horizontal, 12).contentShape(Rectangle())
                }.accessibilityHint("Add a task and optionally choose a specific time")
            }

            if !schedule.later.isEmpty {
                Button { onOpen(.schedule) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("\(schedule.later.count) planned beyond today", systemImage: "calendar")
                        if let focus, schedule.later.contains(where: { $0.id == focus.id }) {
                            Label("Focus · \(focus.title)", systemImage: "scope")
                            TaskTimingLabel(date: focus.scheduledAt)
                        }
                    }.font(.mission(.caption)).frame(minHeight: 44)
                }.padding(.horizontal, 12)
            }

            sectionLabel("For today", symbol: "sun.max", detail: "No fixed time")
            ForEach(anytime) { task in
                TimelineLane(symbol: task.id == focus?.id ? "scope" : "circle.dotted", tone: .focus) {
                    taskEntry(task, caption: "Anytime", tone: .focus)
                }
            }

            if anytime.isEmpty {
                TimelineLane(symbol: "sun.max", tone: .focus) {
                    entry(title: "Room for something flexible", caption: "Anytime · add a task", tone: .focus, action: onAdd)
                }
            }
            TimelineLane(symbol: "exclamationmark.bubble", tone: .attention) {
                entry(title: "Reply to Sam", caption: "Needs action today · Sample", tone: .attention) { onOpen(.reply) }
            }
            TimelineLane(symbol: "leaf", tone: .reminder, expands: !completed.isEmpty) {
                entry(title: "Use the spinach", caption: "Use by tomorrow · Sample", tone: .reminder) { onOpen(.spinach) }
            }
            if !completed.isEmpty {
                TimelineLane(symbol: "checkmark.circle", tone: .completed, expands: false) {
                    DisclosureGroup(isExpanded: $showCompleted) {
                        ForEach(completed) { task in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                                Text(task.title).strikethrough()
                            }.font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 7)
                        }
                    } label: {
                        Text("\(completed.count) completed").font(.mission(.subheadline))
                            .foregroundStyle(MissionTheme.quietText).frame(minHeight: 44)
                    }.padding(.horizontal, 10)
                }
            }
        }
    }

    private func sectionLabel(_ title: String, symbol: String, detail: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text(detail).foregroundStyle(MissionTheme.quietText)
            }
            VStack(alignment: .leading, spacing: 3) {
                Label(title, systemImage: symbol)
                Text(detail).foregroundStyle(MissionTheme.quietText)
            }
        }.font(.mission(.caption, .medium)).padding(.horizontal, 12).padding(.vertical, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func taskEntry(_ task: MissionTask, caption: String, tone: MissionTone) -> some View {
        let isFocus = task.id == focus?.id
        return HStack(spacing: 6) {
            Button { isFocus ? onOpen(.focus) : onSelectFocus(task) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    if isFocus {
                        Label("\(caption) · Focus", systemImage: "scope")
                            .font(.mission(.caption)).foregroundStyle(MissionTheme.tint)
                    } else {
                        Text(caption).font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
                    }
                    Text(task.title).font(isFocus ? .mission(.headline, .medium) : .mission(.subheadline, .medium))
                        .foregroundStyle(MissionTheme.ink)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }
            .accessibilityHint(isFocus ? "Choose a different focus" : "Make this your current focus")
            Menu {
                Button("Set or change time", systemImage: "clock") { editingTime = task }
                Button("Complete task", systemImage: "checkmark") { onComplete(task) }
            } label: {
                Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                    .foregroundStyle(tone.color)
            }.accessibilityLabel("Actions for \(task.title)")
            if isFocus {
                Button { onComplete(task) } label: {
                    Image(systemName: "checkmark").frame(minWidth: 44, minHeight: 44)
                        .background(MissionTheme.tint, in: Circle()).foregroundStyle(MissionTheme.actionInk)
                }.accessibilityLabel("Complete \(task.title)")
            }
        }.padding(.horizontal, 10).padding(.vertical, 6)
            .background((isFocus ? MissionTheme.tint : tone.color).opacity(0.10), in: MissionTheme.compactShape)
    }

    private func entry(title: String, caption: String, tone: MissionTone, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(caption).font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
                    Text(title).font(.mission(.subheadline, .medium)).foregroundStyle(MissionTheme.ink)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.mission(.caption)).foregroundStyle(tone.color).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(tone.color.opacity(0.07), in: MissionTheme.compactShape)
            .contentShape(Rectangle())
        }
    }
}

private struct TimelineLane<Content: View>: View {
    let symbol: String
    let tone: MissionTone
    var date: Date? = nil
    var now: Date = .now
    var continues = false
    var expands = true
    @ViewBuilder let content: Content
    @ScaledMetric(relativeTo: .body) private var iconRailWidth = 40
    @ScaledMetric(relativeTo: .caption) private var timeRailWidth = 76
    private var railWidth: CGFloat { date == nil ? iconRailWidth : timeRailWidth }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 4) {
                if let date {
                    Text(date, style: .time).font(.mission(.caption, .semibold)).monospacedDigit()
                        .foregroundStyle(tone.color)
                    if !Calendar.current.isDate(date, inSameDayAs: now) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.mission(.caption2)).foregroundStyle(MissionTheme.quietText)
                    }
                }
                MissionIconBadge(symbol: symbol, color: tone.color, padding: 9)
            }.fixedSize(horizontal: false, vertical: true).frame(width: railWidth)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, expands ? 6 : 0)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(alignment: .topLeading) {
            // Flexible items intentionally have no connecting clock line.
            if date != nil && continues {
                Rectangle().fill(MissionTheme.line).frame(width: 1)
                    .offset(x: railWidth + 3).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .layoutValue(key: DashboardExpandsVertically.self, value: expands)
    }
}
