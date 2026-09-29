import Foundation

/// Cleans up after a run that is interrupted (Ctrl-C, `kill`): the suite holds Option down with
/// synthetic events and may have switched the keyboard layout, and Dictate and TestPad would
/// otherwise outlive the runner, with Dictate still recording.
///
/// The checks block the main thread, so the handlers run on a global queue. Where the default
/// disposition (terminate at once) is ignored first, so the handler is the only thing that runs.
enum AbortGuard {
    /// Releases any Option key left down by a previous run that died before its `defer` ran.
    static func healKeyboard() {
        KeyboardDriver().releaseAll()
    }

    /// Returns the signal sources; the caller must keep them alive for the whole run.
    static func install() -> [any DispatchSourceSignal] {
        [(SIGINT, Int32(130)), (SIGTERM, Int32(143))].map { signalNumber, exitCode in
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler {
                healKeyboard()
                InputSource.restorePending()
                killApps()
                exit(exitCode)
            }
            source.resume()
            return source
        }
    }

    /// Ends Dictate and TestPad by executable path rather than through `NSRunningApplication`, whose
    /// list can be stale in a tool without a run loop. Asks politely first, then insists.
    static func killApps() {
        for signal in ["-TERM", "-KILL"] {
            for name in ["Dictate", "TestPad"] {
                let pkill = Process()
                pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                pkill.arguments = [signal, "-f", "build/\(name)\\.app/Contents/MacOS/\(name)"]
                try? pkill.run()
                pkill.waitUntilExit()
            }
            if signal == "-TERM" {
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
}
