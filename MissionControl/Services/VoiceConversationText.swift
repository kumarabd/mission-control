import Foundation

/// The current exchange, like Android's transcript/reply UI. This is not an
/// audio recording or a durable history. Recognition drafts cannot replace an
/// accepted user message until they are submitted.
struct VoiceConversationText {
    private(set) var userText = ""
    private(set) var assistantText = ""
    private(set) var draft = ""

    var displayedUserText: String { draft.isEmpty ? userText : draft }

    mutating func updateDraft(_ text: String) { draft = text }
    mutating func discardDraft() { draft = "" }
    mutating func acceptUser(_ text: String) {
        userText = text
        draft = ""
        assistantText = ""
    }
    mutating func updateAssistant(_ text: String) { assistantText = text }
}
