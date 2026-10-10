import SwiftUI

extension LocalizedStringKey {
    static func verbatim(_ text: String) -> LocalizedStringKey {
        "\(text)"
    }
}
