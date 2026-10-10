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
                VStack(alignment: .leading, spacing: 31) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 73)
                .padding(.bottom, 24)
            }
            .hidingSystemScrollEdge()

            header
        }
    }

    private var header: some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .leading)
            .padding(.horizontal, 20)
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
                .frame(height: 68)
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
