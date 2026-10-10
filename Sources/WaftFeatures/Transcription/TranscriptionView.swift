import SwiftUI
import WaftCore

package struct TranscriptionView: View {
    @Bindable private var model: FileTranscriptionModel

    private let settings: SettingsModel
    private let pro: ProModel
    private let showPro: () -> Void

    package init(model: FileTranscriptionModel, settings: SettingsModel, pro: ProModel, showPro: @escaping () -> Void) {
        self.model = model
        self.settings = settings
        self.pro = pro
        self.showPro = showPro
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TranscriptionHeader()

            switch model.phase {
            case .idle where !pro.allows(.fileTranscription):
                ProGateCard(showPro: showPro)

            case .idle, .failed:
                VStack(spacing: 12) {
                    if case let .failed(message) = model.phase {
                        FailureCard(fileName: model.file?.lastPathComponent, message: message)
                            .transition(.reveal)
                    }

                    DropZone(model: model)
                    LanguageCard(model: model, languages: settings.settings.languages.languages)
                }
                .transition(.opacity)

            case .reading, .transcribing:
                ProgressCard(model: model)
                    .transition(.opacity)

            case let .finished(transcript):
                ResultView(model: model, transcript: transcript)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 52)
        .padding(.bottom, 24)
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity, alignment: .top)
        .background(Palette.window)
        .ignoresSafeArea()
        .buttonStyle(PushButtonStyle())
        .animation(Motion.layout, value: model.phase)
        .reducedMotionPolicy()
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, !model.isWorking, pro.allows(.fileTranscription) else { return false }

            model.transcribe(url)

            return true
        } isTargeted: { isTargeted in
            model.isDropTargeted = isTargeted
        }
    }
}

private struct TranscriptionHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbolName: "waveform", tint: .purple, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Transcribe a File")
                    .font(.pageTitle)

                Text("Audio and video files, transcribed on this Mac.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DropZone: View {
    let model: FileTranscriptionModel

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        let isTargeted = model.isDropTargeted

        VStack(spacing: 8) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 30))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                .contentTransition(.symbolEffect(.replace))
                .padding(.bottom, 4)

            Text("Drop an audio or video file here")
                .font(.rowTitle)

            Text(model.notReadyMessage.map { .verbatim($0) } ?? "MP3, M4A, WAV, MP4, MOV and more")
                .font(.rowDetail)
                .foregroundStyle(.secondary)

            Button("Choose File…", action: model.chooseFile)
                .disabled(model.notReadyMessage != nil)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(isTargeted ? Palette.selection : Palette.card, in: shape)
        .overlay {
            shape.strokeBorder(
                isTargeted ? Color.accentColor : Palette.dropZoneBorder,
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]),
            )
        }
        .animation(Motion.fade, value: isTargeted)
    }
}

private struct LanguageCard: View {
    @Bindable var model: FileTranscriptionModel

    let languages: [Language]

    var body: some View {
        SettingsCard {
            PickerRow(
                "Language",
                selection: $model.language,
                current: model.language?.displayName ?? String(localized: "Detect automatically"),
                description: "The languages you chose in Settings › Dictation.",
            ) {
                Text("Detect automatically").tag(Language?.none)

                ForEach(languages, id: \.self) { language in
                    Text(language.displayName).tag(Language?.some(language))
                }
            }
        }
    }
}

private struct FailureCard: View {
    let fileName: String?
    let message: String

    var body: some View {
        SettingsCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                RowLabel(
                    title: fileName
                        .map { name -> LocalizedStringKey in "Couldn't transcribe \(name)" } ?? "Couldn't transcribe the file",
                    description: .verbatim(message),
                )

                Spacer(minLength: 0)
            }
            .settingsRowPadding()
        }
    }
}

private struct ProGateCard: View {
    let showPro: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)

        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .padding(.bottom, 4)

            Text("File transcription is part of Waft Pro")
                .font(.sectionTitle)

            Text("Recordings and videos become text and subtitles, right on your Mac.")
                .font(.rowDetail)
                .opacity(0.9)

            Button("See Waft Pro", action: showPro)
                .buttonStyle(ProButtonStyle())
                .padding(.top, 10)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(LinearGradient.pro, in: shape)
    }
}
