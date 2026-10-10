import CoreGraphics
import DictateCore

package struct SystemKeyboardState: KeyboardState {
    package init() {}

    package func isHeld(_ key: PushToTalkKey) -> Bool {
        guard key.modifierFlag != nil else {
            return CGEventSource.keyState(.hidSystemState, key: CGKeyCode(truncatingIfNeeded: key.keyCode))
        }

        let hardwareFlags = CGEventSource.flagsState(.hidSystemState).rawValue
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState).rawValue

        return key.isHeld(in: hardwareFlags | sessionFlags)
    }
}
