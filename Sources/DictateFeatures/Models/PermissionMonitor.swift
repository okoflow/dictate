import DictateCore
import Foundation
import Observation

@Observable
package final class PermissionMonitor {
    private static let pollInterval: TimeInterval = 1

    package private(set) var statuses: [Permission: PermissionStatus] = [:]

    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let provider: any PermissionProvider
    @ObservationIgnored private var timer: Timer?

    package var missing: [Permission] {
        Permission.allCases.filter { !status(of: $0).isGranted }
    }

    package var allGranted: Bool {
        missing.isEmpty
    }

    init(provider: any PermissionProvider) {
        self.provider = provider

        refresh()
    }

    package func status(of permission: Permission) -> PermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    package func request(_ permission: Permission) async {
        await provider.request(permission)

        refresh()
    }

    func startMonitoring() {
        guard timer == nil else { return }

        timer = .scheduledInCommonModes(every: Self.pollInterval, repeats: true) { [weak self] in
            self?.refresh()
        }
    }

    func refresh() {
        let latest = Dictionary(uniqueKeysWithValues: Permission.allCases.map { ($0, provider.status(of: $0)) })
        guard latest != statuses else { return }

        statuses = latest

        onChange?()
    }
}
