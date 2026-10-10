import DictateCore
import SwiftUI

struct ProSettingsPane: View {
    let pro: ProModel

    var body: some View {
        ProHero(pro: pro)

        SettingsSection("What Pro adds") {
            ForEach(ProBenefit.all) { benefit in
                if benefit.id != ProBenefit.all.first?.id {
                    RowDivider()
                }

                ProBenefitRow(benefit: benefit, isUnlocked: pro.access.isUnlocked)
            }
        }

        LicenseSection(pro: pro)
    }
}

private struct ProHero: View {
    let pro: ProModel

    private var status: String {
        switch pro.access.status {
        case let .licensed(license):
            String(localized: "Licensed to \(license.name ?? license.email). Thank you!")
        case .trial:
            String(localized: "Free trial ends \(pro.trialEnds.formatted(.relative(presentation: .named)))")
        case .expired:
            String(localized: "Your free trial has ended.")
        }
    }

    private var isLicensed: Bool {
        if case .licensed = pro.access.status {
            return true
        }

        return false
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)

        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Dictate Pro")
                    .font(.system(size: 22, weight: .bold))

                Text(status)
                    .font(.rowTitle)
                    .opacity(0.9)
            }

            Spacer(minLength: 0)

            if !isLicensed {
                Button("Buy for \(ProModel.price)", action: pro.purchase)
                    .buttonStyle(ProButtonStyle())
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(LinearGradient.pro, in: shape)
    }
}

private struct ProBenefitRow: View {
    let benefit: ProBenefit
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbolName: benefit.symbolName, tint: benefit.tint, size: 28)

            RowLabel(title: benefit.title, description: benefit.detail)

            Spacer(minLength: 0)

            Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(isUnlocked ? Palette.success : .secondary)
                .accessibilityLabel(isUnlocked ? Text("Included") : Text("Locked"))
        }
        .settingsRowPadding()
    }
}

struct ProBenefit: Identifiable {
    static let all = [
        ProBenefit(
            symbolName: "sparkles",
            tint: .purple,
            title: "Clean and Formal",
            detail: "Fillers and false starts go; grammar, punctuation and tone get fixed.",
        ),
        ProBenefit(
            symbolName: "globe",
            tint: .blue,
            title: "Translation both ways",
            detail: "Speak any of 45 languages and get another, in either direction.",
        ),
        ProBenefit(
            symbolName: "cpu.fill",
            tint: .teal,
            title: "Any AI model",
            detail: "Claude or OpenAI with your own key, or a local model on your Mac.",
        ),
        ProBenefit(
            symbolName: "text.cursor",
            tint: .orange,
            title: "Editing by voice",
            detail: "Select text and say what to change.",
        ),
        ProBenefit(
            symbolName: "waveform",
            tint: .red,
            title: "File transcription",
            detail: "Recordings and videos become text and subtitles.",
        ),
        ProBenefit(
            symbolName: "slider.horizontal.3",
            tint: .gray,
            title: "Your own instructions",
            detail: "Tune each mode to the way you write.",
        ),
    ]

    let symbolName: String
    let tint: TileTint
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var id: String {
        symbolName
    }
}
