import SwiftUI

/// Makes a routine in the Life Engine: what, how many times a day, when to be nudged, on which days, and an easier version for
/// hard days. A routine is a behaviour to keep up, not a one-off reminder.
struct NewRoutineSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var perDay = 1
    @State private var cues: [Date] = [NewRoutineSheet.time(9, 0)]
    @State private var cuesEdited = false
    @State private var days: Set<Int> = []
    @State private var minutes = 10
    @State private var shortTitle = ""
    @State private var shortMinutes = 2
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What") { TextField("e.g. Drink water", text: $title) }
                Section {
                    Stepper("\(perDay) \(perDay == 1 ? "time" : "times") a day", value: $perDay, in: 1...12)
                } header: { Text("How often") }
                Section {
                    ForEach(cues.indices, id: \.self) { i in
                        HStack {
                            DatePicker("Nudge \(i + 1)", selection: Binding(get: { cues[i] }, set: { cues[i] = $0; cuesEdited = true }), displayedComponents: .hourAndMinute)
                            if cues.count > 1 { Button { cues.remove(at: i); cuesEdited = true } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("Remove nudge \(i + 1)") }
                        }
                    }
                    if cues.count < 8 { Button("Add a nudge", systemImage: "plus") { cues.append(Self.time(12, 0)); cuesEdited = true } }
                } header: { Text("Nudge me at") } footer: { Text("A nudge only speaks up if you haven't reached your count yet.") }
                Section("On these days") {
                    HStack {
                        ForEach(0..<7, id: \.self) { d in
                            Chip(title: Calendar.current.veryShortWeekdaySymbols[d], selected: days.contains(d)) { if days.contains(d) { days.remove(d) } else { days.insert(d) } }
                        }
                    }
                    Text(days.isEmpty ? "Every day" : RoutineDetailView.weekdays(Array(days))).font(.mission(.footnote)).foregroundStyle(Tok.muted)
                }
                Section {
                    TextField("e.g. One glass", text: $shortTitle)
                    Stepper("\(shortMinutes) minutes", value: $shortMinutes, in: 1...30)
                } header: { Text("Busy-day version") } footer: { Text("Something small enough to do on your worst day.") }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("New routine").navigationBarTitleDisplayMode(.inline)
            .onChange(of: perDay) { _, n in if !cuesEdited { cues = Self.spread(n) } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saving = true
                        Task {
                            let ok = await life.addRoutine(title: title.trimmed, targetPerDay: perDay, cues: Self.hhmm(cues), weekdays: days.sorted(),
                                                           shortTitle: shortTitle.trimmed, minutes: minutes, shortMinutes: shortMinutes)
                            saving = false
                            if ok { dismiss() }
                        }
                    } label: { if saving { ProgressView() } else { Text("Add") } }
                    .disabled(title.trimmed.isEmpty || saving)
                }
            }
        }
        .presentationDetents([.large])
    }

    static func time(_ h: Int, _ m: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date() }

    /// n nudges spread across the waking day, 9 to 5 for the first and last.
    static func spread(_ n: Int) -> [Date] {
        guard n > 1 else { return [time(9, 0)] }
        return (0..<min(n, 8)).map { i in time(9 + (8 * i) / (min(n, 8) - 1), 0) }
    }

    /// "HH:mm" in 24-hour form, which is what the engine takes, sorted and without duplicates.
    static func hhmm(_ dates: [Date]) -> [String] {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"
        return Array(Set(dates.map(f.string(from:)))).sorted()
    }
}
