import SwiftUI

/// A round picture for a person or an agent: their image when there is one and it has loaded. An agent with no picture
/// of its own gets the assistant's mark — the same sigil the voice screens animate — so every agent is recognizable
/// even before anyone sets an avatar. A person falls back to their initials.
struct AvatarView: View {
    let name: String
    var url: String?
    var size: CGFloat = 32
    var agent: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(Tok.accent.opacity(0.16))
            if agent {
                AgentMark(state: .idle, size: size * 0.92)
            } else {
                Text(Self.initials(name))
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tok.accent)
            }
            if let url, let parsed = URL(string: url), !url.isEmpty {
                AsyncImage(url: parsed) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(Tok.hairline) }
        .accessibilityHidden(true)
    }

    static func initials(_ name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }
}
