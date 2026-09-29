import DictateCore
import Foundation

@main
@MainActor
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--print-permissions") {
            printPermissionsAndExit()
        }
        if let path = LaunchOptions(arguments: CommandLine.arguments).reportFile {
            writeReport(to: URL(fileURLWithPath: path))
        }
        DictateApp.main()
    }

    /// Lets the E2E suite ask the *launched app* (not the terminal) which permissions it holds.
    private static func writeReport(to url: URL) {
        try? SystemPermissionChecker.currentReport().encodedJSON().write(to: url, options: .atomic)
    }

    /// Headless diagnostic used by the E2E suite and by users debugging a missing permission.
    /// Note: when run from a terminal, macOS attributes the answer to the terminal, not the app.
    private static func printPermissionsAndExit() -> Never {
        do {
            try FileHandle.standardOutput.write(SystemPermissionChecker.currentReport().encodedJSON())
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("failed to encode permissions: \(error)\n".utf8))
            exit(1)
        }
    }
}
