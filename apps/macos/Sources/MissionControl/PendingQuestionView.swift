import SwiftUI

struct PendingQuestionView: View {
    let question: GatewayQuestion
    let onAnswer: (String?, String?) -> Void
    @State private var freeText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your input is needed", systemImage: "questionmark.bubble.fill")
                .font(.mission(.headline))
                .foregroundStyle(MissionTheme.attention)
            Text(question.prompt)
                .font(.mission(.body))
                .foregroundStyle(MissionTheme.ink)
            if !question.options.isEmpty {
                HStack {
                    ForEach(question.options) { option in
                        Button(option.label) { onAnswer(option.id, nil) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            if question.allowsFreeText {
                HStack {
                    TextField("Type your answer", text: $freeText)
                    Button("Send") {
                        let value = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else { return }
                        onAnswer(nil, value)
                    }
                    .disabled(freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(16)
        .background(MissionTheme.surface, in: MissionTheme.cardShape)
        .overlay(MissionTheme.cardShape.stroke(MissionTheme.attention.opacity(0.42)))
        .frame(maxWidth: 820)
    }
}
