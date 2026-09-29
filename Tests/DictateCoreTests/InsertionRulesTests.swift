@testable import DictateCore
import Foundation
import Testing

struct SpacingTests {
    @Test func addsASpaceAfterAWordCharacter() {
        #expect(InsertionRules.prepared("hello", characterBeforeCaret: "d") == " hello")
        #expect(InsertionRules.prepared("привет", characterBeforeCaret: "т") == " привет")
        #expect(InsertionRules.prepared("안녕하세요", characterBeforeCaret: "요") == " 안녕하세요")
    }

    @Test func addsASpaceAfterPunctuationThatEndsASentence() {
        #expect(InsertionRules.prepared("Next", characterBeforeCaret: ".") == " Next")
        #expect(InsertionRules.prepared("Next", characterBeforeCaret: ",") == " Next")
    }

    @Test(arguments: [" ", "\n", "\t", "(", "[", "{", "<", "\"", "'", "‘", "“", "«", "„", "/"] as [Character])
    func addsNoSpaceAfter(character: Character) {
        #expect(InsertionRules.prepared("word", characterBeforeCaret: character) == "word")
    }

    @Test func addsNoSpaceAtTheStartOrWhenTheFieldCannotBeRead() {
        #expect(InsertionRules.prepared("word", characterBeforeCaret: nil) == "word")
    }

    @Test func trimsWhisperWhitespaceFirst() {
        #expect(InsertionRules.prepared("  hello world \n", characterBeforeCaret: "a") == " hello world")
        #expect(InsertionRules.prepared(" hello", characterBeforeCaret: nil) == "hello")
    }

    @Test func emptyTextStaysEmpty() {
        #expect(InsertionRules.prepared("  \n", characterBeforeCaret: "a").isEmpty)
    }
}

struct InsertionDecisionTests {
    private func decide(
        secure: Bool = false,
        accessibility: Bool = true,
        onTarget: Bool = true,
        held: Bool = false
    ) -> InsertionRules.Decision {
        InsertionRules.decide(
            focusedElementIsSecure: secure,
            accessibilityGranted: accessibility,
            focusStillOnTarget: onTarget,
            hotkeyStillHeld: held
        )
    }

    @Test func pastesWhenEverythingIsFine() {
        #expect(decide() == .paste)
    }

    @Test func aPasswordFieldNeverGetsText() {
        #expect(decide(secure: true) == .skip(.secureField))
        // Even when other things are wrong too, the password field is what gets reported.
        #expect(decide(secure: true, accessibility: false, onTarget: false, held: true) == .skip(.secureField))
    }

    @Test func aChangedFocusIsNotPastedInto() {
        #expect(decide(onTarget: false) == .skip(.focusChanged))
    }

    @Test func withoutAccessibilityNothingIsPasted() {
        #expect(decide(accessibility: false) == .skip(.noAccessibility))
    }

    @Test func aHeldHotkeyWouldTurnPasteIntoOptionPaste() {
        #expect(decide(held: true) == .skip(.hotkeyHeld))
    }

    @Test func focusComparesElementsWhenItCanAndProcessesOtherwise() {
        #expect(InsertionRules.focusStillOnTarget(elements: .same, targetPID: 5, currentPID: 5))
        #expect(!InsertionRules.focusStillOnTarget(elements: .different, targetPID: 5, currentPID: 5))
        #expect(InsertionRules.focusStillOnTarget(elements: .unknown, targetPID: 5, currentPID: 5))
        #expect(!InsertionRules.focusStillOnTarget(elements: .unknown, targetPID: 5, currentPID: 6))
        #expect(!InsertionRules.focusStillOnTarget(elements: .same, targetPID: 5, currentPID: 6))
    }
}

struct ClipboardRestoreTests {
    @Test func anOrdinaryClipboardIsRestored() {
        #expect(InsertionRules.restorePlan(currentTypes: ["public.utf8-plain-text"], snapshotBytes: 100) == .restore)
        #expect(InsertionRules.restorePlan(currentTypes: [], snapshotBytes: 0) == .restore)
    }

    @Test func aPasswordManagersItemIsLeftAlone() {
        for marker in [InsertionRules.concealedType, InsertionRules.transientType] {
            let plan = InsertionRules.restorePlan(currentTypes: ["public.utf8-plain-text", marker], snapshotBytes: 10)
            #expect(plan != .restore)
        }
    }

    @Test func theCapIsFiveMegabytesInclusive() {
        #expect(InsertionRules.restorePlan(currentTypes: [], snapshotBytes: InsertionRules.maximumSnapshotBytes) == .restore)
        #expect(InsertionRules.restorePlan(currentTypes: [], snapshotBytes: InsertionRules.maximumSnapshotBytes + 1) != .restore)
    }

