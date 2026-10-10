import os
import WaftCore

extension Logger {
    static let dictation = Logger(subsystem: AppIdentity.bundleIdentifier, category: "dictation")
    static let speechModel = Logger(subsystem: AppIdentity.bundleIdentifier, category: "speech-model")
    static let settings = Logger(subsystem: AppIdentity.bundleIdentifier, category: "settings")
}
