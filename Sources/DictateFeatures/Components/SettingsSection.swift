import SwiftUI

struct SettingsSection<Content: View, Accessory: View, Footer: View>: View {
    private let title: String?
    private let subtitle: String?
    private let content: Content
    private let accessory: Accessory?
    private let footer: Footer?

    init(
        _ title: String?,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder footer: () -> Footer,
    ) {
        self.init(title: title, subtitle: subtitle, content: content(), accessory: accessory(), footer: footer())
    }

    private init(title: String?, subtitle: String?, content: Content, accessory: Accessory?, footer: Footer?) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.accessory = accessory
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || subtitle != nil || accessory != nil {
                header
            }

            SettingsCard {
                content
            }

            if let footer {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    footer
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            accessory
        }
        .padding(.horizontal, 10)
    }
}

extension SettingsSection where Accessory == EmptyView, Footer == EmptyView {
    init(_ title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, content: content(), accessory: nil, footer: nil)
    }
}

extension SettingsSection where Accessory == EmptyView {
    init(_ title: String?, subtitle: String? = nil, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(title: title, subtitle: subtitle, content: content(), accessory: nil, footer: footer())
    }
}
