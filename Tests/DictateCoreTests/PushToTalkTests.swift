@testable import DictateCore
import Testing

struct HotkeyClassifyTests {
    private let rightDown = Hotkey.rightOptionDeviceFlag | Hotkey.optionFlag

    @Test func rightOptionPressIsHotkeyDown() {
        let event = RawKeyEvent(kind: .flagsChanged, keyCode: Hotkey.rightOptionKeyCode, flags: rightDown)
        #expect(Hotkey.classify(event) == .hotkeyDown)
    }

    @Test func rightOptionReleaseIsHotkeyUp() {
        let event = RawKeyEvent(kind: .flagsChanged, keyCode: Hotkey.rightOptionKeyCode, flags: 0)
        #expect(Hotkey.classify(event) == .hotkeyUp)
    }

    @Test func releaseWhileLeftOptionStillHeldIsHotkeyUp() {
        // Left Option keeps the generic Option flag, but the right-device bit is gone.
        let event = RawKeyEvent(kind: .flagsChanged, keyCode: Hotkey.rightOptionKeyCode, flags: Hotkey.optionFlag)
        #expect(Hotkey.classify(event) == .hotkeyUp)
    }

    @Test func rightOptionPressedWhileLeftOptionHeldIsHotkeyDown() {
        let flags = Hotkey.optionFlag | 0x20 | Hotkey.rightOptionDeviceFlag
        let event = RawKeyEvent(kind: .flagsChanged, keyCode: Hotkey.rightOptionKeyCode, flags: flags)
        #expect(Hotkey.classify(event) == .hotkeyDown)
    }

    @Test func leftOptionIsIgnored() {
        let event = RawKeyEvent(kind: .flagsChanged, keyCode: 58, flags: Hotkey.optionFlag)
        #expect(Hotkey.classify(event) == .ignored)
    }

    @Test func anyKeyDownIsOtherKey() {
        #expect(Hotkey.classify(RawKeyEvent(kind: .keyDown, keyCode: 0)) == .otherKeyDown)
    }

    @Test func tapDisabledEventsAreRecognised() {
        #expect(Hotkey.classify(RawKeyEvent(kind: .tapDisabledByTimeout)) == .tapDisabled)
        #expect(Hotkey.classify(RawKeyEvent(kind: .tapDisabledByUserInput)) == .tapDisabled)
    }

    @Test func otherEventsAreIgnored() {
        #expect(Hotkey.classify(RawKeyEvent(kind: .other)) == .ignored)
    }
}

struct PushToTalkTests {
    @Test func longPressRecords() {
        var ptt = PushToTalk()
        #expect(ptt.handle(.hotkeyDown, at: 10) == .startRecording)
        #expect(ptt.isHolding)
        #expect(ptt.handle(.hotkeyUp, at: 12.5) == .finishRecording(seconds: 2.5))
        #expect(!ptt.isHolding)
    }

    @Test func shortPressIsDiscarded() {
        var ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown, at: 0)
        #expect(ptt.handle(.hotkeyUp, at: 0.29) == .discardRecording(.tooShort))
    }

    @Test func exactlyMinimumPressRecords() {
        var ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown, at: 0)
        #expect(ptt.handle(.hotkeyUp, at: PushToTalk.minimumPress) == .finishRecording(seconds: PushToTalk.minimumPress))
    }

    @Test func combinationCancelsAndWaitsForRelease() {
        var ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown, at: 0)
        #expect(ptt.handle(.otherKeyDown, at: 0.5) == .discardRecording(.otherKeyPressed))
        #expect(ptt.handle(.otherKeyDown, at: 0.6) == nil)
        #expect(ptt.handle(.hotkeyUp, at: 1) == nil)
        // Armed again afterwards.
        #expect(ptt.handle(.hotkeyDown, at: 2) == .startRecording)
    }

    @Test func typingWithoutHotkeyDoesNothing() {
        var ptt = PushToTalk()
        #expect(ptt.handle(.otherKeyDown, at: 0) == nil)
        #expect(ptt.handle(.hotkeyUp, at: 0) == nil)
    }

    @Test func repeatedHotkeyDownWhileHoldingIsIgnored() {
        var ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown, at: 0)
        #expect(ptt.handle(.hotkeyDown, at: 0.5) == nil)
        #expect(ptt.handle(.hotkeyUp, at: 1) == .finishRecording(seconds: 1))
    }

    @Test func tapDisabledWhileHoldingStopsRecording() {
        var ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown, at: 0)
        #expect(ptt.handle(.tapDisabled, at: 1) == .discardRecording(.interrupted))
        #expect(!ptt.isHolding)
        #expect(ptt.handle(.hotkeyDown, at: 2) == .startRecording)
    }

    @Test func cancelledPressRestartsOnNewHotkeyDown() {
        // The release after a combination was lost; the next press must not be swallowed.
        var ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown, at: 0)
        _ = ptt.handle(.otherKeyDown, at: 0.5)
        #expect(ptt.handle(.hotkeyDown, at: 3) == .startRecording)
        #expect(ptt.handle(.hotkeyUp, at: 4) == .finishRecording(seconds: 1))
    }

    @Test func tapDisabledWhileCancelledReturnsToIdle() {
        var ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown, at: 0)
        _ = ptt.handle(.otherKeyDown, at: 0.5)
        #expect(ptt.handle(.tapDisabled, at: 1) == nil)
        #expect(ptt.handle(.hotkeyDown, at: 2) == .startRecording)
    }

    @Test func tapDisabledWhileIdleDoesNothing() {
        var ptt = PushToTalk()
        #expect(ptt.handle(.tapDisabled, at: 0) == nil)
        #expect(!ptt.isHolding)
    }

    @Test func ignoredSignalChangesNothing() {
        var ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown, at: 0)
        #expect(ptt.handle(.ignored, at: 0.1) == nil)
        #expect(ptt.isHolding)
    }
}
