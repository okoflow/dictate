import SwiftUI
import WaftCore

package struct OnboardingView: View {
    private let model: AppModel

    package init(model: AppModel) {
        self.model = model
    }

    package var body: some View {
        VStack(spacing: 0) {
            step
                .id(model.onboarding.step)
                .transition(StepTransition())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 56)
                .padding(.horizontal, 72)

            OnboardingFooter(model: model)
        }
        .animation(Motion.page, value: model.onboarding.step)
        .buttonStyle(PushButtonStyle())
        .reducedMotionPolicy()
        .frame(width: 640, height: 540)
        .background(Palette.window)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var step: some View {
        switch model.onboarding.step {
        case .welcome:
            WelcomeStep(keyTitle: model.settings.settings.pushToTalkKey.shortTitle)
        case .microphone:
            PermissionStep(permission: .microphone, monitor: model.permissions)
        case .accessibility:
            PermissionStep(permission: .accessibility, monitor: model.permissions)
        case .practice:
            PracticeStep(model: model)
        case .finish:
            FinishStep(model: model)
        }
    }
}

private struct OnboardingFooter: View {
    let model: AppModel

    private var onboarding: OnboardingModel {
        model.onboarding
    }

    private var missingPermission: Permission? {
        let permission: Permission? = switch onboarding.step {
        case .microphone: .microphone
        case .accessibility: .accessibility
        default: nil
        }

        return permission.flatMap { model.permissions.status(of: $0).isGranted ? nil : $0 }
    }

    private var primaryTitle: LocalizedStringKey {
        if let permission = missingPermission {
            return permission == .microphone ? "Allow Microphone" : "Open System Settings"
        }

        return switch onboarding.step {
        case .welcome: "Get Started"
        case .finish: "Done"
        default: "Continue"
        }
    }

    var body: some View {
        ZStack {
            PageDots(count: OnboardingModel.Step.allCases.count, current: onboarding.step.rawValue)

            HStack {
                Button("Back") { onboarding.goBack() }
                    .opacity(onboarding.isFirstStep ? 0 : 1)
                    .disabled(onboarding.isFirstStep)

                Spacer()

                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(PushButtonStyle(isProminent: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private func primaryAction() {
        guard let permission = missingPermission else {
            onboarding.advance()

            return
        }

        Task {
            let step = onboarding.step
            await model.permissions.request(permission)

            let status = model.permissions.status(of: permission)
            guard permission == .microphone, status != .notDetermined else { return }

            if status.isGranted {
                try? await Task.sleep(for: .milliseconds(600))
            }

            if onboarding.step == step {
                onboarding.advance()
            }
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: index == current ? 18 : 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}
