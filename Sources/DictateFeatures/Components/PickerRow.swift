import SwiftUI

struct PickerRow<Value: Hashable, Options: View>: View {
    @Binding private var selection: Value

    private let title: String
    private let description: String?
    private let options: Options

    init(_ title: String, selection: Binding<Value>, description: String? = nil, @ViewBuilder options: () -> Options) {
        self.title = title
        self.description = description
        _selection = selection
        self.options = options()
    }

    var body: some View {
        SettingsRow(title, description: description) {
            Picker(title, selection: $selection) {
                options
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .labelsHidden()
            .fixedSize()
        }
    }
}
