import Foundation

package enum AppIdentity {
    package static let name = "Dictate"
    package static let bundleIdentifier = "dev.dictate.app"

    package static var supportDirectory: URL {
        URL.applicationSupportDirectory.appending(path: name, directoryHint: .isDirectory)
    }
}
