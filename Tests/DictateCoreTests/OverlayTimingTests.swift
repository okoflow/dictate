@testable import DictateCore
import Testing

struct OverlayTimingTests {
    @Test func shortTextsStayTwoSeconds() {
        #expect(OverlayTiming.messageSeconds(characters: 0) == 2)
    }

    @Test func everyFifteenCharactersAddASecond() {
        #expect(abs(OverlayTiming.messageSeconds(characters: 15) - 3) < 1e-9)
        #expect(abs(OverlayTiming.messageSeconds(characters: 60) - 6) < 1e-9)
    }

    @Test func neverLongerThanTenSeconds() {
        #expect(OverlayTiming.messageSeconds(characters: 120) == 10)
        #expect(OverlayTiming.messageSeconds(characters: 5000) == 10)
    }
}
