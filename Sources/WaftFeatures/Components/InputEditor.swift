import SwiftUI

struct InputEditor: View {
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    private let height: CGFloat

    init(text: Binding<String>, height: CGFloat) {
        _text = text
        self.height = height
    }

    var body: some View {
        TextEditor(text: $text)
            .font(.editor)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .padding(6)
            .frame(height: height)
            .modifier(FieldChrome(isFocused: isFocused, cornerRadius: Metrics.editorRadius))
    }
}
