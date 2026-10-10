import SwiftUI

struct ProgressCard: View {
    let model: FileTranscriptionModel

    private var progress: Double? {
        if case let .transcribing(progress) = model.phase {
            return progress
        }

        return nil
    }

    private var status: String {
        guard let progress else { return String(localized: "Reading the audio…") }

        return String(localized: "Transcribing… \(progress.formatted(.percent.precision(.fractionLength(0))))")
    }

    var body: some View {
        SettingsCard {
            HStack(spacing: 12) {
                FileIcon(url: model.file)

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.file?.lastPathComponent ?? "")
                        .font(.rowTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    ProgressView(value: progress ?? 0)
                        .progressViewStyle(.linear)
                        .opacity(progress == nil ? 0.4 : 1)
                        .animation(Motion.meter, value: progress)

                    Text(status)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Button("Cancel", action: model.cancel)
            }
            .settingsRowPadding()
        }
    }
}
