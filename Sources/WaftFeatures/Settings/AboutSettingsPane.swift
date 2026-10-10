import AppKit
import SwiftUI

struct AboutSettingsPane: View {
    private static let website = URL(literal: "https://waft.okoflow.com")
    private static let repository = URL(literal: "https://github.com/okoflow/waft")
    private static let license = URL(literal: "https://github.com/okoflow/waft/blob/main/LICENSE")

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

        return version.map { String(localized: "Version \($0)") } ?? String(localized: "Development build")
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)

            Text("Waft")
                .font(.heroTitle)

            Text(versionText)
                .font(.rowTitle)
                .foregroundStyle(.secondary)

            Text("On-device dictation for macOS with AI cleanup.")
                .font(.rowTitle)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)

        SettingsSection {
            LinkRow(title: "Website", detail: "waft.okoflow.com", url: Self.website)
            RowDivider()
            LinkRow(title: "Source code", detail: "github.com/okoflow/waft", url: Self.repository)
            RowDivider()
            LinkRow(title: "License", detail: "GPL-3.0", url: Self.license)
        }

        Text("Copyright 2026 The Waft Authors")
            .font(.rowDetail)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }
}
