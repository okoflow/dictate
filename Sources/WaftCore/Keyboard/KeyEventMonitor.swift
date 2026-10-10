@MainActor
package protocol KeyEventMonitor: AnyObject {
    var events: AsyncStream<KeyEvent> { get }
    var isRunning: Bool { get }

    func start() -> Bool
}
