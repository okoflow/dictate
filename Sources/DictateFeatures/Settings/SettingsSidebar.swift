import SwiftUI

struct SettingsSidebar: View {
    let state: SettingsWindowState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsPane.sidebarPanes, id: \.self) { pane in
                SidebarRow(pane: pane, state: state)
            }

            Spacer(minLength: 0)

            SidebarRow(pane: .about, state: state)
        }
        .padding(.horizontal, 10)
        .padding(.top, 48)
        .padding(.bottom, 10)
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
            surface(ConcentricRectangle(corners: .concentric(minimum: .fixed(8)), isUniform: true))
        } else {
            surface(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    .font(.system(size: 13))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 36)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Palette.selection)
                } else if state.hoveredPane == pane {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Palette.hover)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { state.hover(pane, $0) }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
