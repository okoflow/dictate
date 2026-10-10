import DictateCore
import SwiftUI

struct EditKeySection: View {
    @Bindable var settings: SettingsModel

    let keyRecorder: KeyRecorder
    let isLocked: Bool
    let showPro: () -> Void

    var body: some View {
        SettingsSection(
            "Editing by voice",
            subtitle: "Select text, hold the key and say what to change, like “make it shorter” or “translate into German”.",
        ) {
            SettingsRow("Hold to edit", description: keyRecorder.note(for: .edit)) {
                if isLocked {
                    Badge("Pro", tint: .purple)

                    Button("Unlock…", action: showPro)
                } else {
                    recorder
                }
            }
            .animation(Motion.feedback, value: settings.settings.editKey)
        }
    }

    @ViewBuilder
    private var recorder: some View {
        KeyRecorderField(
            field: .edit,
            key: settings.settings.editKey,
            takenKey: settings.settings.pushToTalkKey,
            recorder: keyRecorder,
        ) { key in
            settings.settings.editKey = key
        }

        if settings.settings.editKey != nil {
            RemoveButton(help: "Turn off editing by voice") {
                settings.settings.editKey = nil
            }
            .transition(.pop)
        }
    }
}

extension KeyRecorder {
    func note(for field: Field) -> LocalizedStringKey? {
        guard isRecording(field) else { return nil }

        if let rejection, rejection.field == field {
            return rejection.isTaken
                ? "That key is already in use. Choose another one."
                : "That key types text. Press a modifier, fn, or an F-key."
        }

        return "Press Option, Command, Shift or Control on either side, fn, or an F-key. Esc cancels."
    }
}