    @Test func onlyTheAllowlistedTypesAreSaved() {
        let types = [
            "public.utf8-plain-text", "public.rtf", "dyn.ah62d4rv4gu8y",
            "com.apple.pasteboard.promised-file-url", "com.foo.private",
        ]
        #expect(InsertionRules.typesToSave(from: types) == ["public.utf8-plain-text", "public.rtf"])
    }

    @Test func tiffIsSkippedOnlyWhenAPngIsThere() {
        #expect(InsertionRules.typesToSave(from: ["public.tiff", "public.png"]) == ["public.png"])
        #expect(InsertionRules.typesToSave(from: ["public.tiff"]) == ["public.tiff"])
    }

    @Test func theMarkerTypesAreSavedSoTheyComeBack() {
        let types = [InsertionRules.concealedType, InsertionRules.transientType, InsertionRules.ownType]
        #expect(InsertionRules.typesToSave(from: types) == types)
    }

    @Test func aTextOnlyCopiedByDictateIsRestoredEvenThoughItIsConcealed() {
        let types = ["public.utf8-plain-text", InsertionRules.concealedType, InsertionRules.transientType, InsertionRules.ownType]
        #expect(InsertionRules.restorePlan(currentTypes: types, snapshotBytes: 20) == .restore)
    }

    @Test func restoresOnlyWhileTheChangeCountIsOurs() {
        #expect(InsertionRules.shouldRestore(changeCount: 7, expected: 7))
        #expect(!InsertionRules.shouldRestore(changeCount: 8, expected: 7))
    }
}

struct ReleaseWatchdogTests {
    @Test func aSingleMissedPollDoesNotEndTheHold() {
        var watchdog = ReleaseWatchdog()
        #expect(watchdog.poll(held: true, at: 0) == .holding)
        #expect(watchdog.poll(held: false, at: 0.25) == .holding)
        #expect(watchdog.poll(held: true, at: 0.5) == .holding)
    }

    @Test func fourPollsInARowDeclareTheReleaseFromTheFirstOne() {
        var watchdog = ReleaseWatchdog()
        #expect(watchdog.poll(held: false, at: 10.00) == .holding)
        #expect(watchdog.poll(held: false, at: 10.25) == .holding)
        #expect(watchdog.poll(held: false, at: 10.50) == .holding)
        #expect(watchdog.poll(held: false, at: 10.75) == .released(since: 10.00))
    }

    @Test func aHeldPollInTheMiddleStartsTheCountAgain() {
        var watchdog = ReleaseWatchdog()
        for time in [0.0, 0.25, 0.5] {
            _ = watchdog.poll(held: false, at: time)
        }
        #expect(watchdog.poll(held: true, at: 0.75) == .holding)
        #expect(watchdog.poll(held: false, at: 1.0) == .holding)
        #expect(watchdog.poll(held: false, at: 1.25) == .holding)
        #expect(watchdog.poll(held: false, at: 1.5) == .holding)
        #expect(watchdog.poll(held: false, at: 1.75) == .released(since: 1.0))
    }

    @Test func aTapEventWithTheKeyBitStartsTheCountAgain() {
        var watchdog = ReleaseWatchdog()
        for time in [0.0, 0.25, 0.5] {
            _ = watchdog.poll(held: false, at: time)
        }
        watchdog.sawHotkeyEvent()
        #expect(watchdog.poll(held: false, at: 0.75) == .holding)
    }
}

struct TranscriptHistoryTests {
    private let start = Date(timeIntervalSince1970: 1000)

    @Test func nothingAtFirst() {
        #expect(TranscriptHistory().latest(at: start) == nil)
    }

    @Test func theLatestTextWins() {
        var history = TranscriptHistory()
        history.remember("first", at: start)
        history.remember("second", at: start.addingTimeInterval(5))
        #expect(history.latest(at: start.addingTimeInterval(6)) == "second")
    }

    @Test func keepsOnlyTheLastFive() {
        var history = TranscriptHistory()
        for number in 1 ... 8 {
            history.remember("text \(number)", at: start)
        }
        #expect(history.count == 5)
        #expect(history.latest(at: start) == "text 8")
    }

    @Test func textsExpireAfterTenMinutes() {
        var history = TranscriptHistory()
        history.remember("old", at: start)
        #expect(history.latest(at: start.addingTimeInterval(600)) == "old")
        #expect(history.latest(at: start.addingTimeInterval(601)) == nil)
        history.remember("new", at: start.addingTimeInterval(500))
        #expect(history.latest(at: start.addingTimeInterval(601)) == "new")
    }
}
