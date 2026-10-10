import SwiftUI

struct SettingsSidebar: View {
    let state: SettingsWindowState

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sidebarRowSpacing) {
            ForEach(SettingsPane.sidebarPanes, id: \.self) { pane in
                SidebarRow(pane: pane, state: state)
            }

            Spacer(minLength: 0)

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
            .shadow(color: Palette.sidebarShadow, radius: 14, y: 2)
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
                if isSelected {
                    RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                        .fill(Palette.selection)
                } else if state.hoveredPane == pane {
                    RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                        .fill(Palette.hover)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { state.hover(pane, $0) }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
