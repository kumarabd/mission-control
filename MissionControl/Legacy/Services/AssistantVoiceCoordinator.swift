import AVFAudio
import Combine
import CoreMedia
import Foundation
import Speech
import UIKit

/// Voice selection and delivery for assistant responses received from the gateway.
enum MissionVoiceProfile {
    static let responseStyle = "Playful"
    static let delivery = "Energetic and direct"
    static let selectedVoiceDefaultsKey = "missionSelectedVoiceIdentifier"

    static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let identifier = UserDefaults.standard.string(forKey: selectedVoiceDefaultsKey),
           let selected = voices.first(where: { $0.identifier == identifier }) {
            return selected
        }
        let ranked = voices.sorted { score($0) > score($1) }
        return ranked.first
    }

    static var selectableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.gender == .female && $0.language.lowercased().hasPrefix("en") }
            .sorted { score($0) > score($1) }
    }

    static var selectedVoiceDescription: String {
        guard let voice = preferredVoice() else { return "No system voice available" }
        return "\(voice.name) · \(qualityLabel(for: voice))"
    }

    static var voiceAvailabilityDetail: String {
        guard let voice = preferredVoice() else {
            return "No system voice is available right now."
        }
        if voice.gender == .female && voice.language.lowercased().hasPrefix("en-in") {
            return "Using a feminine Indian-English voice."
        }
        if voice.gender == .female && voice.language.lowercased().hasPrefix("en") {
            return "Using a feminine English system voice. Download an Enhanced or Premium voice in iOS Settings for a more natural sound."
        }
        return "No feminine English voice is installed. Add one in iPad or iPhone Settings, then reopen Mission Control."
    }

    private static func score(_ voice: AVSpeechSynthesisVoice) -> Int {
        let language = voice.language.lowercased()
        let isIndianEnglish = language.hasPrefix("en-in")
        let isEnglish = language.hasPrefix("en")
        let isFemale = voice.gender == .female
        let quality: Int
        switch voice.quality {
        case .premium: quality = 1_000
        case .enhanced: quality = 500
        default: quality = 100
        }
        // Gender is the primary preference. Among feminine English voices, natural
        // quality matters more than locale: a Premium voice is normally far less
        // robotic than a compact regional voice. The person can always choose a
        // specific downloaded voice in Settings.
        let genderScore = isFemale ? 10_000 : 0
        let languageScore = isIndianEnglish ? 20 : isEnglish ? 10 : 0
        return genderScore + languageScore + quality
    }

    static func optionLabel(for voice: AVSpeechSynthesisVoice) -> String {
        "\(voice.name) · \(voice.language) · \(qualityLabel(for: voice))"
    }

    private static func qualityLabel(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "Premium"
        case .enhanced: "Enhanced"
        default: "Standard"
        }
    }
}

/// Device-owned offline STT and TTS. Capture, playback and the gateway turn
/// have separate lifecycles: microphone energy never cancels an assistant reply.
@MainActor
final class AssistantVoiceCoordinator: NSObject, ObservableObject {
    enum State: Equatable { case idle, preparing, listening, processing, speaking, unavailable }
    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var message = ""
    @Published private(set) var progressNarration = ""
    @Published private(set) var conversationText = VoiceConversationText()

    private var flow = VoiceInteractionPolicy()
    private var gate = VoiceSpeechGate()
    private let audioEngine = AVAudioEngine()
    private let captureSink = AVAudioSinkNode { _, _, _ in noErr }
    private let audioRouter = SpeechAnalyzerAudioRouter()
    private let ttsPlayback = TTSPlaybackNode()
    private let playsStartupCue: Bool
    private let synthesizer = AVSpeechSynthesizer()
    // No saved resume position: it is one number for the whole app, and when it is ahead of this session's turn numbers the
    // gateway skips the very turn we just started. Replayed history is ignored by `historyLoaded` below.
    private let gateway = MobileGateway(usesResumeCursor: false, humanOnly: true, streams: false)
    private var speechLocale: Locale?
    private var captureFormat: AVAudioFormat?
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var recognitionTask: Task<Void, Never>?
    private var analysisFinalizationTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var transcriptSegments = [SpeechAnalyzerTranscriptSegment]()
    private var recognitionGeneration = 0
    private var requestedFinish = false
    private var requestStartedAt: TimeInterval = 0
    private var finishRequestedAt: TimeInterval?
    private var lastAudioDiagnosticAt: TimeInterval = 0
    private var captureTick: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var recognitionFailures = 0
    private var tapInstalled = false
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var engineConfigurationObserver: NSObjectProtocol?
    private var backgroundPaused = false
    private var preparingVoice = false
    private var audioRecoveryTask: Task<Void, Never>?
    private var playbackStartTask: Task<Void, Never>?
    private var audioRecoveryInProgress = false
    private var playbackRecoveryAttempts = 0

    // Only one utterance is handed to AVSpeechSynthesizer at a time.
    // Invalidating its identity before stop makes late delegate events harmless.
    private var activeUtterance: AVSpeechUtterance?
    private var activeWordOffset = 0
    private var queuedSpeech = [String]()
    private var recentPlayback = [(id: ObjectIdentifier, text: String, time: TimeInterval)]()
    private var recognitionPlayback = [ObjectIdentifier: String]()
    private var historyLoaded = false
    private var activeTurnSequence: Int?
    private var suppressStreamingSpeech = false
    private var streamBuffer = ""
    private var speechBuffer = ""
    // The durable assistant-message frame is a fallback speech source for
    // follow-ups which arrive without a token stream.
    private var pendingAssistantMessageSpeech: (turn: Int, content: String)?
    private var pendingUserMessages = Set<String>()
    private var pendingQuestion: MobileGateway.GatewayQuestion?

