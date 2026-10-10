import SwiftUI

struct InputField: View {
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    private let prompt: String
    private let isSecure: Bool

    init(_ prompt: String, text: Binding<String>, isSecure: Bool = false) {
        self.prompt = prompt
        _text = text
        self.isSecure = isSecure
    }

    var body: some View {
        field
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($isFocused)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .modifier(FieldChrome(isFocused: isFocused))
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField(prompt, text: $text, prompt: Text(prompt))
        } else {
            TextField(prompt, text: $text, prompt: Text(prompt))
        }
    }
}
