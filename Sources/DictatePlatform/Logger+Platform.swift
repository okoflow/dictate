import DictateCore
import os

extension Logger {
    static let audio = Logger(subsystem: AppIdentity.bundleIdentifier, category: "audio")
    static let insertion = Logger(subsystem: AppIdentity.bundleIdentifier, category: "insertion")
    static let keyboard = Logger(subsystem: AppIdentity.bundleIdentifier, category: "keyboard")
}
