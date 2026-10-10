import SwiftUI

struct InUseAccessory: View {
    let isInUse: Bool
    var canUse = true
    let use: () -> Void

    var body: some View {
        if isInUse {
            Badge("In use", tint: .accentColor)
        } else {
            Button("Use", action: use)
                .disabled(!canUse)
        }
    }
}
