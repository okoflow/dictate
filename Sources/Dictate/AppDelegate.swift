import AppKit
import DictateFeatures

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel(dependencies: .live())

    func applicationDidFinishLaunching(_: Notification) {
        model.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await model.prepareToQuit()

            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        model.windows.showSettings()

        return false
    }
}
