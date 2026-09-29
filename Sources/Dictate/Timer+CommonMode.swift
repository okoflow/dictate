import Foundation

extension Timer {
    /// A timer that also fires while a menu is open or a control is being dragged. `scheduledTimer`
    /// runs only in the default run-loop mode, so it would freeze exactly when the user opens
    /// Dictate's own menu mid-recording.
    @MainActor
    static func commonModeTimer(interval: TimeInterval, repeats: Bool, _ fire: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
            MainActor.assumeIsolated { fire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
