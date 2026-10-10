import AppKit
import WaftFeatures

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel

    override init() {
        LegacyDataMigration.run()
        model = AppModel(dependencies: .live())

        super.init()
    }

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
        for url in urls where url.scheme == "waft" && url.host() == "activate" {
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
