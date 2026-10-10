import SwiftUI

enum Motion {
    static let feedback = Animation.snappy(duration: 0.2)
    static let layout = Animation.smooth(duration: 0.3)
    static let page = Animation.smooth(duration: 0.4)
    static let fade = Animation.easeOut(duration: 0.15)
    static let meter = Animation.smooth(duration: 0.12)
    static let reduced = Animation.easeInOut(duration: 0.15)
}

struct ReducedMotionPolicy: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        let reducesMotion = reducesMotion

        content.transaction { transaction in
            if reducesMotion, transaction.animation != nil {
                transaction.animation = Motion.reduced
            }
        }
    }
}

struct CheckmarkAppear: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.transition(.symbolEffect(.drawOn))
        } else {
            content.transition(.symbolEffect(.appear))
        }
    }
}

struct RevealTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .offset(y: phase.isIdentity ? 0 : -4)
    }
}

struct PopTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : 0.85)
    }
}

struct StepTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .offset(y: phase.value * -8)
    }
}

struct PillTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase == .willAppear ? 0.9 : phase == .didDisappear ? 0.96 : 1, anchor: .bottom)
            .offset(y: phase == .willAppear ? 8 : 0)
    }
}

extension Transition where Self == RevealTransition {
    static var reveal: RevealTransition {
        RevealTransition()
    }
}

extension Transition where Self == PopTransition {
    static var pop: PopTransition {
        PopTransition()
    }
}

extension View {
    func reducedMotionPolicy() -> some View {
        modifier(ReducedMotionPolicy())
    }

    func rowTransition() -> some View {
        transition(AsymmetricTransition(
            insertion: .reveal.animation(Motion.layout.delay(0.05)),
            removal: .reveal.animation(Motion.fade),
        ))
    }
}
