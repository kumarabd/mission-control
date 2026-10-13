import Foundation

/// The block structure of a markdown reply. SwiftUI's `Text` renders inline markdown (bold, italics, links) but not lists,
/// headings or tables, which is what an assistant's replies are made of; this splits the text into blocks a view can lay out.
/// Inline markdown inside each block is left for `Text` to render.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case quote(String)
    case code(String)
    case rule
    case table(header: [String], rows: [[String]])
}

enum Markdown {
    static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var i = 0

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
        }

        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                flush()
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") { code.append(lines[i]); i += 1 }
                blocks.append(.code(code.joined(separator: "\n")))
                i += 1
                continue
            }
            if line.isEmpty { flush(); i += 1; continue }
            if isRule(line) { flush(); blocks.append(.rule); i += 1; continue }
            if let (level, text) = heading(line) { flush(); blocks.append(.heading(level: level, text: text)); i += 1; continue }

            if line.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flush()
                let header = cells(line)
                var rows: [[String]] = []
                i += 2
                while i < lines.count, lines[i].contains("|"), !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    rows.append(cells(lines[i])); i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }
            if bullet(line) != nil {
                flush()
                var items: [String] = []
                while i < lines.count, let item = bullet(lines[i].trimmingCharacters(in: .whitespaces)) { items.append(item); i += 1 }
                blocks.append(.bullets(items))
                continue
            }
            if numbered(line) != nil {
                flush()
                var items: [String] = []
                while i < lines.count, let item = numbered(lines[i].trimmingCharacters(in: .whitespaces)) { items.append(item); i += 1 }
                blocks.append(.numbered(items))
                continue
            }
            if line.hasPrefix(">") {
                flush()
                var quoted: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    quoted.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces)); i += 1
                }
                blocks.append(.quote(quoted.joined(separator: "\n")))
                continue
            }
            paragraph.append(line)
            i += 1
        }
        flush()
        return blocks
    }

    private static func heading(_ line: String) -> (Int, String)? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count), line.dropFirst(hashes.count).first == " " else { return nil }
        return (hashes.count, line.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces))
    }

    private static func isRule(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard stripped.count >= 3, let first = stripped.first, "-*_".contains(first) else { return false }
        return stripped.allSatisfy { $0 == first }
    }

    private static func bullet(_ line: String) -> String? {
        for marker in ["- ", "* ", "\u{2022} "] where line.hasPrefix(marker) { return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces) }
        return nil
    }

    private static func numbered(_ line: String) -> String? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3 else { return nil }
        let rest = line.dropFirst(digits.count)
        guard let mark = rest.first, mark == "." || mark == ")", rest.dropFirst().first == " " else { return nil }
        return rest.dropFirst(2).trimmingCharacters(in: .whitespaces)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.contains("-"), t.contains("|") else { return false }
        return t.allSatisfy { "|-: ".contains($0) }
    }

    private static func cells(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
