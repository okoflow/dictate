import DictateCore
import SwiftUI

struct KeyRecorderField: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    let key: PushToTalkKey
    let recorder: KeyRecorder
    let record: (PushToTalkKey) -> Void

    var body: some View {
        let shakes = !reducesMotion

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
                    .contentTransition(.symbolEffect(.replace))

                ZStack {
                    if recorder.isRecording {
                        Text("Press a key…")
                            .foregroundStyle(.secondary)
                            .phaseAnimator(reducesMotion ? [1.0] : [1.0, 0.45]) { content, opacity in
                                content.opacity(opacity)
                            } animation: { _ in
                                .easeInOut(duration: 0.9)
                            }
                            .transition(.opacity)
                    } else {
                        Text(key.title)
                            .transition(.blurReplace)
                    }
                }
                .font(.control)
            }
            .padding(.horizontal, Metrics.fieldPadding)
            .frame(minWidth: 160, minHeight: Metrics.controlHeight)
            .modifier(FieldChrome(isFocused: recorder.isRecording))
            .contentShape(Rectangle())
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: recorder.rejections) { content, offset in
                content.offset(x: shakes ? offset : 0)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-5, duration: 0.06)
                    LinearKeyframe(5, duration: 0.08)
                    LinearKeyframe(-3, duration: 0.08)
                    SpringKeyframe(0, duration: 0.18, spring: .snappy)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(Motion.feedback, value: recorder.isRecording)
        .animation(Motion.feedback, value: key)
        .help(recorder.isRecording ? Text("Press the key to use, or Esc to cancel") : Text("Click, then press the key to use"))
        .accessibilityLabel("Dictation key")
        .accessibilityValue(key.title)
    }
}
