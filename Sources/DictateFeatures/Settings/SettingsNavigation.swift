import Observation

@Observable
package final class SettingsNavigation {
    package var selection = SettingsPane.general

    package init() {}

    func move(by offset: Int) {
        let panes = SettingsPane.allCases
        guard let index = panes.firstIndex(of: selection) else { return }

        selection = panes[min(max(index + offset, 0), panes.count - 1)]
    }
}
