import SwiftUI

struct SettingsPage<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.pagePadding)
                .padding(.top, Metrics.pageTop)
                .padding(.bottom, Metrics.pagePadding)
            }
            .hidingSystemScrollEdge()

            header
        }
    }

    private var header: some View {
        Text(title)
            .font(.pageTitle)
            .frame(maxWidth: .infinity, minHeight: Metrics.titleBarHeight, maxHeight: Metrics.titleBarHeight, alignment: .leading)
            .padding(.horizontal, Metrics.pagePadding)
            .background(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: Palette.window, location: 0),
                        .init(color: Palette.window, location: 0.76),
                        .init(color: Palette.window.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                .frame(height: Metrics.pageTop - 5)
            }
            .allowsHitTesting(false)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    @ViewBuilder
    fileprivate func hidingSystemScrollEdge() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }
}
