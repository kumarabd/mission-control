import SwiftUI
import ClerkKit

struct AssistantPresence: View {
    let ambient: Bool
    var diameter: CGFloat = 88
    var voiceState: AssistantVoiceCoordinator.State = .idle
    var onVoiceTap: () -> Void = {}
    var onCapture: () -> Void = {}
    var onAttach: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasArrived = false
    private var isListening: Bool {
        voiceState == .preparing || voiceState == .listening || voiceState == .processing
    }
    private var isSpeaking: Bool { voiceState == .speaking }
    private var isActive: Bool { isListening || isSpeaking }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                Button(action: onVoiceTap) {
                    ZStack {
                        Circle().fill(RadialGradient(colors: [MissionTheme.tint.opacity(0.16), MissionTheme.tint.opacity(0.02), .clear],
                                                     center: .center, startRadius: 0, endRadius: diameter / 2))
                            .scaleEffect(hasArrived ? 1 : 0.72)
                            .opacity(hasArrived ? 1 : 0)
                        Circle().stroke(MissionTheme.line, lineWidth: 1)
                        animatedRings
                        sensingWaves
                        thoughtSparks
                        animatedWaveform
                    }
                    .frame(width: diameter, height: diameter).accessibilityHidden(true)
                }
                .buttonStyle(MissionPressStyle())
                .accessibilityLabel(voiceAccessibilityLabel)
                .accessibilityHint(voiceAccessibilityHint)

