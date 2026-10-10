import DictateCore
import SwiftUI

package struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    private let model: AppModel

    package init(model: AppModel) {
        self.model = model
    }

    package var body: some View {
        VStack(spacing: 0) {
            step
                .id(model.onboarding.step)
                .transition(reducesMotion ? .opacity : .opacity.combined(with: .offset(y: 10)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 56)
                .padding(.horizontal, 72)

            OnboardingFooter(model: model)
        }
        .animation(.smooth(duration: 0.35), value: model.onboarding.step)
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

    private var primaryTitle: String {
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
                    .buttonStyle(.borderedProminent)
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
            await model.permissions.request(permission)

            if permission == .microphone, model.permissions.status(of: .microphone) != .notDetermined {
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
