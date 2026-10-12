import Foundation

@main
struct VoiceInteractionChecks {
    static func main() {
        var checks = 0
        func expect(_ condition: Bool, _ explanation: String) {
            precondition(condition, explanation)
            checks += 1
        }
        var flow = VoiceInteractionPolicy()
        expect(flow.status == .idle, "Initially idle")
        flow.start()
        let firstSession = flow.generation
        expect(flow.status == .listening, "Listen before submitting")
        flow.awaitingResponse = true
        expect(flow.status == .thinking, "Submitted turn stays thinking during STT restart")
        flow.playing = true
        expect(flow.status == .speaking, "Actual playback has status priority")
        flow.paused = true
        expect(flow.status != .speaking, "Retained but stopped playback is not speaking")
        flow.stop()
        expect(flow.status == .idle && !flow.accepts(firstSession), "Stop invalidates all old callbacks")
        flow.start()
        expect(!flow.accepts(firstSession) && flow.status == .listening, "Restart cannot accept old session callbacks")
        for status in [VoiceInteractionPolicy.Status.listening, .thinking, .speaking] {
            flow.awaitingResponse = status == .thinking
            flow.playing = status == .speaking
            flow.stop()
            expect(flow.status == .idle, "Stop works in every visible active state")
            flow.start()
        }

        var spike = VoiceSpeechGate()
        spike.energy(at: 0)
        spike.partial("noise guess", echo: false, at: 0)
        expect(!spike.shouldPause(at: 0.20), "A single spike cannot pass sustained-speech confirmation")
        var noise = VoiceSpeechGate()
        for index in 0...12 { noise.energy(at: Double(index) * 0.04) }
        expect(!noise.shouldPause(at: 0.48), "Even sustained energy alone cannot interrupt")
        expect(!noise.shouldFinish(at: 2), "Noise without recognized speech cannot submit")

        var speech = VoiceSpeechGate()
        speech.partial("Wait, another question", echo: false, at: 0)
        for index in 0...6 { speech.energy(at: Double(index) * 0.04) }
        expect(!speech.shouldPause(at: 0.15), "Confirmation is not immediate")
        expect(speech.shouldPause(at: 0.24), "Sustained energy plus real text permits recoverable pause")
        expect(!speech.shouldPause(at: 0.5), "Stale activity cannot pause playback")
        expect(!speech.shouldFinish(at: 0.7), "Do not endpoint inside silence budget")
        speech.partial("Wait, another question", echo: false, at: 0.85)
        expect(speech.shouldFinish(at: 0.91), "Repeated partial does not delay actual silence endpoint")
        speech.partial("Wait, another question please", echo: false, at: 0.95)
        expect(!speech.shouldFinish(at: 0.96), "Allow a revised final phrase to settle")

        var echo = VoiceSpeechGate()
        echo.partial("This is the assistant", echo: true, at: 0)
        for index in 0...8 { echo.energy(at: Double(index) * 0.04) }
        expect(!echo.shouldPause(at: 0.32), "Recognized speaker echo cannot interrupt")
        expect(echo.shouldFinish(at: 2) && !echo.hasSpeech, "Echo-only STT closes after silence but is not a user candidate")
        expect(VoiceSpeechGate.resemblesPlayback("not much with me", playback: ["Not much with me — just here."]), "Ignore case and punctuation for actual speaker text")
        expect(!VoiceSpeechGate.resemblesPlayback("wait a moment", playback: ["Not much with me — just here."]), "Different user speech remains eligible")

        var text = VoiceConversationText()
        text.updateDraft("My first question")
        expect(text.displayedUserText == "My first question", "Show live user transcription")
        text.acceptUser("My first question")
        text.updateAssistant("The assistant's answer")
        text.discardDraft()
        expect(text.userText == "My first question", "Recognition restart preserves the accepted user message")
        expect(text.assistantText == "The assistant's answer", "Assistant answer is a separate record, not a user echo")
        text.updateDraft("A noise guess")
        text.discardDraft()
        expect(text.displayedUserText == "My first question", "Rejected candidate cannot erase accepted transcription")
        expect(text.assistantText == "The assistant's answer", "False barge-in preserves the reply text")
        text.acceptUser("My second question")
        expect(text.userText == "My second question" && text.assistantText.isEmpty, "New accepted turn begins a new exchange")
        text.updateAssistant("Partial")
        text.updateAssistant("Canonical answer")
        expect(text.assistantText == "Canonical answer", "Canonical response replaces streamed display without duplication")
        print("Passed \(checks) voice interaction and conversation-text checks.")
    }
}
