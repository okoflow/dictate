import SwiftUI

struct SettingsSidebar: View {
    let state: SettingsWindowState

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sidebarRowSpacing) {
            ForEach(SettingsPane.sidebarPanes, id: \.self) { pane in
                SidebarRow(pane: pane, state: state)
            }

            Spacer(minLength: 0)

            SidebarRow(pane: .pro, state: state)
            SidebarRow(pane: .about, state: state)
        }
        .padding(.horizontal, Metrics.rowPadding)
        .padding(.top, Metrics.sidebarTop)
        .padding(.bottom, Metrics.rowPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            SidebarBackground()
        }
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            switch direction {
            case .up: state.move(by: -1)
            case .down: state.move(by: 1)
            default: break
            }
        }
    }
}

private struct SidebarBackground: View {
    var body: some View {
        if #available(macOS 26, *) {
            surface(ConcentricRectangle(corners: .concentric(minimum: .fixed(Metrics.sidebarRadius)), isUniform: true))
        } else {
            surface(RoundedRectangle(cornerRadius: Metrics.sidebarRadius, style: .continuous))
        }
    }

    private func surface(_ shape: some Shape) -> some View {
        shape
            .fill(Palette.sidebar)
            .overlay {
                shape.stroke(Palette.sidebarBorder, lineWidth: 1)
            }
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane
    let state: SettingsWindowState

    private var isSelected: Bool {
        state.selection == pane
    }

    var body: some View {
        Button {
            state.selection = pane
        } label: {
            HStack(spacing: 10) {
                IconTile(symbolName: pane.symbolName, tint: pane.tint)

                Text(pane.title)
                    .font(.rowTitle)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: Metrics.sidebarRowHeight)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                        .fill(Palette.hover)
                        .animation(Motion.fade) { fill in
                            fill.opacity(state.hoveredPane == pane && !isSelected ? 1 : 0)
                        }

                    if isSelected {
                        RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                            .fill(Palette.selection)
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { state.hover(pane, $0) }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
