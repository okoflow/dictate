package protocol FocusedElement: Sendable {
    var isSecureTextField: Bool { get }
    var characterBeforeCaret: Character? { get }
    var selectedText: String? { get }

    func compare(with other: any FocusedElement) -> FocusComparison
}

package enum FocusComparison: Sendable {
    case same
    case different
    case unknown
}
