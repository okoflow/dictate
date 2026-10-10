import DictateCore
import SwiftUI

struct PermissionRow: View {
    let permission: Permission
    let monitor: PermissionMonitor
    var offersRequest = true

    private var isGranted: Bool {
        monitor.status(of: permission).isGranted
    }

    var body: some View {
        SettingsRow(permission.title, description: permission.purpose) {
            if isGranted {
                Label {
                    Text("Allowed")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.success)
                }
                .font(.rowTitle)
            } else if offersRequest {
                Button("Allow…") {
                    Task { await monitor.request(permission) }
                }
            } else {
                Text("Not allowed yet")
                    .font(.rowTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