                HStack(spacing: 8) {
                    Button(action: onCapture) { Image(systemName: "camera.viewfinder") }
                        .accessibilityLabel("Scan with camera")
                    Button(action: onAttach) { Image(systemName: "paperclip") }
                        .accessibilityLabel("Attach image or PDF")
                }
                .font(.mission(.callout, .semibold)).foregroundStyle(MissionTheme.ink)
                .padding(.horizontal, 10).frame(minHeight: 44)
                .background(.thinMaterial, in: Capsule())
                .overlay { Capsule().stroke(MissionTheme.line) }
                .offset(y: 20)
            }
            .padding(.bottom, 20)
            Text(voiceStatus)
                .font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { hasArrived = true; return }
            withAnimation(.spring(response: 0.72, dampingFraction: 0.72)) { hasArrived = true }
        }
    }
    private var voiceStatus: String {
        switch voiceState {
        case .idle: "Tap to speak"
        case .preparing: "Preparing voice"
        case .listening: "Listening"
        case .processing: "Thinking"
        case .speaking: "Speaking"
        case .unavailable: "Voice unavailable · tap to retry"
        }
    }
    private var voiceAccessibilityLabel: String { "Assistant. \(voiceStatus)" }
    private var voiceAccessibilityHint: String {
        isActive ? "Double tap to end the conversation." : "Double tap to start a conversation."
    }
    private var rings: some View {
        ZStack {
            RoundedRectangle(cornerRadius: diameter * 0.32).stroke(MissionTheme.tint.opacity(0.7), lineWidth: 1)
                .frame(width: diameter * 0.68, height: diameter * 0.68).rotationEffect(.degrees(28))
            RoundedRectangle(cornerRadius: diameter * 0.27).stroke(MissionTheme.tint.opacity(0.35), lineWidth: 1)
                .frame(width: diameter * 0.57, height: diameter * 0.61).rotationEffect(.degrees(64))
        }
    }

    @ViewBuilder private var animatedRings: some View {
        if !ambient || reduceMotion {
            rings
        } else {
            switch voiceState {
            case .listening:
                rings.phaseAnimator([false, true]) { content, phase in
                    content.scaleEffect(phase ? 1.09 : 0.94).rotationEffect(.degrees(phase ? 7 : -3))
                } animation: { _ in .easeInOut(duration: 0.9) }
            case .processing:
                rings.phaseAnimator([false, true]) { content, phase in
                    content.rotationEffect(.degrees(phase ? 38 : 0)).scaleEffect(phase ? 0.98 : 1.04)
                } animation: { _ in .easeInOut(duration: 1.45) }
            case .speaking:
                rings.phaseAnimator([false, true]) { content, phase in
                    content.scaleEffect(phase ? 1.06 : 0.98).rotationEffect(.degrees(phase ? 5 : -5))
                } animation: { _ in .easeInOut(duration: 0.42) }
            case .preparing:
                rings.phaseAnimator([false, true]) { content, phase in
                    content.scaleEffect(phase ? 1.03 : 0.82).opacity(phase ? 1 : 0.45)
                } animation: { _ in .easeOut(duration: 0.38) }
            case .idle, .unavailable:
                rings
            }
        }
    }

    @ViewBuilder private var sensingWaves: some View {
        if voiceState == .listening, ambient, !reduceMotion {
            Circle().stroke(MissionTheme.tint.opacity(0.45), lineWidth: 1)
                .phaseAnimator([false, true]) { wave, phase in
                    wave.scaleEffect(phase ? 1.18 : 0.76).opacity(phase ? 0 : 0.72)
                } animation: { _ in .easeOut(duration: 1.1) }
            Circle().stroke(MissionTheme.tint.opacity(0.25), lineWidth: 1)
                .phaseAnimator([false, true]) { wave, phase in
                    wave.scaleEffect(phase ? 1.08 : 0.82).opacity(phase ? 0 : 0.5)
                } animation: { _ in .easeOut(duration: 1.1).delay(0.42) }
        }
    }

    @ViewBuilder private var thoughtSparks: some View {
        if voiceState == .processing, ambient, !reduceMotion {
            ForEach(0..<3) { index in
                Circle().fill(MissionTheme.tint)
                    .frame(width: max(3, diameter * 0.035), height: max(3, diameter * 0.035))
                    .offset(x: (index - 1) == 0 ? 0 : CGFloat(index - 1) * diameter * 0.18,
                            y: -diameter * 0.23)
                    .phaseAnimator([false, true]) { spark, phase in
                        spark.opacity(phase ? 1 : 0.22).scaleEffect(phase ? 1.15 : 0.68)
                    } animation: { _ in .easeInOut(duration: 0.55).delay(Double(index) * 0.15) }
            }
        }
    }

    private var animatedWaveform: some View {
        HStack(spacing: max(4, diameter * 0.035)) {
            ForEach(0..<5) { index in
                let width = max(3, diameter * 0.018)
                if ambient && !reduceMotion && isActive {
                    Capsule().fill(MissionTheme.tint)
                        .phaseAnimator([false, true]) { bar, phase in
                            bar.frame(width: width, height: waveHeight(for: index, phase: phase) * diameter / 88)
                        } animation: { _ in .easeInOut(duration: waveDuration(for: index)) }
                } else {
                    Capsule().fill(MissionTheme.tint)
                        .frame(width: width, height: waveHeight(for: index, phase: true) * diameter / 88)
                }
            }
        }
    }

    private func waveHeight(for index: Int, phase: Bool) -> CGFloat {
        switch voiceState {
        case .listening:
            return phase ? CGFloat(16 + (index % 3) * 9) : CGFloat(6 + (index % 2) * 4)
        case .processing:
            return phase ? (index == 2 ? 25 : 10) : (index == 2 ? 13 : 6)
        case .speaking:
            return phase ? CGFloat(15 + ((index * 7 + 5) % 4) * 8) : CGFloat(7 + ((index + 1) % 3) * 5)
        case .preparing:
            return phase ? CGFloat(10 + (index % 3) * 5) : 5
        case .idle, .unavailable:
            return 5
        }
    }

    private func waveDuration(for index: Int) -> Double {
        switch voiceState {
        case .speaking: 0.24 + Double(index) * 0.06
        case .listening: 0.40 + Double(index) * 0.08
        case .processing: 0.58 + Double(index) * 0.05
        case .preparing: 0.32 + Double(index) * 0.07
        case .idle, .unavailable: 0.5
        }
    }
}

