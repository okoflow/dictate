import AppKit
import SwiftUI

struct FileIcon: View {
    let url: URL?

    var body: some View {
        Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage())
            .resizable()
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
    }
}
