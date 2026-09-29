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

    var transcriptDirectory: URL {
        scratchDirectory.appendingPathComponent("dictate-transcripts")
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
        try? FileManager.default.removeItem(at: transcriptDirectory)
        let arguments = [
            "--report-file", reportURL.path,
            "--event-log", eventLogURL.path,
            "--recording-dir", recordingDirectory.path,
            "--input-device", "BlackHole 2ch",
            "--transcript-dir", transcriptDirectory.path,
        ]
        // `--transcript-dir` is honoured only with this variable: dictated text stays off disk otherwise.
        guard let app = dictate.launch(arguments: arguments, environment: ["DICTATE_E2E": "1"]) else {
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

    // MARK: Speech model

    /// The suite never downloads the model (about 0.6 GB): that is `make model`.
    func modelIsInstalled() -> Outcome {
        ModelStore.isInstalled(ModelStore.defaultModel, in: ModelStore.defaultBaseDirectory)
            ? .pass
            : .blocked("the speech model is not downloaded: run `make model`")
    }

    /// Waits for Dictate to load the model. The first load on a Mac compiles it for the chip, which
    /// takes about a minute; later loads take seconds.
    func modelIsReady(log: EventLog, timeout: TimeInterval = 180) -> Outcome {
        let start = Date()
        let loaded = waitUntil(timeout: timeout, interval: 0.25) {
            log.events.contains {
                if case .modelReady = $0 {
                    true
                } else {
                    false
                }
            }
        }
        guard loaded else { return .fail("the model was not loaded within \(Int(timeout)) s (app logged: \(log.events))") }
        return .measured(String(format: "model ready after waiting %.0f s", Date().timeIntervalSince(start)))
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
        // a background launch the focus while you work in another app, so keep asking via Accessibility.
        let isFrontmost = { (try? TestPadState.read(from: stateURL))?.isFrontmost == true }
        let pid = testPad.runningApplication?.processIdentifier
        let active = waitUntil(timeout: 5, interval: 0.5) {
            if isFrontmost() {
                return true
            }
            if let pid {
                Accessibility.bringToFront(Accessibility.application(pid: pid))
            }
            return isFrontmost()
        }
        guard active else {
            return .blocked("macOS did not let TestPad take focus (you may be using another app): click the TestPad window")
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
        AbortGuard.killApps()
    }
}
