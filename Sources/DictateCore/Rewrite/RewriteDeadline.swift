enum RewriteDeadline {
    static func run(_ deadline: Duration, _ operation: @escaping @Sendable () async throws -> String) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: deadline)

                throw RewriteError.timeout
            }

            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw RewriteError.timeout }

            return first
        }
    }
}
