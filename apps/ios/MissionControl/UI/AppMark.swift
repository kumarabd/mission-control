import SwiftUI

/// The app's own mark, decorative. The launch, welcome and lock screens use the same symbol, so it is a heading for
/// the screen rather than a control: no label, hidden from VoiceOver, and it never takes a tap.
struct AppMark: View {
    var body: some View {
        Image(systemName: "scope")
            .font(.mission(.body, .medium))
            .foregroundStyle(Tok.accent)
            .accessibilityHidden(true)
    }
}
