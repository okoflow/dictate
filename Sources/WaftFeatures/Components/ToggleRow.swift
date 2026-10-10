import SwiftUI

struct ToggleRow: View {
    @Binding private var isOn: Bool

    private let title: LocalizedStringKey
    private let description: LocalizedStringKey?

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>, description: LocalizedStringKey? = nil) {
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
