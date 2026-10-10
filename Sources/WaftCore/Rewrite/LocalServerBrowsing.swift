package protocol LocalServerBrowsing: Sendable {
    func models(at server: LocalServer) async -> [String]?
}
