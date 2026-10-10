import Observation

@Observable
package final class OnboardingModel {
    package enum Step: Int, CaseIterable {
        case welcome
        case microphone
        case accessibility
        case practice
        case finish
    }

    package var step = Step.welcome
    package var practiceText = ""

    @ObservationIgnored var onFinish: (() -> Void)?

    package var isFirstStep: Bool {
        step == .welcome
    }

    package init() {}

    package func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            onFinish?()
        }
    }

    package func goBack() {
        if let previous = Step(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    func reset() {
        step = .welcome
        practiceText = ""
    }
}
