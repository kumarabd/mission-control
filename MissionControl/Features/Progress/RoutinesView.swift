import SwiftUI

struct RoutineRef: Identifiable, Hashable { let id: String }

/// The control for a routine: a ring with one segment for each time it should be done today. Tap it to record one; the next segment
/// fills, and when the last does the ring becomes a solid check. A routine that does not apply today shows a dashed ring and a
/// calendar, and is not tappable. The segments, the check and the calendar are the whole vocabulary, so nothing needs a word.
struct LogRing: View {
    @Environment(Life.self) private var life
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let status: Wire.RoutineStatus
    var size: CGFloat = 48
    /// False where the ring only shows how the routine is going (on a goal); recording happens in the routine's own screen.
    var interactive = true

    private var lineWidth: CGFloat { size * 0.09 }
    private var segments: Int { min(status.target, 12) }

    var body: some View {
        if interactive {
            Button {
                guard status.scheduled, !status.done, !life.busyRoutines.contains(status.id) else { return }
                Task { await life.logRoutine(status.id) }
            } label: { face }
            .buttonStyle(.borderless)
            .sensoryFeedback(.impact(weight: .medium), trigger: status.count)
            .accessibilityLabel(label)
            .accessibilityAddTraits(status.scheduled && !status.done ? .isButton : [])
        } else {
            face.accessibilityElement().accessibilityLabel(label)
        }
    }

    private var label: String {
        if !status.scheduled { return "\(status.routine.title) is not scheduled today" }
        if status.done { return "\(status.routine.title) is done for today" }
        return status.target > 1 ? "Record \(status.routine.title) once. \(status.count) of \(status.target) today" : "Mark \(status.routine.title) done"
    }

    @ViewBuilder private var face: some View {
        ZStack {
            if !status.scheduled {
                Circle().strokeBorder(Tok.hairline, style: StrokeStyle(lineWidth: lineWidth * 0.8, dash: [3, 4]))
                Image(systemName: "calendar").font(.system(size: size * 0.34)).foregroundStyle(Tok.muted)
            } else {
                ForEach(0..<segments, id: \.self) { i in
                    let gap = segments > 1 ? 0.02 : 0
                    let start = Double(i) / Double(segments) + gap / 2, end = Double(i + 1) / Double(segments) - gap / 2
                    Circle().trim(from: start, to: end).stroke(i < status.count ? Tok.accent : Tok.hairline, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: status.count)
                }
                if status.done {
                    Circle().fill(Tok.accent).padding(lineWidth * 1.4)
                    Image(systemName: "checkmark").font(.system(size: size * 0.32, weight: .bold)).foregroundStyle(Tok.onAccent)
                } else {
                    Image(systemName: "checkmark").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(Tok.accent.opacity(0.4))
                }
            }
        }
        .frame(width: size, height: size).contentShape(Circle())
    }
}

struct RoutinesList: View {
    @Environment(Life.self) private var life
    let onNew: () -> Void
    @State private var open: RoutineRef?

    var body: some View {
        Group {
            if !life.routinesAvailable {
                EmptyState(symbol: "icloud.slash", title: "Routines need your workspace", message: "They are kept with your assistant, which isn't reachable right now.")
            } else if life.routines.isEmpty {
                EmptyState(symbol: "repeat", title: "Build a routine", message: "Something you want to keep doing, like drinking water three times a day. A missed day is fine; we track how consistent you are.",
                           actionTitle: "New routine", action: onNew)
            } else {
                List {
                    Section {
                        ForEach(life.routines) { status in row(status) }
                    } footer: { Text("Busy day? Do the short version. Missed a few days? Just start again.").font(.mission(.footnote)) }
                    .listRowBackground(Tok.surface)
                }
                .scrollContentBackground(.hidden)
                .refreshable { await life.loadRoutines() }
            }
        }
        .navigationDestination(item: $open) { RoutineDetailView(id: $0.id) }
        .task { await life.loadRoutines() }
    }

    private func row(_ s: Wire.RoutineStatus) -> some View { RoutineRow(status: s) { open = RoutineRef(id: s.id) } }
}

/// A routine as a row: the ring records one, the text opens the tracker. Used by the routines list and by a goal's routines.
struct RoutineRow: View {
    let status: Wire.RoutineStatus
    var interactive = true
    let open: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            LogRing(status: status, interactive: interactive)
            Button(action: open) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.routine.title).font(.mission(.body)).foregroundStyle(Tok.text)
                        Text(status.scheduled ? status.hint : (status.nextText.map { "Next: \($0)" } ?? "Not today")).font(.mission(.caption))
                            .foregroundStyle(status.gap ? Tok.warn : Tok.muted).lineLimit(2).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Tok.muted)
                }
                .frame(minHeight: 48).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(status.routine.title). Show details")
        }
    }
}

extension Wire.RoutineStatus {
    /// For a routine that does not apply today: when it next does ("Tomorrow", "Sunday").
    var nextText: String? {
        RoutineSchedule.nextLabel(weekdays: routine.weekdays, today: RoutineSchedule.weekdayNow(in: routine.timeZone), names: Calendar.current.weekdaySymbols)
    }
}
