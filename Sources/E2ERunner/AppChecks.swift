import AppKit
import ApplicationServices
import DictateCore
import E2ESupport
import Foundation

/// The M0 checks: both apps start, permissions are reported, and Accessibility can drive TestPad.
@MainActor
struct AppChecks {
    let buildDirectory: URL
    let scratchDirectory: URL

    var dictate: AppLauncher {
        AppLauncher(
            bundleURL: buildDirectory.appendingPathComponent("Dictate.app"),
            bundleIdentifier: "dev.dictate.app"
        )
    }

    var testPad: AppLauncher {
        AppLauncher(
            bundleURL: buildDirectory.appendingPathComponent("TestPad.app"),
            bundleIdentifier: TestPadState.bundleIdentifier
        )
    }

    var eventLogURL: URL {
        scratchDirectory.appendingPathComponent("dictate-events.jsonl")
    }

    var recordingDirectory: URL {
        scratchDirectory.appendingPathComponent("dictate-recordings")
    }

    var stateURL: URL {
        scratchDirectory.appendingPathComponent("testpad-state.json")
    }

    private var reportURL: URL {
        scratchDirectory.appendingPathComponent("dictate-permissions.json")
    }

    // MARK: Dictate

    /// Launches Dictate and asserts it is a menu bar app (no Dock icon).
    func dictateLaunchesAsMenuBarApp() -> Outcome {
        try? FileManager.default.removeItem(at: reportURL)
        try? FileManager.default.removeItem(at: recordingDirectory)
        let arguments = [
            "--report-file", reportURL.path,
            "--event-log", eventLogURL.path,
            "--recording-dir", recordingDirectory.path,
            "--input-device", "BlackHole 2ch",
        ]
        guard let app = dictate.launch(arguments: arguments) else {
            return .fail("Dictate.app did not start within 10 s (is it built? run `make bundle`)")
        }
        guard app.activationPolicy == .accessory else {
            return .fail("expected accessory activation policy (LSUIElement), got \(app.activationPolicy.rawValue)")
        }
        return .pass
    }

    /// The app, launched by LaunchServices, writes its own permission report.
    func dictateReportsPermissions() -> Outcome {
        guard waitUntil(timeout: 5, { FileManager.default.fileExists(atPath: reportURL.path) }) else {
            return .fail("Dictate did not write \(reportURL.lastPathComponent)")
        }
        do {
            let report = try PermissionReport.decode(json: Data(contentsOf: reportURL))
            let reported = report.entries.map(\.permission)
            guard reported == Permission.allCases else {
                return .fail("report covers \(reported), expected \(Permission.allCases)")
            }
            return .pass
        } catch {
            return .fail("unreadable report: \(error)")
        }
    }

    func dictatePermissionsGranted() -> Outcome {
        guard let json = try? Data(contentsOf: reportURL),
              let report = try? PermissionReport.decode(json: json)
        else {
            return .fail("no permission report to inspect")
        }
        if report.allGranted {
            return .pass
        }
        let names = report.missing.map(\.title).joined(separator: ", ")
        return .blocked("Dictate.app lacks: \(names). Click the menu bar icon → Grant… (see README, Permissions)")
    }

    /// An ad-hoc signature pins permissions to one exact build (`cdhash`), so they reset on the next
    /// rebuild. A real identity pins them to the app's identifier and certificate instead.
    func dictateSignatureIsStable() -> Outcome {
        let codesign = Process()
        codesign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        codesign.arguments = ["-d", "-r-", dictate.bundleURL.path]
        let pipe = Pipe()
        codesign.standardOutput = pipe
        codesign.standardError = pipe
        do {
            try codesign.run()
        } catch {
            return .fail("cannot run codesign: \(error)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        codesign.waitUntilExit()
        let requirement = String(bytes: data, encoding: .utf8) ?? ""
        if requirement.contains("certificate leaf") {
            return .pass
        }
        return .blocked("Dictate.app is ad-hoc signed, so permissions reset on every rebuild: run `make signing`")
    }

    // MARK: TestPad

    func testPadLaunches() -> Outcome {
        try? FileManager.default.removeItem(at: stateURL)
        guard testPad.launch(arguments: ["--state-file", stateURL.path]) != nil else {
            return .fail("TestPad.app did not start (run `make bundle`)")
        }
        guard waitUntil(timeout: 5, { (try? TestPadState.read(from: stateURL)) != nil }) else {
            return .fail("TestPad did not write its state file")
        }
        // Text is typed into the frontmost app, so TestPad must really be active. macOS may refuse
        // a background launch the focus while you work in another app, so ask via Accessibility.
        let isFrontmost = { (try? TestPadState.read(from: stateURL))?.isFrontmost == true }
        if !waitUntil(timeout: 2, isFrontmost), let pid = testPad.runningApplication?.processIdentifier {
            Accessibility.bringToFront(Accessibility.application(pid: pid))
        }
        guard waitUntil(timeout: 3, isFrontmost) else {
            return .fail("TestPad did not become the active app")
        }
        return .pass
    }

    /// Writes into both TestPad controls through Accessibility and confirms the text really
    /// landed (via the app's own state file), then confirms the password field is secure.
    func testPadAccessibilityRoundTrip() -> Outcome {
        guard AXIsProcessTrusted() else {
            return .blocked(
                "Accessibility not granted to your terminal app: "
                    + "System Settings → Privacy & Security → Accessibility"
            )
        }
        guard let pid = testPad.runningApplication?.processIdentifier else {
            return .fail("TestPad is not running")
        }
        let app = Accessibility.application(pid: pid)
        let outcomes = [textViewRoundTrip(in: app), passwordFieldChecks(in: app)]
        return outcomes.first {
            if case .pass = $0 {
                false
            } else {
                true
            }
        } ?? .pass
    }

    private func textViewRoundTrip(in app: AXUIElement) -> Outcome {
        guard let element = Accessibility.waitForElement(identifier: TestPadState.textIdentifier, in: app) else {
            return .fail("text view not found in the accessibility tree")
        }
        let phrase = "привет hello 안녕"
        guard Accessibility.setValue(phrase, of: element) else {
            return .fail("AXValue on the text view is not settable")
        }
        guard waitUntil(timeout: 3, { (try? TestPadState.read(from: stateURL))?.text == phrase }) else {
            return .fail("text set via Accessibility never showed up in TestPad")
        }
        guard Accessibility.string("AXValue", of: element) == phrase else {
            return .fail("AXValue read-back differs from what was written")
        }
        return .pass
    }

    private func passwordFieldChecks(in app: AXUIElement) -> Outcome {
        guard let element = Accessibility.waitForElement(identifier: TestPadState.passwordIdentifier, in: app) else {
            return .fail("password field not found in the accessibility tree")
        }
        guard Accessibility.string("AXSubrole", of: element) == "AXSecureTextField" else {
            return .fail("password field is not exposed as AXSecureTextField")
        }
        guard Accessibility.setValue("s3cret", of: element),
              waitUntil(timeout: 3, { (try? TestPadState.read(from: stateURL))?.password == "s3cret" })
        else {
            return .fail("text set via Accessibility never reached the password field")
        }
        return .pass
    }

    func cleanUp() {
        dictate.terminate()
        testPad.terminate()
    }
}
