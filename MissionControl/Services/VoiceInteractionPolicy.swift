import Foundation

/// Independent conversation, capture and playback state. Capture events never
/// decide whether the assistant is speaking or whether a tap means stop.
struct VoiceInteractionPolicy {
    enum Status { case idle, listening, thinking, speaking }
    private(set) var active = false
    private(set) var generation = 0
    var awaitingResponse = false
    var playing = false
    var paused = false

    var status: Status {
        guard active else { return .idle }
        if playing && !paused { return .speaking }
        if awaitingResponse { return .thinking }
        return .listening
    }

    mutating func start() { generation += 1; active = true }
    mutating func stop() {
        generation += 1
        active = false
        awaitingResponse = false
        playing = false
        paused = false
    }
    func accepts(_ epoch: Int) -> Bool { active && generation == epoch }
}

/// Audio energy is used only to locate silence, never to pause playback.
/// A candidate also needs non-echo recognized text and recent sustained energy.
struct VoiceSpeechGate {
    private(set) var lastEnergy: TimeInterval?
    private var energyStart: TimeInterval?
    private var candidateSince: TimeInterval?
    private(set) var lastText = ""
    private(set) var lastTextChange: TimeInterval?
    private(set) var hasSpeech = false

    mutating func energy(at now: TimeInterval) {
        if lastEnergy == nil || now - lastEnergy! > 0.12 { energyStart = now }
        lastEnergy = now
    }

    mutating func partial(_ text: String, echo: Bool, at now: TimeInterval) {
        guard !text.isEmpty else { candidateSince = nil; return }
        if text != lastText { lastText = text; lastTextChange = now }
        guard !echo else { candidateSince = nil; return }
        hasSpeech = true
        if candidateSince == nil { candidateSince = now }
    }

    func shouldPause(at now: TimeInterval) -> Bool {
        guard let candidateSince, let energyStart, let lastEnergy else { return false }
        return now - candidateSince >= 0.18 && lastEnergy - energyStart >= 0.16
            && now - lastEnergy < 0.15
    }

    func shouldFinish(at now: TimeInterval) -> Bool {
        // Echo-only recognition is also closed after silence, then rejected.
        // Otherwise an old speaker transcript could linger into the next turn.
        guard !lastText.isEmpty, let lastTextChange else { return false }
        // Do not equate a delayed/repeated recognition callback with new audio.
        return now - (lastEnergy ?? lastTextChange) >= 0.65 && now - lastTextChange >= 0.15
    }

    static func resemblesPlayback(_ text: String, playback: [String]) -> Bool {
        let words = normalized(text)
        guard !words.isEmpty else { return false }
        return playback.contains { spoken in
            let reference = normalized(spoken)
            return reference == words || (words.split(separator: " ").count >= 3
                && (" " + reference + " ").contains(" " + words + " "))
        }
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}
