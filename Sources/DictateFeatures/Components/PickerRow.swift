import SwiftUI

struct PickerRow<Value: Hashable, Options: View>: View {
    @Binding private var selection: Value

    private let title: LocalizedStringKey
    private let current: String
    private let description: LocalizedStringKey?
    private let options: Options

    init(
        _ title: LocalizedStringKey,
        selection: Binding<Value>,
        current: String,
        description: LocalizedStringKey? = nil,
        @ViewBuilder options: () -> Options,
    ) {
        self.title = title
        _selection = selection
        self.current = current
        self.description = description
        self.options = options()
    }

    var body: some View {
        SettingsRow(title, description: description) {
            MenuPicker(title, selection: $selection, current: current) {
                options
            }
        }
    }
}
