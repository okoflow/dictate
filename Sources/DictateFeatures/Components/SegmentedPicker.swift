import SwiftUI

struct SegmentedPicker<Value: Hashable>: View {
    @Binding private var selection: Value

    private let title: String
    private let options: [Value]
    private let label: (Value) -> String

    init(_ title: String, selection: Binding<Value>, options: [Value], label: @escaping (Value) -> String) {
        self.title = title
        _selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Segment(title: label(option), isSelected: option == selection) {
                    selection = option
                }
            }
        }
        .padding(2)
        .background(Palette.control, in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct Segment: View {
    let title: String
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.controlRadius - 2, style: .continuous)

        Button(action: select) {
            Text(title)
                .font(.control)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, Metrics.controlPadding)
                .frame(minHeight: Metrics.controlHeight - 4)
                .background {
                    if isSelected {
                        shape
                            .fill(Palette.segment)
                            .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
