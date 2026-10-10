@MainActor
package protocol GlobalShortcut: AnyObject {
    var title: String { get }

    func register(_ action: @escaping @MainActor () -> Void) -> Bool
}
