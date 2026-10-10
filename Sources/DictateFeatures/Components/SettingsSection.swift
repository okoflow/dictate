import SwiftUI

struct SettingsSection<Content: View, Accessory: View, Footer: View>: View {
    private let title: LocalizedStringKey?
    private let subtitle: LocalizedStringKey?
    private let content: Content
    private let accessory: Accessory?
    private let footer: Footer?

    init(
        _ title: LocalizedStringKey?,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder footer: () -> Footer,
    ) {
        self.init(title: title, subtitle: subtitle, content: content(), accessory: accessory(), footer: footer())
    }

    private init(
        title: LocalizedStringKey?,
        subtitle: LocalizedStringKey?,
        content: Content,
        accessory: Accessory?,
        footer: Footer?,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.accessory = accessory
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.groupSpacing) {
            if title != nil || subtitle != nil || accessory != nil {
                header
            }

            SettingsCard {
                content
            }

            if let footer {
                HStack(spacing: Metrics.controlSpacing) {
                    Spacer(minLength: 0)
                    footer
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Metrics.rowSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            accessory
        }
        .padding(.horizontal, Metrics.rowPadding)
    }
}

extension SettingsSection where Accessory == EmptyView, Footer == EmptyView {
    init(_ title: LocalizedStringKey? = nil, subtitle: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, content: content(), accessory: nil, footer: nil)
    }
}

extension SettingsSection where Accessory == EmptyView {
    init(
        _ title: LocalizedStringKey?,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer,
    ) {
        self.init(title: title, subtitle: subtitle, content: content(), accessory: nil, footer: footer())
    }
}

extension SettingsSection where Footer == EmptyView {
    init(
        _ title: LocalizedStringKey?,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory,
    ) {
        self.init(title: title, subtitle: subtitle, content: content(), accessory: accessory(), footer: nil)
    }
}
