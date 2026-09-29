import ApplicationServices
import DictateCore
import E2ESupport
import Foundation

/// The checks that type into TestPad.
extension PushToTalkChecks {
    /// Option+letter must still type its character, and must not leave a recording running.
    func optionLetterPassesThrough() -> Outcome {
        run {
            _ = try session.environment()
            let element = try prepareTestPad()
            let baseline = log.baseline()
            do {
                try InputSource.using(InputSource.abc) {
                    keyboard.holding(.rightOption) {
                        Thread.sleep(forTimeInterval: 0.05)
                        keyboard.type(key: KeyboardDriver.letterA, holding: .rightOption)
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                    let typed = waitUntil(timeout: 3) { testPadState()?.text == "å" }
                    guard typed else {
                        throw Verdict.fail("expected TestPad to contain \"å\", it contains \"\(testPadState()?.text ?? "?")\"")
                    }
                }
            } catch let failure as InputSource.Failure {
                throw Verdict.blocked(failure.description)
            }
            let discarded = try session.waitFor(since: baseline, timeout: 2) { $0 == .recordingDiscarded(.otherKeyPressed) }
            guard discarded else {
                throw Verdict.fail("no recordingDiscarded(otherKeyPressed): \(log.newEvents(since: baseline))")
            }
            guard Accessibility.string("AXValue", of: element) == "å", testPadIsFrontmost() else {
                throw Verdict.fail("TestPad lost its text or focus")
            }
            return .pass
        }
    }

    /// Makes TestPad frontmost with an empty text view, so what appears there came from the keys.
    func prepareTestPad() throws -> AXUIElement {
        guard let pid = testPad.runningApplication?.processIdentifier else { throw Verdict.fail("TestPad is not running") }
        let app = Accessibility.application(pid: pid)
        Accessibility.bringToFront(app)
        guard waitUntil(timeout: 3, { testPadIsFrontmost() }) else { throw Verdict.fail("TestPad is not the frontmost app") }
        guard let element = Accessibility.waitForElement(identifier: TestPadState.textIdentifier, in: app),
              Accessibility.setValue("", of: element),
              waitUntil(timeout: 3, { testPadState()?.text == "" })
        else {
            throw Verdict.fail("cannot clear the TestPad text view")
        }
        return element
    }

    func testPadState() -> TestPadState? {
        try? TestPadState.read(from: testPadStateURL)
    }

    func testPadIsFrontmost() -> Bool {
        testPadState()?.isFrontmost == true
    }
}
