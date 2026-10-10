import SwiftUI
import WaftCore

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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Metrics.controlSpacing) {
                    anotherFileButton

                    Spacer(minLength: Metrics.controlSpacing)

                    saveButtons
                }

                VStack(alignment: .trailing, spacing: Metrics.controlSpacing) {
                    HStack(spacing: Metrics.controlSpacing) {
                        saveButtons
                    }

                    anotherFileButton
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var anotherFileButton: some View {
        Button("Transcribe Another File", action: model.reset)
            .fixedSize()
    }

    @ViewBuilder
    private var saveButtons: some View {
        Button("Save Text…") { model.save(.text) }
            .fixedSize()

        Button("Save Subtitles…") { model.save(.subtitles) }
            .buttonStyle(PushButtonStyle(isProminent: true))
            .fixedSize()
    }
}
