import AppKit
import DictateCore
import SwiftUI

package struct OnboardingView: View {
    private let model: AppModel

    package init(model: AppModel) {
        self.model = model
    }

    package var body: some View {
        VStack(spacing: 0) {
            step
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 56)
                .padding(.top, 48)

            OnboardingFooter(model: model)
        }
        .frame(width: 580, height: 460)
    }

    @ViewBuilder
    private var step: some View {
        switch model.onboarding.step {
        case .welcome:
            WelcomeStep(onboarding: model.onboarding, keyTitle: model.settings.settings.pushToTalkKey.shortTitle)
        case .microphone:
            PermissionStep(permission: .microphone, symbolName: "mic.circle.fill", model: model)
        case .accessibility:
            PermissionStep(permission: .accessibility, symbolName: "keyboard.badge.ellipsis", model: model)
        case .practice:
            PracticeStep(model: model)
        case .finish:
            FinishStep(model: model)
        }
    }
}

private struct StepLayout<Content: View, Actions: View>: View {
    let symbol: Image
    let title: String
    let message: String
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 14) {
            symbol
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.tint)

            Text(title)
                .font(.title.weight(.semibold))

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            content

            Spacer(minLength: 0)

            actions
                .controlSize(.large)
        }
    }
}

private struct WelcomeStep: View {
    let onboarding: OnboardingModel
    let keyTitle: String

    var body: some View {
        StepLayout(
            symbol: Image(nsImage: NSApp.applicationIconImage),
            title: "Welcome to Dictate",
            message: "Your words appear wherever you type. Speech is recognized right on your Mac.",
        ) {
            HStack(spacing: 32) {
                GestureHint(symbolName: "option", title: "Hold \(keyTitle)")
                GestureHint(symbolName: "waveform", title: "Speak")
                GestureHint(symbolName: "text.cursor", title: "Let go")
            }
            .padding(.top, 14)
        } actions: {
            Button("Get Started") { onboarding.advance() }
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct GestureHint: View {
    let symbolName: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(title)
                .font(.callout)
        }
    }
}

private struct PermissionStep: View {
    let permission: Permission
    let symbolName: String
    let model: AppModel

    private var isGranted: Bool {
        model.permissions.status(of: permission).isGranted
    }

    private var title: String {
        switch permission {
        case .microphone: "Allow the microphone"
        case .accessibility: "Allow Accessibility"
        }
    }

    private var message: String {
        switch permission {
        case .microphone:
            "Dictate listens only while you hold the dictation key, and the audio never leaves your Mac."
        case .accessibility:
            """
            Dictate needs it to notice the dictation key and to paste the text where you type. \
            On macOS 27 it is listed under Device Control and Data Access.
            """
        }
    }

    var body: some View {
        StepLayout(symbol: Image(systemName: symbolName), title: title, message: message) {
            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } actions: {
            if isGranted {
                Button("Continue") { model.onboarding.advance() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") {
                    Task { await request() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func request() async {
        await model.permissions.request(permission)

        if permission == .microphone, model.permissions.status(of: .microphone) != .notDetermined {
            model.onboarding.advance()
        }
    }
}

private struct PracticeStep: View {
    @Bindable private var onboarding: OnboardingModel

    let model: AppModel

    private var message: String {
        let key = model.settings.settings.pushToTalkKey.shortTitle

        guard model.speechModel.state.isReady else {
            return "As soon as the speech model is ready, click the box, hold \(key) and say “Hello, Dictate”."
        }

        return "Click the box, hold \(key) and say “Hello, Dictate”. Let go, and the text appears."
    }

    init(model: AppModel) {
        self.model = model
        onboarding = model.onboarding
    }

    var body: some View {
        StepLayout(symbol: Image(systemName: "text.cursor"), title: "Try it", message: message) {
            TextField("Your words appear here", text: $onboarding.practiceText, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
                .padding(.top, 6)
        } actions: {
            Button("Continue") { onboarding.advance() }
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct FinishStep: View {
    let model: AppModel

    private var launchesAtLogin: Binding<Bool> {
        Binding(get: { model.settings.launchesAtLogin }, set: { model.settings.setLaunchesAtLogin($0) })
    }

    var body: some View {
        StepLayout(
            symbol: Image(systemName: "checkmark.seal.fill"),
            title: "You're all set",
            message: "Dictate lives in the menu bar. Switch modes there or press \(model.modeSwitcher.shortcutTitle) anywhere.",
        ) {
            Toggle("Open Dictate at login", isOn: launchesAtLogin)
                .toggleStyle(.checkbox)
                .padding(.top, 6)
        } actions: {
            HStack {
                Button("Set Up Cleanup Modes…") {
                    model.onboarding.advance()
                    model.windows.showSettings(.modes)
                }

                Button("Done") { model.onboarding.advance() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct OnboardingFooter: View {
    let model: AppModel

    private var modelStatus: String {
        model.speechModel.state.isReady ? "Speech model ready" : model.speechModel.state.statusText
    }

    var body: some View {
        HStack {
            Button("Back") { model.onboarding.goBack() }
                .buttonStyle(.borderless)
                .opacity(model.onboarding.isFirstStep ? 0 : 1)
                .disabled(model.onboarding.isFirstStep)

            Spacer()

            PageDots(count: OnboardingModel.Step.allCases.count, current: model.onboarding.step.rawValue)

            Spacer()

            Text(modelStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: 7, height: 7)
            }
        }
    }
}
