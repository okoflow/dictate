import Foundation

package enum AppIdentity {
    package static let name = "Waft"
    package static let bundleIdentifier = "com.okoflow.waft"

    package static var supportDirectory: URL {
        URL.applicationSupportDirectory.appending(path: name, directoryHint: .isDirectory)
    }
}
