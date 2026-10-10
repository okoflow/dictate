import AppKit
import SwiftUI

struct AboutSettingsPane: View {
    private static let website = URL(literal: "https://dictate.okoflow.com")
    private static let repository = URL(literal: "https://github.com/okoflow/dictate")
    private static let license = URL(literal: "https://github.com/okoflow/dictate/blob/main/LICENSE")

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

        return version.map { "Version \($0)" } ?? "Development build"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Dictate")
                .font(.title.weight(.semibold))

            Text(versionText)
                .foregroundStyle(.secondary)

            Text("Push-to-talk dictation for macOS with on-device Whisper.")
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            HStack(spacing: 16) {
                Link("Website", destination: Self.website)
                Link("Source code", destination: Self.repository)
                Link("License", destination: Self.license)
            }
            .padding(.top, 4)

            Text("Copyright 2026 The Dictate Authors")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