    init(playsStartupCue: Bool = true) {
        self.playsStartupCue = playsStartupCue
        super.init()
        gateway.onEvent = { [weak self] event in self?.handleGatewayEvent(event) }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor [weak self] in self?.cancel() }
        }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            Task { @MainActor [weak self] in self?.handleAudioRouteChange(reason) }
        }
        engineConfigurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            // Apple posts this from an internal queue. Rebuild on the main
            // actor, rather than tearing down the engine in this callback.
            Task { @MainActor [weak self] in
                self?.requestAudioRecovery(reason: "audio engine configuration changed")
            }
        }
    }

    deinit {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        if let routeChangeObserver { NotificationCenter.default.removeObserver(routeChangeObserver) }
        if let engineConfigurationObserver { NotificationCenter.default.removeObserver(engineConfigurationObserver) }
    }

    /// Hands-free continuation is opt-out: an active, user-started conversation
    /// remains in the app's declared background-audio session when the user
    /// switches apps or locks the device. It never starts the microphone by
    /// itself; ending the conversation always releases capture and playback.
    func updateGatewayAppActivity(_ isActive: Bool, handsFreeEnabled: Bool = true) {
        let shouldKeepAudioActive = isActive || (handsFreeEnabled && flow.active)

        if shouldKeepAudioActive {
            gateway.setAppActive(true)
            if backgroundPaused { backgroundPaused = false; start() }
        } else if flow.active {
            backgroundPaused = true
            pauseAudioForBackground()
            gateway.setAppActive(false)
        } else {
            gateway.setAppActive(false)
        }
    }

    func toggle() {
        if backgroundPaused { backgroundPaused = false; start(); return }
        flow.active ? cancel() : start()
    }

    func cancel() {
        backgroundPaused = false
        preparingVoice = false
        UIApplication.shared.isIdleTimerDisabled = false
        flow.stop() // Invalidate the session BEFORE stopping any asynchronous producer.
        startupTask?.cancel(); startupTask = nil
        captureTick?.cancel(); captureTick = nil
        retryTask?.cancel(); retryTask = nil
        audioRecoveryTask?.cancel(); audioRecoveryTask = nil
        playbackStartTask?.cancel(); playbackStartTask = nil
        audioRecoveryInProgress = false
        closeRecognition(cancel: true)
        audioEngine.stop()
        if tapInstalled { audioEngine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        captureFormat = nil
        audioRouter.clear()
        stopSpeechPlayback()
        clearProgressNarration()
        recentPlayback.removeAll()
        recognitionPlayback.removeAll()
        pendingUserMessages.removeAll()
        conversationText = VoiceConversationText()
        pendingQuestion = nil
        questionTurnSequence = nil
        activeTurnSequence = nil
        suppressStreamingSpeech = false
        historyLoaded = false
        transcript = ""; message = ""
        gateway.endInteraction()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Task { await SpeechModels.endRetention() }
        refreshState()
        log("conversation stopped")
    }

    func presentAttachmentPayload(_ payload: String) {
        cancel()
        transcript = payload; message = payload
    }

    /// Everything cancel() does to hardware, none of what it does to the turn:
    /// activeTurnSequence, conversationText, pendingUserMessages and the gateway
    /// interaction all survive so a reply that lands while backgrounded is still
    /// attributable when audio resumes.
    private func pauseAudioForBackground() {
        startupTask?.cancel(); startupTask = nil
        captureTick?.cancel(); captureTick = nil
        retryTask?.cancel(); retryTask = nil
        audioRecoveryTask?.cancel(); audioRecoveryTask = nil
        playbackStartTask?.cancel(); playbackStartTask = nil
        audioRecoveryInProgress = false
        closeRecognition(cancel: true)
        audioEngine.stop()
        if tapInstalled { audioEngine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        captureFormat = nil
        audioRouter.clear()
        stopSpeechPlayback()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        log("audio paused for background")
    }

    private func handleAudioRouteChange(_ reason: AVAudioSession.RouteChangeReason?) {
        guard flow.active, !backgroundPaused, !preparingVoice else { return }
        let detail = reason.map { String(describing: $0) } ?? "unknown"
        requestAudioRecovery(reason: "audio route changed: \(detail)")
    }

    /// AVAudioEngine stops and uninitializes itself when I/O hardware changes.
    /// Preserve unread TTS before rebuilding the shared capture/playback graph so
    /// the gateway reply stays audible instead of merely visible as text.
    private func requestAudioRecovery(reason: String) {
        guard flow.active, !backgroundPaused, !preparingVoice,
              !flow.paused, !audioRecoveryInProgress
        else { return }
        audioRecoveryInProgress = true
        playbackStartTask?.cancel(); playbackStartTask = nil
        retainUnreadSpeechForRecovery()
        refreshState()
        closeRecognition(cancel: true)
        resetAudioGraphConnections()
        let epoch = flow.generation
        log("audio recovery requested: \(reason)")
        audioRecoveryTask = Task { [weak self] in
            guard let self else { return }
            defer {
                audioRecoveryTask = nil
                audioRecoveryInProgress = false
            }
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                try await Task.sleep(for: .milliseconds(120))
                guard flow.accepts(epoch), !Task.isCancelled else { return }
                try await startAudio(epoch: epoch)
                guard flow.accepts(epoch), !Task.isCancelled else { return }
                try await beginRecognition()
                startCaptureTick(epoch: epoch)
                playNext()
                refreshState()
                log("audio recovery completed")
            } catch {
                guard flow.accepts(epoch), !Task.isCancelled else { return }
                fail("Voice playback stopped after an audio-route change. Tap to try again.")
            }
        }
    }

    private func retainUnreadSpeechForRecovery() {
        if let utterance = activeUtterance {
            let fullText = utterance.speechString as NSString
            let offset = min(activeWordOffset, fullText.length)
            let tail = fullText.substring(from: offset).trimmingCharacters(in: .whitespacesAndNewlines)
            activeUtterance = nil
            if !tail.isEmpty { queuedSpeech.insert(tail, at: 0) }
        }
        flow.playing = false
        synthesizer.stopSpeaking(at: .immediate)
        ttsPlayback.stop()
    }

    private func resetAudioGraphConnections() {
        audioEngine.stop()
        let input = audioEngine.inputNode
        if tapInstalled {
            input.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.disconnectNodeOutput(input)
        audioEngine.disconnectNodeInput(captureSink)
        audioEngine.disconnectNodeOutput(ttsPlayback.node)
        captureFormat = nil
        audioRouter.clear()
        ttsPlayback.resetGraphState()
    }

    private func start() {
        flow.start()
        preparingVoice = true
        // A hands-free conversation has no touch input to keep the screen awake
        // for, so iOS's normal auto-lock fires mid-turn unless told otherwise.
        UIApplication.shared.isIdleTimerDisabled = true
        refreshState()
        let epoch = flow.generation
        startupTask?.cancel()
        startupTask = Task { [weak self] in
            guard let self else { return }
            let granted = await AVAudioApplication.requestRecordPermission()
            guard flow.accepts(epoch) else { return }
            guard granted else {
                fail("Microphone permission is required for on-device speech."); return
            }
            do {
                speechLocale = try await prepareOnDeviceSpeechModel()
                guard flow.accepts(epoch), !Task.isCancelled else { return }
                try await startAudio(epoch: epoch)
                if playsStartupCue {
                    ttsPlayback.playStartupCue()
                    try await Task.sleep(for: .milliseconds(260))
                    guard flow.accepts(epoch), !Task.isCancelled else { return }
                }
                recognitionFailures = 0
                try await beginRecognition()
                preparingVoice = false
                gateway.beginInteraction()
                startCaptureTick(epoch: epoch)
                refreshState()
            } catch {
                log("start failed \((error as NSError).domain):\((error as NSError).code)")
                guard flow.accepts(epoch), !Task.isCancelled else { return }
                fail("I couldn’t prepare on-device speech. Check the connection once so its language model can install, then try again.")
            }
        }
    }

    private func fail(_ reason: String) {
        cancel()
        message = reason
        state = .unavailable
    }

    private func refreshState() {
        if flow.active, preparingVoice {
            state = .preparing
            return
        }
        switch flow.status {
        case .idle: state = .idle
        case .listening: state = .listening
        case .thinking: state = .processing
        case .speaking: state = .speaking
        }
    }

    private func log(_ event: String) {
        #if DEBUG
        print("[MissionVoice] \(event)")
        #endif
    }

    private func prepareOnDeviceSpeechModel() async throws -> Locale {
        guard SpeechTranscriber.isAvailable else {
            throw SpeechInputError.onDeviceRecognitionUnavailable
        }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            throw SpeechInputError.unsupportedLocale
        }

        let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        let initialStatus = await AssetInventory.status(forModules: [module])
        if initialStatus != .installed {
            log("installing SpeechTranscriber model locale=\(locale.identifier) status=\(String(describing: initialStatus))")
            guard let installation = try await AssetInventory.assetInstallationRequest(supporting: [module]) else {
                throw SpeechInputError.modelInstallationFailed
            }
            try await installation.downloadAndInstall()
        }
        guard await AssetInventory.status(forModules: [module]) == .installed else {
            throw SpeechInputError.modelInstallationFailed
        }
        log("SpeechTranscriber model ready locale=\(locale.identifier)")
        return locale
    }

    private func startAudio(epoch: Int) async throws {
        #if targetEnvironment(simulator)
        throw SpeechInputError.microphoneUnavailable
        #else
        let session = AVAudioSession.sharedInstance()
        let input = audioEngine.inputNode

        for attempt in 1...2 {
            if attempt > 1 {
                // The first enablement of voice-processing I/O can finish an
                // asynchronous graph change after start() returns and leave the
                // engine stopped. Recreate the same audio activation locally;
                // this is the restart that previously required a second tap.
                audioEngine.stop()
                if tapInstalled {
                    input.removeTap(onBus: 0)
                    tapInstalled = false
                }
                captureFormat = nil
                audioRouter.clear()
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                try await Task.sleep(for: .milliseconds(120))
                guard flow.accepts(epoch), !Task.isCancelled else {
                    throw CancellationError()
                }
            }

            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true)
            try AVAudioApplication.shared.setInputMuted(false)

            // The playback graph must exist before voice processing is enabled,
            // so the I/O unit has a render reference for acoustic echo control.
            ttsPlayback.attachIfNeeded(to: audioEngine)
            try input.setVoiceProcessingEnabled(true)
            input.isVoiceProcessingInputMuted = false
            input.voiceProcessingOtherAudioDuckingConfiguration = .init(
                enableAdvancedDucking: false,
                duckingLevel: .min
            )
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw SpeechInputError.microphoneUnavailable
            }
            captureFormat = format

            // The terminal sink keeps processed input rendered but has no path to
            // the speaker. The input tap independently forwards PCM to STT.
            if captureSink.engine == nil { audioEngine.attach(captureSink) }
            audioEngine.connect(input, to: captureSink, format: format)
            let router = audioRouter
            input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
                router.append(buffer)
            }
            tapInstalled = true
            ttsPlayback.connect(in: audioEngine)
            audioEngine.isAutoShutdownEnabled = false
            audioEngine.prepare()
            try audioEngine.start()

            // Let iOS finish the initial voice-processing graph transition before
            // accepting this activation as healthy.
            try await Task.sleep(for: .milliseconds(180))
            guard flow.accepts(epoch), !Task.isCancelled else {
                throw CancellationError()
            }
            if audioEngine.isRunning {
                let inputRoute = session.currentRoute.inputs
                    .map { "\($0.portType.rawValue):\($0.portName)" }
                    .joined(separator: ",")
                log("capture started attempt=\(attempt) engine=true voiceProcessing=\(input.isVoiceProcessingEnabled) route=\(inputRoute)")
                return
            }
            log("capture graph stopped during activation attempt=\(attempt)")
        }

        throw SpeechInputError.audioEngineStopped
        #endif
    }

    private func beginRecognition() async throws {
        guard flow.active, let speechLocale, let captureFormat else {
            throw SpeechInputError.onDeviceRecognitionUnavailable
        }

        recognitionGeneration &+= 1
        let generation = recognitionGeneration
        let epoch = flow.generation
        let currentTranscriber = SpeechTranscriber(
            locale: speechLocale,
            preset: .progressiveTranscription
        )
        let modules: [any SpeechModule] = [currentTranscriber]
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: modules,
            considering: captureFormat
        ) else {
            throw SpeechInputError.analyzerFormatUnavailable
        }

        let currentAnalyzer = SpeechAnalyzer(
            modules: modules,
            options: .init(priority: .userInitiated, modelRetention: .processLifetime)
        )
        let (inputSequence, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

        requestedFinish = false
        finishRequestedAt = nil
        requestStartedAt = ProcessInfo.processInfo.systemUptime
        lastAudioDiagnosticAt = requestStartedAt
        recentPlayback.removeAll { requestStartedAt - $0.time > 2 }
        recognitionPlayback = Dictionary(
            recentPlayback.map { ($0.id, $0.text) },
            uniquingKeysWith: { _, latest in latest }
        )
        transcriptSegments.removeAll(keepingCapacity: true)
        gate = VoiceSpeechGate()
        transcript = ""
        conversationText.discardDraft()
        transcriber = currentTranscriber
        analyzer = currentAnalyzer

        recognitionTask = Task { [weak self, currentTranscriber] in
            do {
                for try await result in currentTranscriber.results {
                    guard !Task.isCancelled, let self,
                          flow.accepts(epoch), recognitionGeneration == generation
                    else { return }
                    receive(result)
                }
                guard !Task.isCancelled, let self,
                      flow.accepts(epoch), recognitionGeneration == generation,
                      !requestedFinish
                else { return }
                log("SpeechAnalyzer result stream ended unexpectedly")
                recognitionFailed()
            } catch {
                guard !Task.isCancelled, let self,
                      flow.accepts(epoch), recognitionGeneration == generation
                else { return }
                let ns = error as NSError
                log("SpeechAnalyzer error \(ns.domain):\(ns.code) finishing=\(requestedFinish)")
                recognitionFailed()
            }
        }

        audioRouter.install(inputContinuation, analyzerFormat: analyzerFormat)
        do {
            try await currentAnalyzer.start(inputSequence: inputSequence)
        } catch {
            closeRecognition(cancel: true)
            throw error
        }
        log("SpeechAnalyzer started generation=\(generation) input=\(Int(captureFormat.sampleRate))Hz analyzer=\(Int(analyzerFormat.sampleRate))Hz")
        refreshState()
    }

    private func receive(_ result: SpeechTranscriber.Result) {
        let resultText = String(result.text.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        transcriptSegments.removeAll { $0.overlaps(result.range) }
        if !resultText.isEmpty {
            transcriptSegments.append(.init(
                range: result.range,
                text: resultText,
                isFinal: result.isFinal
            ))
        }
        transcript = transcriptSegments
            .sorted { CMTimeCompare($0.range.start, $1.range.start) < 0 }
            .map(\.text)
            .joined(separator: " ")
        let cleaned = SpeechTranscriptCleaner.clean(transcript)
        let now = ProcessInfo.processInfo.systemUptime
        let echo = isPlaybackEcho(cleaned, at: now)
        gate.partial(cleaned, echo: echo, at: now)
        if !echo, !flow.playing, !flow.awaitingResponse {
            conversationText.updateDraft(transcript)
        }
    }

    private func startCaptureTick(epoch: Int) {
        captureTick?.cancel()
        captureTick = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled, let self, flow.accepts(epoch) else { return }
                let now = ProcessInfo.processInfo.systemUptime
                if transcript.isEmpty, now - lastAudioDiagnosticAt >= 2 {
                    lastAudioDiagnosticAt = now
                    let diagnostics = audioRouter.diagnostics()
                    if diagnostics.capturedBuffers == 0 {
                        let session = AVAudioSession.sharedInstance()
                        log("audio route captured=0 engine=\(audioEngine.isRunning) sessionRate=\(Int(session.sampleRate))")
                    }
                }
                for time in audioRouter.takeEnergyTimes() where time >= requestStartedAt {
                    gate.energy(at: time)
                }
                guard recognitionTask != nil else { continue }
                if !requestedFinish {
                    if gate.shouldPause(at: now) { pauseForPotentialBargeIn() }
                    if gate.shouldFinish(at: now) || now - requestStartedAt >= 45 {
                        finishListening()
                    }
                } else if let finishRequestedAt, now - finishRequestedAt >= 2.5 {
                    log("recognition finalization timeout")
                    recognitionFailed()
                }
            }
        }
    }

    private func finishListening() {
        guard flow.active,
              let currentAnalyzer = analyzer,
              let currentResults = recognitionTask,
              !requestedFinish
        else { return }
        requestedFinish = true
        finishRequestedAt = ProcessInfo.processInfo.systemUptime
        let generation = recognitionGeneration
        let epoch = flow.generation
        // End only this analyzer sequence. The engine, AEC and TTS stay alive,
        // while newly captured audio becomes pre-roll for the next sequence.
        audioRouter.finish()
        analysisFinalizationTask?.cancel()
        analysisFinalizationTask = Task { [weak self] in
            do {
                try await currentAnalyzer.finalizeAndFinishThroughEndOfInput()
                await currentResults.value
                guard !Task.isCancelled, let self,
                      flow.accepts(epoch), recognitionGeneration == generation
                else { return }
                recognitionFailures = 0
                submitFinalTranscript()
            } catch {
                guard !Task.isCancelled, let self,
                      flow.accepts(epoch), recognitionGeneration == generation
                else { return }
                let ns = error as NSError
                log("SpeechAnalyzer finalization error \(ns.domain):\(ns.code)")
                recognitionFailed()
            }
        }
        log("SpeechAnalyzer endpoint")
    }

    private func closeRecognition(cancel: Bool) {
        recognitionGeneration &+= 1
        audioRouter.finish()
        recognitionTask?.cancel()
        analysisFinalizationTask?.cancel()
        let oldAnalyzer = analyzer
        recognitionTask = nil
        analysisFinalizationTask = nil
        transcriber = nil
        analyzer = nil
        transcriptSegments.removeAll(keepingCapacity: true)
        requestedFinish = false
        finishRequestedAt = nil
        gate = VoiceSpeechGate()
        if cancel, let oldAnalyzer {
            Task { await oldAnalyzer.cancelAndFinishNow() }
        }
    }

    private func recognitionFailed() {
        let hadCandidate = gate.hasSpeech
        let idleRotation = requestedFinish && !hadCandidate
        closeRecognition(cancel: true)
        resumeAfterFalseBargeIn()
        recognitionFailures = idleRotation ? 0 : recognitionFailures + 1
        // Idle/no-match recognizer rotations are expected; persistent failures
        // while speech is present must not form an unbounded hot restart loop.
        if (hadCandidate && recognitionFailures >= 3) || recognitionFailures >= 5 {
            fail("Offline recognition stopped responding. Tap to try again."); return
        }
        let epoch = flow.generation
        let delay = min(2_000, 200 * recognitionFailures)
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled, let self, flow.accepts(epoch) else { return }
            await restartRecognition()
        }
    }

    private func restartRecognition() async {
        guard flow.active else { return }
        do { try await beginRecognition() }
        catch { fail("I couldn’t keep listening offline. Tap to try again.") }
    }

    private func isPlaybackEcho(_ text: String, at now: TimeInterval) -> Bool {
        // Keep this request's playback references through finalization. A slow
        // final must not turn previously rejected speaker audio into a user turn.
        VoiceSpeechGate.resemblesPlayback(text, playback: Array(recognitionPlayback.values))
    }

    private func pauseForPotentialBargeIn() {
        guard flow.active, !flow.paused, let utterance = activeUtterance else { return }
        let tail = (utterance.speechString as NSString).substring(from: activeWordOffset)
        activeUtterance = nil // didCancel for this object cannot affect the next utterance.
        if !tail.isEmpty { queuedSpeech.insert(tail, at: 0) }
        flow.paused = true
        flow.playing = false
        playbackStartTask?.cancel(); playbackStartTask = nil
        conversationText.updateDraft(transcript)
        synthesizer.stopSpeaking(at: .immediate)
        ttsPlayback.stop()
        refreshState()
        log("barge-in candidate: playback retained")
    }

    private func resumeAfterFalseBargeIn() {
        guard flow.paused else { return }
        flow.paused = false
        log("barge-in rejected: playback resumed")
        playNext()
    }

    private func submitFinalTranscript() {
        guard flow.active else { return }
        let payload = SpeechTranscriptCleaner.clean(transcript)
        let echo = isPlaybackEcho(payload, at: ProcessInfo.processInfo.systemUptime)
        closeRecognition(cancel: false)
        guard !payload.isEmpty, !echo else {
            log("final rejected empty=\(payload.isEmpty) echo=\(echo)")
            resumeAfterFalseBargeIn()
            Task { await restartRecognition() }
            return
        }
        stopSpeechPlayback()
        clearProgressNarration()
        suppressStreamingSpeech = true
        activeTurnSequence = nil
        flow.awaitingResponse = true
        message = transcript
        conversationText.acceptUser(transcript)
        refreshState()
        if let question = pendingQuestion {
            suppressStreamingSpeech = false // Answers continue the existing gateway turn.
            activeTurnSequence = questionTurnSequence
            sendAnswer(to: question, transcript: payload)
            pendingQuestion = nil
        } else {
            pendingUserMessages.insert(gateway.sendMessage(payload))
        }
        log("final submitted characters=\(payload.count)")
        Task { await restartRecognition() }
    }

    private var questionTurnSequence: Int?

    /// True when a frame belongs to the turn we are actively mid-conversation on
    /// in this app session, as opposed to backlog replayed after a fresh connect.
    /// A transient reconnect (network blip, ping timeout) resets historyLoaded to
    /// false on the client the instant reconnection starts, before the server has
    /// any chance to say so — without this, the reply to whatever we're already
    /// waiting on would be treated as unspoken history if it streams in mid-reconnect,
    /// which is how a delayed task's answer went missing until the mic was tapped again.
    private func isLiveTurnEvent(_ event: MobileGateway.Event) -> Bool {
        guard flow.awaitingResponse, let activeTurnSequence else { return false }
        switch event {
        case .turnStarted(let turn): return turn == activeTurnSequence
        case .delta(let turn, _, _, _): return turn == activeTurnSequence
        case .message(let turn, _, _, _, _): return turn == activeTurnSequence
        case .status(let turn, _): return turn == activeTurnSequence
        case .turnEnded(let turn, _): return turn == activeTurnSequence
        case .askUser: return true
        case .synchronizing, .historyLoaded, .error, .history, .retract: return false
        }
    }

    private func handleGatewayEvent(_ event: MobileGateway.Event) {
        guard flow.active else { return }
        if !historyLoaded, !isLiveTurnEvent(event) {
            switch event {
            case .synchronizing: return
            case .historyLoaded: historyLoaded = true; return
            case let .message(turn, _, role, content, clientMessageID):
                if let clientMessageID, pendingUserMessages.remove(clientMessageID) != nil {
                    suppressStreamingSpeech = false
                    beginAssistantTurn(turn)
                } else if role == "assistant", activeTurnSequence == turn {
                    conversationText.updateAssistant(content)
                }
                return
            case let .turnEnded(turn, _) where activeTurnSequence == turn:
                flow.awaitingResponse = false
                refreshState()
                return
            case .error(let error): fail(error); return
            default: return // Replayed history never enters TTS.
            }
        }
        switch event {
        case .synchronizing:
            historyLoaded = false
        case .historyLoaded:
            historyLoaded = true
        case .history, .retract:
            break    // the text chat's: it pages through older messages and asks for only what is for the person
        case .turnStarted(let turn):
            // While a new user frame is pending, accept only its canonical
            // acknowledgement below; an older in-flight turn must not speak.
            guard !suppressStreamingSpeech else { return }
            beginAssistantTurn(turn)
        case let .delta(turn, text, replace, progress):
            guard !suppressStreamingSpeech, activeTurnSequence == turn else { return }
            streamBuffer = replace ? text : streamBuffer + text
            if progress {
                // Progress belongs to the agent's internal work (including
                // tool activity). Keep it available to the visual surface, but
                // never let it enter the user's spoken assistant reply.
                progressNarration = streamBuffer
            } else {
                // Deltas are the canonical spoken form. A matching durable
                // message frame must not be read aloud a second time.
                if pendingAssistantMessageSpeech?.turn == turn {
                    pendingAssistantMessageSpeech = nil
                }
                let replacingProgress = !progressNarration.isEmpty
                clearProgressNarration()
                if replacingProgress && replace { stopSpeechPlayback() }
                message = streamBuffer
                conversationText.updateAssistant(streamBuffer)
                appendSpeakableText(text, replacing: replace)
            }
        case let .message(turn, _, role, content, clientMessageID):
            if let clientMessageID, pendingUserMessages.remove(clientMessageID) != nil {
                suppressStreamingSpeech = false
                beginAssistantTurn(turn)
                return
            }
            guard !suppressStreamingSpeech, role == "assistant", activeTurnSequence == turn else { return }
            clearProgressNarration()
            message = content
            conversationText.updateAssistant(content)
            speakAssistantMessageIfNeeded(turn: turn, content: content)
        case let .status(turn, text):
            guard !suppressStreamingSpeech, activeTurnSequence == turn else { return }
            if streamBuffer.isEmpty { message = text }
        case .askUser(let question):
            guard !suppressStreamingSpeech else { return }
            questionTurnSequence = activeTurnSequence
            pendingQuestion = question
            message = question.prompt
            conversationText.updateAssistant(question.prompt + optionPrompt(question))
            speak(question.prompt + optionPrompt(question))
        case let .turnEnded(turn, _):
            guard !suppressStreamingSpeech, activeTurnSequence == turn else { return }
            clearProgressNarration()
            flow.awaitingResponse = false
            flushSpeechBuffer()
            if let fallback = pendingAssistantMessageSpeech, fallback.turn == turn {
                pendingAssistantMessageSpeech = nil
                speak(fallback.content)
            }
            refreshState()
        case .error(let error):
            fail(error)
        }
    }

    private func beginAssistantTurn(_ turn: Int) {
        guard activeTurnSequence != turn else { return }
        activeTurnSequence = turn
        flow.awaitingResponse = true
        streamBuffer = ""; speechBuffer = ""
        pendingAssistantMessageSpeech = nil
        clearProgressNarration()
        refreshState()
    }

    private func appendSpeakableText(_ text: String, replacing: Bool) {
        if replacing { speechBuffer = text } else { speechBuffer += text }
        while let range = speechBoundary(in: speechBuffer) {
            speak(String(speechBuffer[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines))
            speechBuffer.removeSubrange(..<range.upperBound)
        }
    }

    private func speakAssistantMessageIfNeeded(turn: Int, content: String) {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        // Persist normally writes a final assistant message after its token
        // deltas. That snapshot is visual-only because the deltas have
        // already been spoken. A distinct message is a real follow-up.
        if !streamBuffer.isEmpty {
            if content == streamBuffer || streamBuffer.hasPrefix(content) { return }
            if content.hasPrefix(streamBuffer) {
                appendSpeakableText(String(content.dropFirst(streamBuffer.count)), replacing: false)
                streamBuffer = content
            } else {
                speak(normalized)
            }
            return
        }

        if flow.awaitingResponse {
            // Wait until turn end in case the canonical delta stream follows.
            pendingAssistantMessageSpeech = (turn, normalized)
        } else {
            // This arrived after the first response completed, so there is no
            // stream left to speak it for us.
            speak(normalized)
        }
    }

    private func speechBoundary(in text: String) -> Range<String.Index>? {
        for index in text.indices where ".?!".contains(text[index]) {
            let after = text.index(after: index)
            if after == text.endIndex || text[after].isWhitespace { return index..<after }
        }
        return text.range(of: "\n")
    }

    private func flushSpeechBuffer() {
        let remainder = speechBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        speechBuffer = ""
        if !remainder.isEmpty { speak(remainder) }
    }

    private func speak(_ text: String) {
        guard flow.active, !text.isEmpty else { return }
        queuedSpeech.append(text)
        playNext()
    }

    private func playNext() {
        guard flow.active, !flow.paused, activeUtterance == nil else { return }
        guard !queuedSpeech.isEmpty else { flow.playing = false; refreshState(); return }
        let utterance = AVSpeechUtterance(string: queuedSpeech.removeFirst())
        utterance.voice = MissionVoiceProfile.preferredVoice()
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = 0.50
        utterance.pitchMultiplier = 1.10
        utterance.volume = 0.96
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.08
        speakUtterance(utterance)
    }

    /// Renders through AVSpeechSynthesizer.write and schedules the resulting PCM on
    /// ttsPlayback's node inside our own AVAudioEngine, rather than calling
    /// synthesizer.speak (which would play through AVSpeechSynthesizer's own,
    /// separate audio unit sharing the .voiceChat session with the input node).
    /// Word offset is only approximate: it comes from the fraction of scheduled
    /// audio that has actually finished rendering, not real per-word boundaries.
    private func speakUtterance(_ utterance: AVSpeechUtterance) {
        activeUtterance = utterance
        activeWordOffset = 0
        let text = utterance.speechString as NSString
        let now = ProcessInfo.processInfo.systemUptime
        recentPlayback.removeAll { now - $0.time > 2 }
        recentPlayback.append((ObjectIdentifier(utterance), "", now))
        // Buffer scheduling only means synthesis began. The visible speaking
        // state waits until the player has rendered through the active engine.
        flow.playing = false
        refreshState()

        guard audioEngine.isRunning else {
            handlePlaybackFailure(utterance, reason: "audio engine was not running")
            return
        }

        let playback = ttsPlayback
        let tracker = UtterancePlaybackTracker()
        synthesizer.write(utterance) { [weak self] audioBuffer in
            guard let pcm = audioBuffer as? AVAudioPCMBuffer else { return }
            if pcm.frameLength == 0 {
                if tracker.markWriteFinished() {
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if tracker.hasProducedAudio {
                            self.finishPlayback(utterance)
                        } else {
                            self.handlePlaybackFailure(utterance, reason: "speech synthesis produced no playable buffers")
                        }
                    }
                }
                return
            }
            guard let converted = playback.convert(pcm) else {
                tracker.recordConversionFailure()
                return
            }
            let frames = AVAudioFramePosition(converted.frameLength)
            tracker.addBuffer(frames: frames)
            playback.node.scheduleBuffer(converted, completionCallbackType: .dataPlayedBack) { _ in
                let progress = tracker.bufferPlayed(frames: frames)
                Task { @MainActor [weak self] in
                    guard let self, self.activeUtterance === utterance else { return }
                    let offset = min(text.length, Int((Double(progress.played) / Double(progress.total)) * Double(text.length)))
                    self.activeWordOffset = max(self.activeWordOffset, offset)
                    self.trackPlaybackProgress(utterance, spokenLength: self.activeWordOffset, fullText: text)
                    if progress.done { self.finishPlayback(utterance) }
                }
            }
            if !playback.node.isPlaying { playback.node.play() }
            Task { @MainActor [weak self] in self?.armPlaybackStartWatch(for: utterance) }
        }
    }

    private func armPlaybackStartWatch(for utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance, playbackStartTask == nil else { return }
        playbackStartTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_250))
            guard !Task.isCancelled, let self, activeUtterance === utterance else { return }
            playbackStartTask = nil
            if audioEngine.isRunning,
               ttsPlayback.node.isPlaying,
               ttsPlayback.node.lastRenderTime != nil {
                flow.playing = true
                playbackRecoveryAttempts = 0
                refreshState()
                log("tts playback rendered")
            } else {
                handlePlaybackFailure(utterance, reason: "speech buffers did not render")
            }
        }
    }

    private func handlePlaybackFailure(_ utterance: AVSpeechUtterance, reason: String) {
        guard activeUtterance == nil || activeUtterance === utterance else { return }
        playbackStartTask?.cancel(); playbackStartTask = nil
        log("tts playback failure: \(reason)")
        if playbackRecoveryAttempts >= 1 {
            retainUnreadSpeechForRecovery()
            fail("Voice playback is unavailable. Your reply remains on screen; tap to try again.")
            return
        }
        playbackRecoveryAttempts += 1
        requestAudioRecovery(reason: reason)
    }

    private func trackPlaybackProgress(_ utterance: AVSpeechUtterance, spokenLength: Int, fullText: NSString) {
        let spoken = fullText.substring(to: spokenLength)
        let now = ProcessInfo.processInfo.systemUptime
        recentPlayback.removeAll { now - $0.time > 2 }
        let identifier = ObjectIdentifier(utterance)
        recentPlayback.removeAll { $0.id == identifier }
        recentPlayback.append((identifier, spoken, now))
        recognitionPlayback[identifier] = spoken
    }

    private func finishPlayback(_ utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance else { return }
        playbackStartTask?.cancel(); playbackStartTask = nil
        activeUtterance = nil
        flow.playing = false
        playNext()
    }

    private func stopSpeechPlayback() {
        playbackStartTask?.cancel(); playbackStartTask = nil
        activeUtterance = nil
        queuedSpeech.removeAll()
        speechBuffer = ""
        flow.paused = false
        flow.playing = false
        synthesizer.stopSpeaking(at: .immediate)
        ttsPlayback.stop()
    }

    private func clearProgressNarration() {
        progressNarration = ""
    }

    private func optionPrompt(_ question: MobileGateway.GatewayQuestion) -> String {
        guard !question.options.isEmpty else { return "" }
        return " Options: " + question.options.map(\.label).joined(separator: ", ")
    }

    private func sendAnswer(to question: MobileGateway.GatewayQuestion, transcript: String) {
        let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let option = question.options.first(where: { $0.label.lowercased() == normalized }) {
            gateway.answer(requestID: question.requestID, optionID: option.id)
        } else if question.allowsFreeText {
            gateway.answer(requestID: question.requestID, freeText: transcript)
        } else {
            message = "Please say one of the available options."
            speak(message)
        }
    }

}

