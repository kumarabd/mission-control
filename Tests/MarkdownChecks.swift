import Foundation

// How a reply is split into blocks. Compiled on its own:
//   xcrun swiftc -parse-as-library MissionControl/Core/Domain/Markdown.swift Tests/MarkdownChecks.swift -o /private/tmp/markdown-checks && /private/tmp/markdown-checks
@main
struct MarkdownChecks {
    static func main() {
        let reply = """
        All set. Here's your hydration system:

        **🎯 Goal:** "Drink at least 3 liters"

        ## Check-ins (daily)

        | Time | Purpose |
        |---|---|
        | 9:00 AM | Nudge — start sipping |
        | 1:00 PM | Midday check |

        - First thing: a glass
        - With lunch
        * After work

        1. Pick a bottle
        2) Fill it

        > Small steps count.

        ---
        ```
        let x = 1
        ```
        Done.
        """
        let blocks = Markdown.parse(reply)
        precondition(blocks == [
            .paragraph("All set. Here's your hydration system:"),
            .paragraph("**🎯 Goal:** \"Drink at least 3 liters\""),
            .heading(level: 2, text: "Check-ins (daily)"),
            .table(header: ["Time", "Purpose"], rows: [["9:00 AM", "Nudge — start sipping"], ["1:00 PM", "Midday check"]]),
            .bullets(["First thing: a glass", "With lunch", "After work"]),
            .numbered(["Pick a bottle", "Fill it"]),
            .quote("Small steps count."),
            .rule,
            .code("let x = 1"),
            .paragraph("Done."),
        ], "got \(blocks)")

        // Lines of one paragraph keep their breaks; plain text is one paragraph; empty input has no blocks.
        precondition(Markdown.parse("one\ntwo") == [.paragraph("one\ntwo")])
        precondition(Markdown.parse("Just words.") == [.paragraph("Just words.")])
        precondition(Markdown.parse("").isEmpty && Markdown.parse("\n\n").isEmpty)
        // A pipe in prose is not a table without a separator row; a hash without a space is not a heading; "-5" is not a bullet.
        precondition(Markdown.parse("a | b") == [.paragraph("a | b")])
        precondition(Markdown.parse("#hashtag") == [.paragraph("#hashtag")])
        precondition(Markdown.parse("-5 degrees") == [.paragraph("-5 degrees")])
        // An unterminated code fence takes the rest instead of losing it.
        precondition(Markdown.parse("```\nabc") == [.code("abc")])
        // Windows line endings.
        precondition(Markdown.parse("- a\r\n- b") == [.bullets(["a", "b"])])
        print("MarkdownChecks passed")
    }
}
