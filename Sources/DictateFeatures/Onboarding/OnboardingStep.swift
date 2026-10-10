import AppKit
import DictateCore
import SwiftUI

struct OnboardingStep<Hero: View, Content: View>: View {
    let title: String
    let message: String
    @ViewBuilder let hero: Hero
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            hero

            Text(title)
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 20)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            content
                .padding(.top, 28)
        }
        .frame(maxWidth: 480)
    }
}

struct WelcomeStep: View {
    let keyTitle: String

    var body: some View {
        OnboardingStep(title: "Welcome to Dictate", message: "Your words appear wherever you type.") {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
        } content: {
            SettingsCard {
                GestureRow(symbolName: "option", tint: .gray, title: "Hold \(keyTitle)", detail: "In any app, wherever you type")
                RowDivider()
                GestureRow(symbolName: "waveform", tint: .red, title: "Speak", detail: "Whisper listens right on your Mac")
                RowDivider()
                GestureRow(symbolName: "text.cursor", tint: .blue, title: "Let go", detail: "The text appears at the cursor")
            }
        }
    }
}

struct PermissionStep: View {
    let permission: Permission
    let monitor: PermissionMonitor

    private var title: String {
        switch permission {
        case .microphone: "Allow the microphone"
        case .accessibility: "Allow Accessibility"
        }
    }

    private var message: String {
        switch permission {
        case .microphone:
            "Dictate listens only while you hold the key, and the audio stays on your Mac."
        case .accessibility:
            "To notice the key and paste the text. On macOS 27 it is under Device Control and Data Access."
        }
    }

    var body: some View {
        OnboardingStep(title: title, message: message) {
            switch permission {
            case .microphone: IconTile(symbolName: "mic.fill", tint: .red, size: 72)
            case .accessibility: IconTile(symbolName: "accessibility", tint: .blue, size: 72)
            }
        } content: {
            SettingsCard {
                PermissionRow(permission: permission, monitor: monitor, offersRequest: false)
            }
        }
    }
}

struct PracticeStep: View {
    @Bindable private var onboarding: OnboardingModel
    @FocusState private var isTyping: Bool

    let model: AppModel

    private var message: String {
        let key = model.settings.settings.pushToTalkKey.shortTitle

        guard model.speechModel.state.isReady else {
            return "When the speech model is ready, click the box, hold \(key) and say “Hello, Dictate”."
        }

        return "Click the box, hold \(key) and say “Hello, Dictate”."
    }

    private var modelStatus: String {
        model.speechModel.state.isReady ? "Speech model ready" : model.speechModel.state.statusText
    }

    init(model: AppModel) {
        self.model = model
        onboarding = model.onboarding
    }

    var body: some View {
        OnboardingStep(title: "Try it", message: message) {
            IconTile(symbolName: "text.cursor", tint: .purple, size: 72)
        } content: {
            VStack(spacing: 10) {
                TextField("Your words appear here", text: $onboarding.practiceText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .lineLimit(4, reservesSpace: true)
                    .focused($isTyping)
                    .padding(14)
                    .modifier(FieldChrome(isFocused: isTyping, cornerRadius: 12))

                Text(modelStatus)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FinishStep: View {
    let model: AppModel

    private var launchesAtLogin: Binding<Bool> {
        Binding(get: { model.settings.launchesAtLogin }, set: { model.settings.setLaunchesAtLogin($0) })
    }

    var body: some View {
        OnboardingStep(
            title: "You're all set",
            message: "Dictate lives in the menu bar. \(model.modeSwitcher.shortcutTitle) switches modes.",
        ) {
            IconTile(symbolName: "checkmark", tint: .green, size: 72)
        } content: {
            SettingsCard {
                ToggleRow("Open at login", isOn: launchesAtLogin)
                RowDivider()
                SettingsRow("Cleanup modes", description: "Clean, Formal and Translate use Claude or OpenAI.") {
                    Button("Set Up…") {
                        model.onboarding.advance()
                        model.windows.showSettings(.writing)
                    }
                }
            }
        }
    }
}

private struct GestureRow: View {
    let symbolName: String
    let tint: TileTint
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbolName: symbolName, tint: tint, size: 28)

            RowLabel(title: title, description: detail)

            Spacer(minLength: 0)
        }
        .settingsRowPadding()
    }
}
