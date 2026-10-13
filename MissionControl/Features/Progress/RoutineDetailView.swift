import SwiftUI

/// One routine's tracker: today's count, the week, the last month, and how consistent you have been. A missed day lowers a
/// rate; it never resets what you have built.
struct RoutineDetailView: View {
    let id: String
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var history: Wire.RoutineHistory?
    @State private var confirmDelete = false

    private var status: Wire.RoutineStatus? { life.routines.first { $0.id == id } }

    var body: some View {
        Group {
            if let s = status { content(s) } else {
                ContentUnavailableView("This routine is gone", systemImage: "repeat", description: Text("It was removed."))
            }
        }
        .scrollContentBackground(.hidden).screenBackground()
        .navigationTitle(status?.routine.title ?? "Routine").navigationBarTitleDisplayMode(.inline)
        .task(id: status?.count) { history = await life.history(for: id) }   // loads once, then follows each tap
        .confirmationDialog("Delete this routine?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let r = status?.routine { Task { await life.deleteRoutine(r); dismiss() } }
            }
        } message: { Text("Its history stays with your assistant and it can be restored.") }
    }

    private func content(_ s: Wire.RoutineStatus) -> some View {
        List {
            overviewSection(s)
            todaySection(s)
            if let h = history { weekSection(h); monthSection(h); consistencySection(h) }
            detailsSection(s.routine)
            Section { Button("Delete routine", systemImage: "trash", role: .destructive) { confirmDelete = true } }
                .listRowBackground(Tok.surface)
        }
    }

    // MARK: Overview

    private func overviewSection(_ s: Wire.RoutineStatus) -> some View {
        Section {
            MarkdownView(text: Overview.routine(s.routine, count: s.count, target: s.target, history: history, clock: Self.clock, days: Self.weekdays(s.routine.weekdays)))
        }
        .listRowBackground(Tok.surface)
    }

    // MARK: Today

    private func todaySection(_ s: Wire.RoutineStatus) -> some View {
        Section {
            HStack(spacing: Space.l) {
                CountRing(count: s.count, target: s.target, size: 88)
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(s.scheduled ? s.hint : "Not scheduled today" + (s.nextText.map { ". Next: \($0)." } ?? ".")).font(.mission(.subheadline)).foregroundStyle(s.gap ? Tok.warn : Tok.muted)
                    LogButton(status: s)
                    if s.scheduled && s.count > 0 {
                        Button { Task { await life.logRoutine(s.id, delta: -1) } } label: { Label("Take one back", systemImage: "arrow.uturn.backward") }
                            .font(.mission(.subheadline)).buttonStyle(.borderless).foregroundStyle(Tok.muted).frame(minHeight: 44)
                            .disabled(life.busyRoutines.contains(s.id))
                    }
                }
            }
            if s.scheduled && !s.done {
                Button { Task { await life.logRoutine(s.id, short: true) } } label: {
                    Label("Short version: \(s.routine.shortTitle) (\(s.routine.shortMinutes) min)", systemImage: "timer")
                }
                .disabled(life.busyRoutines.contains(s.id))
            }
        } header: { Text("Today").font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface)
    }

    // MARK: History

    private func weekSection(_ h: Wire.RoutineHistory) -> some View {
        Section {
            HStack {
                ForEach(h.days.suffix(7)) { d in
                    VStack(spacing: Space.xs) {
                        DayDot(day: d, isToday: d.id == h.days.last?.id)
                        Text(Self.weekdayLetter(d.day)).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                    }.frame(maxWidth: .infinity)
                }
            }
        } header: { Text("This week").font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface)
    }

    private func monthSection(_ h: Wire.RoutineHistory) -> some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                ForEach(h.days) { d in
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Self.cellColor(d)).aspectRatio(1, contentMode: .fit)
                        .accessibilityElement().accessibilityLabel(Self.describe(d))
                }
            }
            .padding(.vertical, Space.xs)
            HStack(spacing: Space.l) {
                legend(Tok.accent, "Done"); legend(Tok.accent.opacity(0.45), "Some"); legend(Tok.hairline, "Missed")
            }.font(.mission(.caption)).foregroundStyle(Tok.muted)
        } header: { Text("Last \(h.days.count) days").font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface)
    }

    private func consistencySection(_ h: Wire.RoutineHistory) -> some View {
        Section {
            LabeledContent("Last 7 days") { Text("\(h.last7.done) of \(h.last7.scheduled)").foregroundStyle(Tok.text) }
            LabeledContent("Last 30 days") { Text("\(h.last30.done) of \(h.last30.scheduled)").foregroundStyle(Tok.text) }
            LabeledContent("Current run") { Text("\(h.streak) \(h.streak == 1 ? "day" : "days")").foregroundStyle(Tok.text) }
            LabeledContent("Best run") { Text("\(h.bestStreak) \(h.bestStreak == 1 ? "day" : "days")").foregroundStyle(Tok.text) }
        } header: { Text("Consistency").font(.mission(.subheadline, .medium)) }
        footer: { Text("A missed day lowers the rate. It never wipes out what you have done.").font(.mission(.footnote)) }
        .listRowBackground(Tok.surface)
    }

    // MARK: Details

    private func detailsSection(_ r: Wire.Routine) -> some View {
        Section {
            LabeledContent("Times a day") { Text("\(r.targetPerDay)").foregroundStyle(Tok.text) }
            LabeledContent("Nudges") { Text(r.cues.isEmpty ? "None" : r.cues.map(Self.clock).joined(separator: ", ")).foregroundStyle(Tok.text).multilineTextAlignment(.trailing) }
            LabeledContent("Days") { Text(Self.weekdays(r.weekdays)).foregroundStyle(Tok.text) }
            LabeledContent("Usual") { Text("\(r.minutes) min").foregroundStyle(Tok.text) }
            LabeledContent("Short version") { Text("\(r.shortTitle), \(r.shortMinutes) min").foregroundStyle(Tok.text).multilineTextAlignment(.trailing) }
        } header: { Text("Details").font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface)
    }

    // MARK: Helpers

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: Space.xs) { RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12); Text(label) }
    }

    static func cellColor(_ d: Wire.HistoryDay) -> Color {
        if !d.scheduled { return Tok.hairline.opacity(0.35) }
        if d.done { return Tok.accent }
        return d.count > 0 ? Tok.accent.opacity(0.45) : Tok.hairline
    }

    static func describe(_ d: Wire.HistoryDay) -> String {
        let when = date(d.day)?.formatted(.dateTime.weekday(.wide).day().month()) ?? d.day
        if !d.scheduled { return "\(when): not scheduled" }
        return d.done ? "\(when): done" : d.count > 0 ? "\(when): \(d.count) of \(d.target)" : "\(when): missed"
    }

    static func date(_ day: String) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.date(from: day)
    }
    static func weekdayLetter(_ day: String) -> String {
        guard let d = date(day) else { return "" }
        return String(d.formatted(.dateTime.weekday(.narrow)))
    }
    /// "09:00" shown as the user's clock ("9:00 AM").
    static func clock(_ hhmm: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"
        guard let d = f.date(from: hhmm) else { return hhmm }
        return d.formatted(date: .omitted, time: .shortened)
    }
    static func weekdays(_ days: [Int]) -> String {
        if days.isEmpty || days.count == 7 { return "Every day" }
        let names = Calendar.current.shortWeekdaySymbols
        return days.sorted().compactMap { names.indices.contains($0) ? names[$0] : nil }.joined(separator: ", ")
    }
}

/// One day on the week strip. Shape and fill carry the meaning, not colour alone.
struct DayDot: View {
    let day: Wire.HistoryDay
    let isToday: Bool

    var body: some View {
        ZStack {
            if !day.scheduled {
                Circle().strokeBorder(Tok.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            } else if day.done {
                Circle().fill(Tok.accent)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Tok.onAccent)
            } else if day.count > 0 {
                Circle().strokeBorder(Tok.hairline, lineWidth: 2)
                Circle().trim(from: 0, to: Double(day.count) / Double(max(day.target, 1))).stroke(Tok.accent, lineWidth: 3).rotationEffect(.degrees(-90))
            } else {
                Circle().strokeBorder(isToday ? Tok.accent : Tok.hairline, lineWidth: isToday ? 2 : 1.5)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityElement().accessibilityLabel(RoutineDetailView.describe(day))
    }
}
