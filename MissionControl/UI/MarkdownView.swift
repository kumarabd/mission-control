import SwiftUI

/// Lays out a markdown reply: headings, paragraphs, bullet and numbered lists, tables, quotes and code, with bold, italics and
/// links inside. The structure comes from `Markdown.parse`; each block's inline markdown is rendered by `Text`.
struct MarkdownView: View {
    let text: String
    var size: Font.TextStyle = .body

    var body: some View {
        let blocks = Markdown.parse(text)
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in blockView(block) }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let t):
            Text(inline(t)).font(.mission(level == 1 ? .title2 : level == 2 ? .title3 : .headline, .semibold)).foregroundStyle(Tok.text)
                .padding(.top, level <= 2 ? Space.xs : 0)
        case .paragraph(let t):
            Text(inline(t)).font(.mission(size)).foregroundStyle(Tok.text)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: Space.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text("\u{2022}").font(.mission(size)).foregroundStyle(Tok.accent)
                        Text(inline(item)).font(.mission(size)).foregroundStyle(Tok.text)
                    }
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: Space.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { n, item in
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text("\(n + 1).").font(.missionMono(.subheadline, .medium)).foregroundStyle(Tok.accent).frame(minWidth: 22, alignment: .trailing)
                        Text(inline(item)).font(.mission(size)).foregroundStyle(Tok.text)
                    }
                }
            }
        case .quote(let t):
            HStack(alignment: .top, spacing: Space.s) {
                RoundedRectangle(cornerRadius: 2).fill(Tok.accent.opacity(0.6)).frame(width: 3)
                Text(inline(t)).font(.mission(size)).foregroundStyle(Tok.muted)
            }
        case .code(let t):
            Text(t).font(.missionMono(.callout)).foregroundStyle(Tok.text).padding(Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tok.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .rule:
            Divider().overlay(Tok.hairline)
        case .table(let header, let rows):
            table(header: header, rows: rows)
        }
    }

    private func table(header: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: Space.l, verticalSpacing: Space.s) {
                GridRow { ForEach(Array(header.enumerated()), id: \.offset) { _, h in Text(inline(h)).font(.mission(.subheadline, .semibold)).foregroundStyle(Tok.muted) } }
                Divider().overlay(Tok.hairline).gridCellUnsizedAxes(.horizontal)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow { ForEach(Array(row.enumerated()), id: \.offset) { _, c in Text(inline(c)).font(.mission(.subheadline)).foregroundStyle(Tok.text) } }
                }
            }
            .padding(Space.m)
        }
        .background(Tok.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Tok.hairline) }
    }

    /// Bold, italics, code and links inside a block. Line breaks are kept; text that is not valid markdown shows as written.
    private func inline(_ s: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: false, interpretedSyntax: .inlineOnlyPreservingWhitespace,
                                                              failurePolicy: .returnPartiallyParsedIfPossible)
        return (try? AttributedString(markdown: s, options: options)) ?? AttributedString(s)
    }
}
