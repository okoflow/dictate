import AppKit
import DictateCore
import Observation

@Observable
package final class ProModel {
    package enum ActivationProblem: Equatable {
        case unreadable
        case invalid
    }

    static let purchaseURL = URL(literal: "https://dictate.okoflow.com/pro")
    static let price = "$13.99"

    package private(set) var license: License?
    package private(set) var activationProblem: ActivationProblem?
    package var draft = ""

    @ObservationIgnored private let keyStore: any ValueStore<String>
    @ObservationIgnored private let checker: any LicenseSignatureChecking
    @ObservationIgnored private let trialStarted: Date

    package var trialEnds: Date {
        Calendar.current.date(byAdding: .day, value: ProAccess.trialLength, to: Calendar.current.startOfDay(for: trialStarted))
            ?? trialStarted
    }

    package var access: ProAccess {
        ProAccess(license: license, trialStarted: trialStarted, now: Date())
    }

    init(keyStore: any ValueStore<String>, trialStore: any ValueStore<Date>, checker: any LicenseSignatureChecking) {
        self.keyStore = keyStore
        self.checker = checker

        if let started = try? trialStore.load() {
            trialStarted = started
        } else {
            trialStarted = Date()
            try? trialStore.save(trialStarted)
        }

        license = (try? keyStore.load()).flatMap { Self.verifiedKey($0, checker: checker)?.license }
    }

    private static func verifiedKey(_ text: String, checker: any LicenseSignatureChecking) -> LicenseKey? {
        guard let key = LicenseKey(text), checker.isValid(key.signature, for: key.payload) else { return nil }

        return key
    }

    package func allows(_ feature: ProFeature) -> Bool {
        access.allows(feature)
    }

    @discardableResult
    package func activate(_ text: String) -> Bool {
        guard LicenseKey(text) != nil else {
            activationProblem = .unreadable

            return false
        }
        guard let key = Self.verifiedKey(text, checker: checker) else {
            activationProblem = .invalid

            return false
        }

        try? keyStore.save(text.trimmingCharacters(in: .whitespacesAndNewlines))
        license = key.license
        activationProblem = nil
        draft = ""

        return true
    }

    func deactivate() {
        try? keyStore.delete()
        license = nil
    }

    func clearProblem() {
        activationProblem = nil
    }

    func purchase() {
        NSWorkspace.shared.open(Self.purchaseURL)
    }
}
