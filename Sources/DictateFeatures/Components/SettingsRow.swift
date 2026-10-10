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
        HStack(spacing: 16) {
            RowLabel(title: title, description: description)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
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
                .font(.system(size: 13))

            if let description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    func settingsRowPadding() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(minHeight: 37)
    }
}
