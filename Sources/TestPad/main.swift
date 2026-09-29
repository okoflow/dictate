import AppKit
import DictateCore
import E2ESupport

/// A window with a text view and a password field. It exists so the E2E suite can prove
/// that text really arrives in a real macOS text control, including the secure one.
@MainActor
final class TestPadDelegate: NSObject, NSApplicationDelegate {
    private let stateURL: URL
    private let textView = NSTextView()
    private let passwordField = NSSecureTextField()
    private var lastWritten: TestPadState?

    init(stateURL: URL) {
        self.stateURL = stateURL
    }

    func applicationDidFinishLaunching(_: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "TestPad"
        window.center()
        window.contentView = makeContent()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate()
        window.makeFirstResponder(textView)

        // Polling instead of delegates: text set through Accessibility does not always
        // trigger `textDidChange`, and the state file must reflect what is really on screen.
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.writeStateIfChanged() }
        }
        writeStateIfChanged()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    private func makeContent() -> NSView {
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = .width
        textView.setAccessibilityIdentifier(TestPadState.textIdentifier)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        passwordField.placeholderString = "password"
        passwordField.setAccessibilityIdentifier(TestPadState.passwordIdentifier)
        passwordField.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(scroll)
        content.addSubview(passwordField)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: passwordField.topAnchor, constant: -12),
            passwordField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            passwordField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            passwordField.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
        return content
    }

    private func writeStateIfChanged() {
        let state = TestPadState(
            text: textView.string,
            password: passwordField.stringValue,
            isFrontmost: NSApp.isActive
        )
        guard state != lastWritten else { return }
        lastWritten = state
        try? state.write(to: stateURL)
    }
}

let stateURL = URL(
    fileURLWithPath: argumentValue(after: "--state-file")
        ?? NSTemporaryDirectory() + "dictate-testpad-state.json"
)
let delegate = TestPadDelegate(stateURL: stateURL)
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
