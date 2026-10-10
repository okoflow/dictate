import Foundation

package struct TimedSegment: Equatable, Sendable {
    package let start: TimeInterval
    package let end: TimeInterval
    package let text: String

    package init(start: TimeInterval, end: TimeInterval, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}
