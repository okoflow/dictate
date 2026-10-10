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

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "dictate" && url.host() == "activate" {
            let key = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "key" }?.value

            model.pro.draft = key ?? ""

            if let key {
                model.pro.activate(key)
            }

            model.windows.showSettings(.pro)
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        model.windows.showSettings()

        return false
    }
}
