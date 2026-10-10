import os
import WaftCore

extension Logger {
    static let audio = Logger(subsystem: AppIdentity.bundleIdentifier, category: "audio")
    static let insertion = Logger(subsystem: AppIdentity.bundleIdentifier, category: "insertion")
    static let keyboard = Logger(subsystem: AppIdentity.bundleIdentifier, category: "keyboard")
    static let network = Logger(subsystem: AppIdentity.bundleIdentifier, category: "network")
}
