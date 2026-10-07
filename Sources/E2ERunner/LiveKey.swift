import Foundation

/// The Anthropic API key for `E2E_LLM=live`: `ANTHROPIC_API_KEY`, else the app's Keychain item (macOS may ask
/// once whether the runner may read it). Only the proxy uses it, to forward requests; it is never printed.
enum LiveKey {
    static func read() -> String? {
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            return key
        }
        let security = Process()
        security.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        security.arguments = ["find-generic-password", "-s", "dev.dictate.app", "-a", "anthropic-api-key", "-w"]
        let output = Pipe()
        security.standardOutput = output
        security.standardError = Pipe()
        do {
            try security.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        security.waitUntilExit()
        guard security.terminationStatus == 0 else { return nil }
        let key = String(bytes: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return key.isEmpty ? nil : key
    }
}
