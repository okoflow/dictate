package struct AudioInputDevice: Hashable, Identifiable, Sendable {
    package let id: String
    package let name: String

    package init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
