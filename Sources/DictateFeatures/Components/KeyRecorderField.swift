import DictateCore
import SwiftUI

struct KeyRecorderField: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    let field: KeyRecorder.Field
    let key: PushToTalkKey?
    let takenKey: PushToTalkKey?
    let recorder: KeyRecorder
    let record: (PushToTalkKey) -> Void

    private var isRecording: Bool {
        recorder.isRecording(field)
    }

    private var title: String {
        key?.title ?? String(localized: "None")
    }

    var body: some View {
        let shakes = !reducesMotion
        let rejections = recorder.rejections[field, default: 0]

        Button {
            if isRecording {
                recorder.stop()
            } else {
                recorder.start(field, excluding: takenKey, record)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isRecording ? "record.circle" : "keyboard")
                    .font(.glyph)
                    .foregroundStyle(isRecording ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))

                ZStack {
                    if isRecording {
                        Text("Press a key…")
                            .foregroundStyle(.secondary)
                            .phaseAnimator(reducesMotion ? [1.0] : [1.0, 0.45]) { content, opacity in
                                content.opacity(opacity)
                            } animation: { _ in
                                .easeInOut(duration: 0.9)
                            }
                            .transition(.opacity)
                    } else {
                        Text(title)
                            .foregroundStyle(key == nil ? .secondary : .primary)
                            .transition(.blurReplace)
                    }
                }
                .font(.control)
            }
            .padding(.horizontal, Metrics.fieldPadding)
            .frame(minWidth: 160, minHeight: Metrics.controlHeight)
            .modifier(FieldChrome(isFocused: isRecording))
            .contentShape(Rectangle())
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: rejections) { content, offset in
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
        .animation(Motion.feedback, value: isRecording)
        .animation(Motion.feedback, value: key)
        .help(isRecording ? Text("Press the key to use, or Esc to cancel") : Text("Click, then press the key to use"))
        .accessibilityLabel(field == .dictation ? Text("Dictation key") : Text("Editing key"))
        .accessibilityValue(title)
    }
}
