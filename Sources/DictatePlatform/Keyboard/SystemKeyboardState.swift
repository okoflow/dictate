import CoreGraphics
import DictateCore

package struct SystemKeyboardState: KeyboardState {
    package init() {}

    package func isHeld(_ key: PushToTalkKey) -> Bool {
        let hardwareFlags = CGEventSource.flagsState(.hidSystemState).rawValue
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState).rawValue

        return key.isMarked(in: hardwareFlags | sessionFlags)
    }
}
