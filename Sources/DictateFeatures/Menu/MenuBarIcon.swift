import SwiftUI

package struct MenuBarIcon: View {
    private let model: AppModel

    package init(model: AppModel) {
        self.model = model
    }

    package var body: some View {
        Image(systemName: model.status.symbolName)
            .accessibilityLabel("Dictate")
    }
}
