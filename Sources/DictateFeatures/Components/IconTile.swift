import SwiftUI

struct IconTile: View {
    let symbolName: String
    let tint: TileTint
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.56, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}
