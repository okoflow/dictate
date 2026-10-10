@MainActor
package protocol TextInserter: AnyObject {
    func insert(_ text: String, into target: FocusTarget, releasing key: PushToTalkKey) async -> InsertionOutcome
    func waitUntilIdle() async
}

package enum InsertionOutcome: Equatable, Sendable {
    case pasted
    case skipped(InsertionSkipReason)
}
