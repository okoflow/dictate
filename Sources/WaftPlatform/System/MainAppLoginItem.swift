import ServiceManagement
import WaftCore

@MainActor
package final class MainAppLoginItem: LoginItem {
    package var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    package init() {}

    package func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }

        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
