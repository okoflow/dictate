@testable import DictateCore
import Testing

struct CommandLineTests {
    @Test func returnsValueAfterFlag() {
        #expect(argumentValue(after: "--state-file", in: ["app", "--state-file", "/tmp/x"]) == "/tmp/x")
    }

    @Test func returnsNilWhenFlagMissing() {
        #expect(argumentValue(after: "--state-file", in: ["app"]) == nil)
    }

    @Test func returnsNilWhenFlagIsLast() {
        #expect(argumentValue(after: "--state-file", in: ["app", "--state-file"]) == nil)
    }

    @Test func ignoresOtherFlags() {
        #expect(argumentValue(after: "--a", in: ["app", "--b", "1", "--a", "2"]) == "2")
    }
}
