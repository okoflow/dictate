import DictateCore
import SwiftUI

struct PermissionRow: View {
    let permission: Permission
    let monitor: PermissionMonitor

    private var isGranted: Bool {
        monitor.status(of: permission).isGranted
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                Text(permission.purpose)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Text("Allowed")
                    .foregroundStyle(.secondary)
            } else {
                Button("Allow…") {
                    Task { await monitor.request(permission) }
                }
            }
        }
    }
}
