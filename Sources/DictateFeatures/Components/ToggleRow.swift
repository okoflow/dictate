import SwiftUI

struct ToggleRow: View {
    @Binding private var isOn: Bool

    private let title: String
    private let description: String?

    init(_ title: String, isOn: Binding<Bool>, description: String? = nil) {
        self.title = title
        self.description = description
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            RowLabel(title: title, description: description)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .settingsRowPadding()
    }
}
