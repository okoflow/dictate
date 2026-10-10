@MainActor
package protocol LoginItem: AnyObject {
    var isEnabled: Bool { get }

    func setEnabled(_ isEnabled: Bool) throws
}