private struct SpeechAnalyzerTranscriptSegment {
    let range: CMTimeRange
    let text: String
    let isFinal: Bool

    func overlaps(_ other: CMTimeRange) -> Bool {
        let ownStart = CMTimeGetSeconds(range.start)
        let ownEnd = CMTimeGetSeconds(CMTimeRangeGetEnd(range))
        let otherStart = CMTimeGetSeconds(other.start)
        let otherEnd = CMTimeGetSeconds(CMTimeRangeGetEnd(other))
        guard ownStart.isFinite, ownEnd.isFinite,
              otherStart.isFinite, otherEnd.isFinite
        else { return range == other }
        return (ownStart < otherEnd && otherStart < ownEnd)
            || abs(ownStart - otherStart) < 0.001
    }
}

private enum SpeechInputError: Error {
    case microphoneUnavailable
    case onDeviceRecognitionUnavailable
    case unsupportedLocale
    case modelInstallationFailed
    case analyzerFormatUnavailable
    case audioEngineStopped
}

/// Owns the AVAudioPlayerNode that TTS audio renders through, attached to the
/// same AVAudioEngine used for microphone capture. AVSpeechSynthesizer.write
/// delivers buffers off the main actor, so this type is a plain lock-protected
/// Sendable, matching SpeechAnalyzerAudioRouter's pattern for the same reason.
private final class TTSPlaybackNode: @unchecked Sendable {
    let node = AVAudioPlayerNode()
    private let lock = NSLock()
    private var attached = false
    private var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?

