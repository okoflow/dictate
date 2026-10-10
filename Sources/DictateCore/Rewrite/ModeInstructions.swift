import Foundation

package struct ModeInstructions: Codable, Equatable, Sendable {
    private var custom: [String: String] = [:]

    package init() {}

    package func text(for mode: Mode) -> String {
        guard let text = custom[mode.rawValue], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return RewritePrompt.defaultInstructions(for: mode)
        }

        return text
    }

    package func editableText(for mode: Mode) -> String {
        custom[mode.rawValue] ?? RewritePrompt.defaultInstructions(for: mode)
    }

    package func isCustomized(_ mode: Mode) -> Bool {
        custom[mode.rawValue] != nil
    }

    package mutating func set(_ text: String, for mode: Mode) {
        custom[mode.rawValue] = text == RewritePrompt.defaultInstructions(for: mode) ? nil : text
    }

    package mutating func reset(_ mode: Mode) {
        custom[mode.rawValue] = nil
    }
}
