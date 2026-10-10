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
        VStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)

            Text("Dictate")
                .font(.heroTitle)

            Text(versionText)
                .font(.rowTitle)
                .foregroundStyle(.secondary)

            Text("Push-to-talk dictation for macOS with on-device Whisper.")
                .font(.rowTitle)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)

        SettingsSection {
            LinkRow(title: "Website", detail: "dictate.okoflow.com", url: Self.website)
            RowDivider()
            LinkRow(title: "Source code", detail: "github.com/okoflow/dictate", url: Self.repository)
            RowDivider()
            LinkRow(title: "License", detail: "MIT", url: Self.license)
        }

        Text("Copyright 2026 The Dictate Authors")
            .font(.rowDetail)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }
}

private struct LinkRow: View {
    let title: String
    let detail: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 16)

                Text(detail)
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.up.right")
                    .font(.glyph)
                    .foregroundStyle(.secondary)
            }
            .font(.rowTitle)
            .settingsRowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
