@testable import DictateCore
import Foundation
import Testing

struct PermissionReportTests {
    private func report(_ overrides: [Permission: PermissionStatus] = [:]) -> PermissionReport {
        PermissionReport { overrides[$0] ?? .granted }
    }

    @Test func coversEveryPermissionExactlyOnce() {
        let all = report().entries.map(\.permission)
        #expect(all == Permission.allCases)
    }

    @Test func allGrantedWhenNothingMissing() {
        #expect(report().allGranted)
        #expect(report().missing.isEmpty)
    }

    @Test func missingListsDeniedAndUndetermined() {
        let partial = report([.microphone: .denied, .inputMonitoring: .notDetermined])
        #expect(!partial.allGranted)
        #expect(partial.missing == [.microphone, .inputMonitoring])
    }

    @Test func statusLookup() {
        let partial = report([.accessibility: .denied])
        #expect(partial.status(of: .accessibility) == .denied)
        #expect(partial.status(of: .microphone) == .granted)
    }

    @Test func statusOfUnknownPermissionFallsBackToNotDetermined() throws {
        let empty = try PermissionReport.decode(json: Data(#"{"entries":[]}"#.utf8))
        #expect(empty.status(of: .microphone) == .notDetermined)
    }

    @Test func summaryIsOneLinePerPermission() {
        let text = report([.microphone: .denied]).summary
        #expect(text == """
        Microphone: denied
        Accessibility: granted
        Input Monitoring: granted
        """)
    }

    @Test func jsonRoundTrip() throws {
        let original = report([.accessibility: .notDetermined])
        let decoded = try PermissionReport.decode(json: original.encodedJSON())
        #expect(decoded == original)
    }

    @Test func decodingGarbageThrows() {
        #expect(throws: (any Error).self) {
            try PermissionReport.decode(json: Data("not json".utf8))
        }
    }

    @Test func settingsAnchorsAreDistinct() {
        let anchors = Permission.allCases.map(\.settingsAnchor)
        #expect(Set(anchors).count == anchors.count)
        #expect(anchors.allSatisfy { $0.hasPrefix("Privacy_") })
    }

    @Test func titlesAreNonEmpty() {
        #expect(Permission.allCases.allSatisfy { !$0.title.isEmpty })
    }
}