    func attachIfNeeded(to engine: AVAudioEngine) {
        lock.lock(); defer { lock.unlock() }
        guard !attached else { return }
        engine.attach(node)
        attached = true
    }

    /// Re-reads the engine's current output format, since enabling voice
    /// processing on the input node can change it after attach.
    func connect(in engine: AVAudioEngine) {
        lock.lock(); defer { lock.unlock() }
        let format = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        outputFormat = format
        converter = nil
        converterInputFormat = nil
    }

    func stop() { node.stop() }

    func resetGraphState() {
        lock.lock(); defer { lock.unlock() }
        node.stop()
        outputFormat = nil
        converter = nil
        converterInputFormat = nil
    }

    /// A short two-note readiness cue generated in memory. Keeping it on the
    /// existing voice graph means it follows the selected route and never
    /// introduces an asset or a second competing audio session.
    func playStartupCue() {
        let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let frames = AVAudioFrameCount(sourceFormat.sampleRate * 0.24)
        guard let source = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frames),
              let samples = source.floatChannelData?.pointee
        else { return }
        source.frameLength = frames

        for frame in 0..<Int(frames) {
            let time = Double(frame) / sourceFormat.sampleRate
            let note = time < 0.085 ? 523.25 : 783.99
            let localTime = time < 0.085 ? time : time - 0.085
            let envelope = min(1, localTime / 0.012) * max(0, 1 - localTime / 0.15)
            samples[frame] = Float(sin(2 * .pi * note * localTime) * envelope * 0.14)
        }

