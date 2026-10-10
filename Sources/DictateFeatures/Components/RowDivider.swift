import SwiftUI

struct RowDivider: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Palette.separator
            .frame(height: 1 / displayScale)
            .padding(.horizontal, Metrics.rowPadding)
    }
}
