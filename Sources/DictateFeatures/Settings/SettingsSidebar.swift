import AppKit
import SwiftUI

struct SettingsSidebar: View {
    let navigation: SettingsNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SidebarHeader()
                .padding(.top, 54)
                .padding(.bottom, 18)

            ForEach(SettingsPane.sidebarPanes, id: \.self) { pane in
                SidebarRow(pane: pane, navigation: navigation)
            }

            Spacer(minLength: 0)

            SidebarRow(pane: .about, navigation: navigation)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            SidebarBackground()
        }
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            switch direction {
            case .up: navigation.move(by: -1)
            case .down: navigation.move(by: 1)
            default: break
            }
        }
    }
}

private struct SidebarBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        shape
            .fill(Palette.sidebar)
            .overlay {
                shape.strokeBorder(Palette.sidebarBorder, lineWidth: 0.5)
            }
            .shadow(color: Palette.sidebarShadow, radius: 19, y: 3)
    }
}

private struct SidebarHeader: View {
    private var detail: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

        return version.map { "Version \($0)" } ?? "Development build"
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Dictate")
                    .font(.system(size: 13, weight: .semibold))

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane
    let navigation: SettingsNavigation

    private var isSelected: Bool {
        navigation.selection == pane
    }

    var body: some View {
        Button {
            navigation.selection = pane
        } label: {
            HStack(spacing: 10) {
                IconTile(symbolName: pane.symbolName, tint: pane.tint)

                Text(pane.title)
                    .font(.system(size: 13))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 36)
            .background(isSelected ? Palette.selection : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
