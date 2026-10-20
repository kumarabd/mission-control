import SwiftUI

/// A round picture for a person or an agent: their image when there is one and it has loaded, their initials otherwise.
struct AvatarView: View {
    let name: String
    var url: String?
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle().fill(Tok.accent.opacity(0.16))
            Text(Self.initials(name)).font(.system(size: size * 0.4, weight: .semibold, design: .rounded)).foregroundStyle(Tok.accent)
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
