import SwiftUI

struct MenuPicker<Value: Hashable, Options: View>: View {
    @Binding private var selection: Value

    private let title: String
    private let current: String
    private let options: Options

    init(_ title: String, selection: Binding<Value>, current: String, @ViewBuilder options: () -> Options) {
        self.title = title
        _selection = selection
        self.current = current
        self.options = options()
    }

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                options
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                Text(current)
                    .font(.control)
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Palette.control, in: Circle())
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(title)
        .accessibilityValue(current)
    }
}
