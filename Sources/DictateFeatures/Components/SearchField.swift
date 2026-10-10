import SwiftUI

struct SearchField: View {
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    private let prompt: String

    init(_ prompt: String, text: Binding<String>) {
        self.prompt = prompt
        _text = text
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
                .accessibilityLabel("Clear the search")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .modifier(FieldChrome(isFocused: isFocused))
    }
}
