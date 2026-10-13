import SwiftUI

struct RoutineRef: Identifiable, Hashable { let id: String }

/// A small ring that fills as a routine's count climbs toward its target, and turns into a tick when the day is done.
/// The number inside means it never relies on the ring's colour alone.
struct CountRing: View {
    let count: Int
    let target: Int
    var size: CGFloat = 44
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double { target > 0 ? min(Double(count) / Double(target), 1) : 0 }

    var body: some View {
        ZStack {
            Circle().stroke(Tok.hairline, lineWidth: size * 0.1)
            Circle().trim(from: 0, to: fraction)
                .stroke(Tok.accent, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: fraction)
            if count >= target { Image(systemName: "checkmark").font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(Tok.accent) }
            else { Text("\(count)/\(target)").font(.missionMono(.caption, .medium)).foregroundStyle(Tok.text).minimumScaleFactor(0.6) }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of \(target) today")
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

    private func row(_ s: Wire.RoutineStatus) -> some View {
        HStack(spacing: Space.s) {
            Button { open = RoutineRef(id: s.id) } label: {
                HStack(spacing: Space.m) {
                    CountRing(count: s.count, target: s.target)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.routine.title).font(.mission(.body)).foregroundStyle(Tok.text)
                        Text(s.scheduled ? s.hint : "Not today").font(.mission(.caption)).foregroundStyle(s.gap ? Tok.warn : Tok.muted).lineLimit(2).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(s.routine.title). \(s.count) of \(s.target) today. Show details")
            PlusButton(status: s)
        }
    }
}

/// Logs one more time. Disabled while the previous tap is still being saved, so a fast double-tap cannot collide with itself.
struct PlusButton: View {
    @Environment(Life.self) private var life
    let status: Wire.RoutineStatus

    var body: some View {
        Button { Task { await life.logRoutine(status.id) } } label: {
            Image(systemName: "plus").font(.mission(.headline, .semibold)).foregroundStyle(Tok.onAccent)
                .frame(width: 44, height: 44).background(Tok.accent, in: Circle())
        }
        .buttonStyle(.borderless).disabled(life.busyRoutines.contains(status.id))
        .accessibilityLabel("Log \(status.routine.title) once more")
    }
}
