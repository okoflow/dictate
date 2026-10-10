import DictateCore
import SwiftUI

struct ResultView: View {
    let model: FileTranscriptionModel
    let transcript: TimedTranscript

    private var details: String {
        let duration = Duration.seconds(transcript.duration).formatted(
            .time(pattern: transcript.duration >= 3600 ? .hourMinuteSecond : .minuteSecond),
        )

        return [duration, transcript.language.displayName].joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard {
                HStack(spacing: 12) {
                    FileIcon(url: model.file)

                    RowLabel(title: .verbatim(model.file?.lastPathComponent ?? ""), description: .verbatim(details))

                    Spacer(minLength: 0)

                    CopyButton(isCopied: model.copiedAt != nil, action: model.copyText)
                }
                .settingsRowPadding()

                RowDivider()

                ScrollView {
                    Text(transcript.text)
                        .font(.rowTitle)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Metrics.rowPadding + 2)
                }
                .frame(minHeight: 160, maxHeight: .infinity)
            }

            HStack(spacing: Metrics.controlSpacing) {
                Button("Transcribe Another File", action: model.reset)

                Spacer(minLength: 0)

                Button("Save Text…") { model.save(.text) }

                Button("Save Subtitles…") { model.save(.subtitles) }
                    .buttonStyle(PushButtonStyle(isProminent: true))
            }
        }
    }
}
