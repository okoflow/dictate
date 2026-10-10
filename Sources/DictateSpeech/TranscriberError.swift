import Foundation

enum TranscriberError: LocalizedError {
    case modelMissing(String)
    case notLoaded
    case tokenizerMissing
    case languageTokensMissing

    var errorDescription: String? {
        switch self {
        case let .modelMissing(model): "The speech model \(model) isn't downloaded."
        case .notLoaded: "The speech model isn't loaded."
        case .tokenizerMissing: "The speech model has no tokenizer."
        case .languageTokensMissing: "The speech model doesn't know one of the chosen languages."
        }
    }
}
