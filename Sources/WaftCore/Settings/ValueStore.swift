package protocol ValueStore<Value>: Sendable {
    associatedtype Value: Sendable

    func load() throws -> Value?
    func save(_ value: Value) throws
    func delete() throws
    func exists() -> Bool
}

extension ValueStore {
    package func exists() -> Bool {
        (try? load()) != nil
    }
}
