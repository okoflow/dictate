import DictateCore
import SwiftUI

struct KeyRecorderField: View {
    let key: PushToTalkKey
    let recorder: KeyRecorder
    let record: (PushToTalkKey) -> Void

    var body: some View {
        Button {
            if recorder.isRecording {
                recorder.stop()
            } else {
                recorder.start(record)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: recorder.isRecording ? "record.circle" : "keyboard")
                    .font(.glyph)
                    .foregroundStyle(recorder.isRecording ? Color.accentColor : .secondary)
                    .symbolEffect(.pulse, isActive: recorder.isRecording)

                Text(recorder.isRecording ? "Press a key…" : key.title)
                    .font(.control)
                    .foregroundStyle(recorder.isRecording ? .secondary : .primary)
            }
            .padding(.horizontal, Metrics.fieldPadding)
            .frame(minWidth: 160, minHeight: Metrics.controlHeight)
            .modifier(FieldChrome(isFocused: recorder.isRecording))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(recorder.isRecording ? "Press the key to use, or Esc to cancel" : "Click, then press the key to use")
        .accessibilityLabel("Dictation key")
        .accessibilityValue(key.title)
    }
}
