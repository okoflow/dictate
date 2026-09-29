@testable import DictateCore
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

    @Test(arguments: [" ", "\n", "\t", "(", "\"", "«", "„", "/", "["] as [Character])
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

    @Test func dynamicAndPromisedTypesAreNotRestorable() {
        #expect(InsertionRules.isRestorable(type: "public.utf8-plain-text"))
        #expect(!InsertionRules.isRestorable(type: "dyn.ah62d4rv4gu8y"))
        #expect(!InsertionRules.isRestorable(type: "com.apple.pasteboard.promised-file-url"))
        #expect(!InsertionRules.isRestorable(type: "NSPromisedFilesPboardType"))
    }

    @Test func restoresOnlyWhileTheChangeCountIsOurs() {
        #expect(InsertionRules.shouldRestore(changeCount: 7, expected: 7))
        #expect(!InsertionRules.shouldRestore(changeCount: 8, expected: 7))
    }
}