struct DashboardSettings: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Clerk.self) private var clerk
    @Binding var appearance: String
    @Binding var ambientMotion: Bool
    @AppStorage(MissionVoiceProfile.selectedVoiceDefaultsKey) private var selectedVoiceIdentifier = ""
    @StateObject private var speechCapabilityProbe = SpeechCapabilityProbe()
    @State private var authenticationInProgress = false
    @State private var authenticationError: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker(selection: $appearance) {
                        Text("Graphite").tag("graphite")
                        Text("Pearl").tag("pearl")
                        Text("Follow system").tag("system")
                    } label: {
                        Label("Theme", systemImage: "paintpalette").foregroundStyle(MissionTheme.scheduled)
                    }
                }
                Section {
                    Toggle(isOn: $ambientMotion) {
                        Label("Ambient animation", systemImage: "waveform").foregroundStyle(MissionTheme.telemetry)
                    }
                } footer: {
                    Text("Gentle assistant movement. Animations pause when you open a space or leave the app, and respect Reduce Motion.")
                }
                Section("Voice") {
                    LabeledContent("Response style", value: MissionVoiceProfile.responseStyle)
                    LabeledContent("Delivery", value: MissionVoiceProfile.delivery)
                    Picker("Voice", selection: $selectedVoiceIdentifier) {
                        Text("Automatic · natural female").tag("")
                        ForEach(MissionVoiceProfile.selectableVoices, id: \.identifier) { voice in
                            Text(MissionVoiceProfile.optionLabel(for: voice)).tag(voice.identifier)
                        }
                    }
                    LabeledContent("In use", value: MissionVoiceProfile.selectedVoiceDescription)
                    Text(MissionVoiceProfile.voiceAvailabilityDetail)
                        .font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
                }
                Section {
                    NavigationLink {
                        SpeechCapabilityProbeView(probe: speechCapabilityProbe)
                    } label: {
                        LabeledContent("Capability probe", value: speechCapabilityProbe.summary)
                    }
                } header: {
                    Text("On-device speech")
                } footer: {
                    Text("Read-only. Checking does not request access, use the microphone, or download a language model.")
                }
                Section {
                    if let user = clerk.user {
                        LabeledContent("Status", value: "Signed in")
                        LabeledContent("Account", value: accountLabel(for: user))
                        Button("Sign out", role: .destructive, action: signOut)
                            .disabled(authenticationInProgress)
                    } else {
                        Button(action: signInWithGoogle) {
                            Label("Continue with Google", systemImage: "g.circle.fill")
                        }
                        .disabled(!ClerkConfiguration.isConfigured || authenticationInProgress)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if ClerkConfiguration.isConfigured {
                        Text("Your Clerk session is stored securely on this device and can authenticate future agent-gateway requests.")
                    } else {
                        Text("Set CLERK_PUBLISHABLE_KEY in the app target to enable Google sign-in.")
                    }
                }
                Section("Visual language") {
                    ForEach(MissionTone.allCases) { tone in
                        HStack {
                            MissionIconBadge(symbol: tone.symbol, color: tone.color)
                            Text(tone.label)
                        }
                    }
                }
                Section("Connections") {
                    Text("Tasks are saved on this device. The assistant sends only transcribed text to the remote gateway and speaks streamed replies through this device. Repositories, weather, reminders, calendar, garage, pantry, wardrobe, and system readings are samples.")
                        .font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
                }
            }
            .scrollContentBackground(.hidden).background(MissionTheme.canvas)
            .navigationTitle("Dashboard")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await speechCapabilityProbe.refresh() }
        }
        .tint(MissionTheme.tint)
        .presentationDragIndicator(.visible)
        .alert("Account action couldn’t be completed", isPresented: Binding(get: { authenticationError != nil }, set: { if !$0 { authenticationError = nil } })) {
            Button("OK") { authenticationError = nil }
        } message: {
            Text(authenticationError ?? "Please try again.")
        }
    }

    private func accountLabel(for user: User) -> String {
        let name = [user.firstName, user.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? (user.primaryEmailAddress?.emailAddress ?? user.id) : name
    }

    private func signInWithGoogle() {
        authenticationInProgress = true
        Task {
            defer { authenticationInProgress = false }
            do {
                try await clerk.auth.signInWithOAuth(provider: .google)
            } catch {
                authenticationError = error.localizedDescription
            }
        }
    }

    private func signOut() {
        authenticationInProgress = true
        Task {
            defer { authenticationInProgress = false }
            do {
                try await clerk.auth.signOut()
            } catch {
                authenticationError = error.localizedDescription
            }
        }
    }
}

private struct SpeechCapabilityProbeView: View {
    @ObservedObject var probe: SpeechCapabilityProbe

    var body: some View {
        List {
            Section("Access") {
                LabeledContent("Requested locale", value: probe.snapshot.requestedLocale)
                LabeledContent("Microphone", value: probe.snapshot.microphonePermission)
            }

            capabilitySection("SpeechTranscriber", capability: probe.snapshot.speechTranscriber)

            Section("Recommended path") {
                Text(probe.snapshot.recommendation)
            }

            Section {
                Button {
                    Task { await probe.refresh() }
                } label: {
                    Label("Refresh capabilities", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(probe.isRefreshing)
            } footer: {
                Text("This screen reports compatibility and model state only. The on-device model installs when you start voice for the first time.")
            }
        }
        .navigationTitle("Speech diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if probe.isRefreshing && probe.snapshot == .checking {
                ProgressView("Checking device")
            }
        }
    }

    private func capabilitySection(
        _ title: String,
        capability: SpeechCapabilityProbe.Capability
    ) -> some View {
        Section(title) {
            LabeledContent("Availability", value: capability.availability)
            LabeledContent("Matched locale", value: capability.locale)
            LabeledContent("Model", value: capability.model)
        }
    }
}
