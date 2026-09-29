import Foundation

/// A macOS privacy permission Dictate needs in order to work.
public enum Permission: String, CaseIterable, Codable, Sendable {
    case microphone
    case accessibility
    case inputMonitoring

    public var title: String {
        switch self {
        case .microphone: "Microphone"
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        }
    }

    /// Query item for the matching pane of System Settings
    /// (`x-apple.systempreferences:com.apple.preference.security?<anchor>`).
    public var settingsAnchor: String {
        switch self {
        case .microphone: "Privacy_Microphone"
        case .accessibility: "Privacy_Accessibility"
        case .inputMonitoring: "Privacy_ListenEvent"
        }
    }
}

public enum PermissionStatus: String, Codable, Sendable {
    case granted
    case denied
    case notDetermined

    public var isGranted: Bool {
        self == .granted
    }
}

/// A snapshot of every permission's status. Serialisable so the app can print it
/// (`Dictate --print-permissions`) and the E2E runner can read it back.
public struct PermissionReport: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let permission: Permission
        public let status: PermissionStatus

        public init(permission: Permission, status: PermissionStatus) {
            self.permission = permission
            self.status = status
        }
    }

    public let entries: [Entry]

    /// Builds a report by asking `statusOf` about every known permission.
    public init(statusOf: (Permission) -> PermissionStatus) {
        entries = Permission.allCases.map { Entry(permission: $0, status: statusOf($0)) }
    }

    public var missing: [Permission] {
        entries.filter { !$0.status.isGranted }.map(\.permission)
    }

    public var allGranted: Bool {
        missing.isEmpty
    }

    public func status(of permission: Permission) -> PermissionStatus {
        entries.first { $0.permission == permission }?.status ?? .notDetermined
    }

    /// Human-readable, one permission per line.
    public var summary: String {
        entries.map { "\($0.permission.title): \($0.status.rawValue)" }.joined(separator: "\n")
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(json: Data) throws -> PermissionReport {
        try JSONDecoder().decode(PermissionReport.self, from: json)
    }
}
