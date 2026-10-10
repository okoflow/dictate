import DictateCore
import SwiftUI

struct InstructionsButton: View {
    let mode: Mode
    let provider: CloudProvider

    @Bindable var settings: SettingsModel

    let state: SettingsWindowState

    private var isPresented: Binding<Bool> {
        Binding(
            get: { state.editedInstructions == mode },
            set: { isPresented in
                if isPresented {
                    state.editedInstructions = mode
                } else if state.editedInstructions == mode {
                    state.editedInstructions = nil
                }
            },
        )
    }

    var body: some View {
        Button("Instructions…") {
            state.editedInstructions = mode
        }
        .popover(isPresented: isPresented, arrowEdge: .bottom) {
            InstructionsEditor(mode: mode, provider: provider, settings: settings) {
                state.editedInstructions = nil
            }
        }
    }
}

private struct InstructionsEditor: View {
    let mode: Mode
    let provider: CloudProvider

    @Bindable var settings: SettingsModel

    let close: () -> Void

    private var text: Binding<String> {
        Binding(
            get: { settings.settings.instructions.editableText(for: mode) },
            set: { settings.settings.instructions.set($0, for: mode) },
        )
    }

    private var isCustomized: Bool {
        settings.settings.instructions.isCustomized(mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title)
                    .font(.sectionTitle)

                Text("Instructions sent to \(provider.title) with your text.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }

            InputEditor(text: text, height: 200)
                .frame(width: 440)

            HStack {
                Button("Reset to Default") { settings.settings.instructions.reset(mode) }
                    .disabled(!isCustomized)

                Spacer()

                Button("Done", action: close)
                    .buttonStyle(PushButtonStyle(isProminent: true))
            }
        }
        .buttonStyle(PushButtonStyle())
        .padding(16)
    }
}
