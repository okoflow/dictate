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
    package private(set) var appleAvailability = OnDeviceModelAvailability.notSupported

    @ObservationIgnored private let browser: any LocalServerBrowsing
    @ObservationIgnored private let onDeviceModel: any OnDeviceModel

    init(browser: any LocalServerBrowsing, onDeviceModel: any OnDeviceModel) {
        self.browser = browser
        self.onDeviceModel = onDeviceModel
        appleAvailability = onDeviceModel.availability
    }

    func refreshApple() {
        appleAvailability = onDeviceModel.availability
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
