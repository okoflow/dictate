package struct FocusTarget: Sendable {
    package let processID: Int32
    package let bundleIdentifier: String?
    package let element: (any FocusedElement)?

    package init(processID: Int32, bundleIdentifier: String?, element: (any FocusedElement)?) {
        self.processID = processID
        self.bundleIdentifier = bundleIdentifier
        self.element = element
    }
}
