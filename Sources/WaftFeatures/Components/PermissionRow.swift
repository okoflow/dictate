import SwiftUI
import WaftCore

struct PermissionRow: View {
    let permission: Permission
    let monitor: PermissionMonitor
    var offersRequest = true

    private var isGranted: Bool {
        monitor.status(of: permission).isGranted
    }

    var body: some View {
        SettingsRow(.verbatim(permission.title), description: .verbatim(permission.purpose)) {
            Group {
                if isGranted {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Palette.success)
                            .modifier(CheckmarkAppear())

                        Text("Allowed")
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                    .font(.rowTitle)
                } else if offersRequest {
                    Button("Allow…") {
                        Task { await monitor.request(permission) }
                    }
                    .transition(.opacity)
                } else {
                    Text("Not allowed yet")
                        .font(.rowTitle)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .animation(Motion.feedback, value: isGranted)
        }
    }
}