        guard let cue = convert(source) else { return }
        node.scheduleBuffer(cue, completionCallbackType: .dataPlayedBack) { _ in }
        if !node.isPlaying { node.play() }
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        lock.lock(); defer { lock.unlock() }
        guard let format = outputFormat else { return nil }
        if buffer.format == format { return buffer }
        if converter == nil || converterInputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            converterInputFormat = buffer.format
        }
        guard let converter else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1_024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var error: NSError?
        var consumed = false
        converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed { inputStatus.pointee = .noDataNow; return nil }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return error == nil ? output : nil
    }
}

/// Tracks one utterance's render-vs-playback bookkeeping. Buffers are produced
/// off the main actor by AVSpeechSynthesizer.write and consumed by the player
/// node's completion handlers, also off the main actor, so this is lock-protected
/// rather than actor-isolated.
private final class UtterancePlaybackTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var pendingBuffers = 0
    private var writeFinished = false
    private var playedFrames: AVAudioFramePosition = 0
    private var totalFrames: AVAudioFramePosition = 0
    private var conversionFailures = 0

    func addBuffer(frames: AVAudioFramePosition) {
        lock.lock(); defer { lock.unlock() }
        pendingBuffers += 1
        totalFrames += frames
    }

    func bufferPlayed(frames: AVAudioFramePosition) -> (done: Bool, played: AVAudioFramePosition, total: AVAudioFramePosition) {
        lock.lock(); defer { lock.unlock() }
        pendingBuffers -= 1
        playedFrames += frames
        return (pendingBuffers == 0 && writeFinished, playedFrames, max(totalFrames, 1))
    }

    func markWriteFinished() -> Bool {
        lock.lock(); defer { lock.unlock() }
        writeFinished = true
        return pendingBuffers == 0
    }

    var hasProducedAudio: Bool {
        lock.lock(); defer { lock.unlock() }
        return totalFrames > 0
    }

    func recordConversionFailure() {
        lock.lock(); defer { lock.unlock() }
        conversionFailures += 1
    }
}

/// Removes only standalone conversational disfluencies from the text leaving
/// the device. The on-screen transcript remains literal, and substantive words
/// are never rewritten.
private enum SpeechTranscriptCleaner {
    private static let standaloneFillers =
        #"(?i)(?:^|[\s,;:])(?:um+|uh+|er+|ah+|hmm+|mm+)(?=$|[\s,;:.!?])"#

    static func clean(_ text: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: standaloneFillers) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let withoutFillers = expression.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
        return withoutFillers
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,;:.!?])"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
