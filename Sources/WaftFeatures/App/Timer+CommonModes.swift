import Foundation

extension Timer {
    static func scheduledInCommonModes(
        every interval: TimeInterval,
        repeats: Bool,
        _ fire: @escaping @MainActor () -> Void,
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
            MainActor.assumeIsolated { fire() }
        }

        RunLoop.main.add(timer, forMode: .common)

        return timer
    }
}
