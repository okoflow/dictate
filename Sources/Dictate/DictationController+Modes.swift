import DictateCore
import Foundation

/// Switching modes: the menu writes `mode` directly; ⌃⌥M cycles it; apps can have their own; the E2E suite sets
/// it and dictates files.
extension DictationController {
    // MARK: Modes

    func installModeSwitching() {
        mode.onChange = { [weak self] mode in self?.eventLog.log(.modeChanged(mode)) }
        let hotkey = ModeHotkey { [weak self] in self?.switchToNextMode() }
        if hotkey.start() {
            modeHotkey = hotkey
        }
        guard options.acceptsTestControl else { return }
        TestControl.install(
            onDictateFile: { [weak self] path in self?.dictateFile(at: path) },
            onSetMode: { [weak self] mode in self?.mode.mode = mode }
        )
    }

    /// Whether ⌃⌥M is ours (another app may hold it); the menu says so.
    var modeHotkeyAvailable: Bool {
        modeHotkey != nil
    }

    private func switchToNextMode() {
        mode.mode = mode.mode.next
        overlay.show(message: "Mode: \(mode.mode.menuTitle)")
    }

    /// Test-only: the file's audio goes down the same path as a recording, with the current language and mode.
    private func dictateFile(at path: String) {
        guard models.state.isReady, let samples = TestControl.samples(ofWAVAt: path) else {
            eventLog.log(.transcriptionFailed("cannot dictate \(path): model not ready or not a 16 kHz mono WAV"))
            return
        }
        eventLog.log(.fileSubmitted(file: path))
        submit(samples, target: FocusProbe.current())
    }

    /// Hands a recording to the pipeline with the current language and dictionary, in the target app's own mode
    /// if it has one, otherwise in the menu's.
    func submit(_ samples: [Float], target: FocusSnapshot) {
        var chosen = mode.mode
        if let app = target.bundleIdentifier, let own = appModes.modes.mode(for: app) {
            chosen = own
            eventLog.log(.appModeUsed(app: app, mode: own))
        }
        pipeline.submit(
            samples: samples, language: language.preference.language, mode: chosen, vocabulary: vocabulary.current, target: target
        )
    }
}
