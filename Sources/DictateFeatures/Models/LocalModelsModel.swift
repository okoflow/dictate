import DictateCore
import Observation

@Observable
package final class LocalModelsModel {
    package enum ServerState: Equatable {
        case unknown
        case checking
        case running
        case notRunning
    }

    package private(set) var serverState = ServerState.unknown
    package private(set) var serverModels: [String] = []

    @ObservationIgnored private let browser: any LocalServerBrowsing

    init(browser: any LocalServerBrowsing) {
        self.browser = browser
    }

    func refresh(_ server: LocalServer) async {
        serverState = .checking

        let models = await browser.models(at: server)

        serverModels = models ?? []
        serverState = models == nil ? .notRunning : .running
    }

    func detect() async -> LocalServer? {
        serverState = .checking

        for known in LocalServer.knownServers {
            let server = LocalServer(baseURL: known.baseURL)

            if let models = await browser.models(at: server) {
                serverModels = models
                serverState = .running

                return LocalServer(baseURL: known.baseURL, model: models.first ?? "")
            }
        }

        serverModels = []
        serverState = .notRunning

        return nil
    }
}
