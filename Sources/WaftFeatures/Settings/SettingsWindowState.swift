import Foundation
import Observation
import WaftCore

@Observable
package final class SettingsWindowState {
    package var selection = SettingsPane.general {
        didSet { editedInstructions = nil }
    }

    package var editedInstructions: Mode?

    var hoveredPane: SettingsPane?
    var copiedEntry: Date?

    @ObservationIgnored private var copyReset: Task<Void, Never>?

    package init() {}

    func move(by offset: Int) {
        let panes = SettingsPane.allCases
        guard let index = panes.firstIndex(of: selection) else { return }

        selection = panes[min(max(index + offset, 0), panes.count - 1)]
    }

    func hover(_ pane: SettingsPane, _ isHovering: Bool) {
        if isHovering {
            hoveredPane = pane
        } else if hoveredPane == pane {
            hoveredPane = nil
        }
    }

    func showCopied(_ entry: Date) {
        copiedEntry = entry
        copyReset?.cancel()
        copyReset = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))

            guard !Task.isCancelled else { return }

            self?.copiedEntry = nil
        }
    }
}
