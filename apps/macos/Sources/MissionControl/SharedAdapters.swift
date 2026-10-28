import Observation
import SwiftUI

/// The small surface the shared tracker screen needs from chat. On the phone
/// this is the full `ChatModel`; here it forwards to the desktop conversation.
@MainActor @Observable
final class ChatModel {
    struct Transcript: Equatable {
        var isRunning: Bool
    }

    private let store: ChatStore
    /// Set by the workspace, so a screen that starts a conversation brings
    /// Chat forward; auto-composition uses `send`, which stays put.
    weak var workspace: WorkspaceModel?

    init(store: ChatStore) { self.store = store }

    var transcript: Transcript { Transcript(isRunning: store.isRunning) }
    var completedTurns: Int { store.completedTurns }
    var question: GatewayQuestion? { store.question }

    func request(draft: String) {
        store.request(draft: draft)
        workspace?.destination = .chat
    }
    func send(_ text: String) { store.send(text) }
}

/// The shared goal/event sheets use these names; the desktop forms behind
/// them are the same Life Engine writes.
struct ItemFormSheet: View {
    let mode: ItemEditor.Mode
    var initialKind: ItemsService.Kind = .task

    var body: some View {
        ItemEditor(mode: mode, initialKind: initialKind)
    }
}

struct ItemDetailSheet: View {
    let ref: ItemRef

    var body: some View {
        TaskDetailView(ref: ref)
            .frame(width: 540, height: 600)
    }
}

/// A labelled text field with a hardware keyboard.
struct PlainInput: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var keyboard: KeyboardKind = .default

    enum KeyboardKind { case `default`, URL }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.mission(.footnote, .medium)).foregroundStyle(Tok.muted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

/// A secret with a reveal control; the value is never rendered as plain text
/// until the person asks to see it.
struct SecretInput: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.mission(.footnote, .medium)).foregroundStyle(Tok.muted)
            HStack(spacing: Space.s) {
                Group {
                    if reveal { TextField(placeholder, text: $text) }
                    else { SecureField(placeholder, text: $text) }
                }
                .textFieldStyle(.roundedBorder)
                Button { reveal.toggle() } label: {
                    Image(systemName: reveal ? "eye.slash" : "eye")
                        .foregroundStyle(Tok.muted)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(reveal ? "Hide" : "Show")
            }
        }
    }
}
