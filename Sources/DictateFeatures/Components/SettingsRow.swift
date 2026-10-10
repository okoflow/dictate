import SwiftUI

struct SettingsRow<Accessory: View>: View {
    private let title: String
    private let description: String?
    private let accessory: Accessory

    init(_ title: String, description: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.description = description
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            RowLabel(title: title, description: description)

            Spacer(minLength: 0)

            HStack(spacing: Metrics.controlSpacing) {
                accessory
            }
        }
        .settingsRowPadding()
    }
}

struct RowLabel: View {
    let title: String
    var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.rowTitle)

            if let description {
                Text(description)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    func settingsRowPadding() -> some View {
        padding(Metrics.rowPadding)
            .frame(minHeight: Metrics.rowMinHeight)
    }
}
