import AppKit
import DictateCore
import SwiftUI

/// The mode of the app in front ("Mode in Chrome"), and the list of apps that have their own.
struct AppModeMenu: View {
    let dictation: DictationController

    var body: some View {
        let settings = dictation.appModes
        if let app = settings.frontmost, let bundle = app.bundleIdentifier {
            let name = app.localizedName ?? bundle
            let own = settings.modes.mode(for: bundle)
            Menu("Mode in \(name): \(own?.menuTitle ?? "as above")") {
                Picker("Mode in \(name)", selection: Binding(
                    get: { own },
                    set: { settings.set($0, for: bundle) }
                )) {
                    Text("Same as the menu (\(dictation.mode.mode.menuTitle))").tag(Mode?.none)
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.menuTitle).tag(Mode?.some(mode))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                if !settings.modes.modes.isEmpty {
                    Divider()
                    Text("Apps with their own mode (click to remove):")
                    ForEach(settings.modes.modes.keys.sorted(), id: \.self) { other in
                        Button("\(Self.name(of: other)): \(settings.modes.modes[other]?.menuTitle ?? "")") {
                            settings.set(nil, for: other)
                        }
                    }
                }
            }
        }
    }

    private static func name(of bundleIdentifier: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
            ?? bundleIdentifier
    }
}

/// The dictionary file, and the last dictations to copy again.
struct HistoryMenu: View {
    let dictation: DictationController

    var body: some View {
        Button("Dictionary & snippets…") {
            dictation.vocabulary.openForEditing()
        }
        let store = dictation.history
        Menu("History") {
            let recent = store.history.newest(10)
            if recent.isEmpty {
                Text(store.isEnabled ? "Nothing yet" : "History is off")
            }
            ForEach(Array(recent.enumerated()), id: \.offset) { _, entry in
                let time = entry.date.formatted(date: .omitted, time: .shortened)
                Button("\(time)  \(entry.mode.isCloud ? "☁︎ " : "")\(entry.menuTitle)") {
                    Clipboard.copy(entry.text)
                }
            }
            Divider()
            Toggle("Keep history", isOn: Bindable(store).isEnabled)
            Button("Clear history") {
                store.clear()
            }
            .disabled(store.history.entries.isEmpty)
        }
    }
}
