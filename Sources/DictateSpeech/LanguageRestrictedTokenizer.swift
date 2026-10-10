@preconcurrency internal import WhisperKit

struct LanguageRestrictedTokenizer: WhisperTokenizer {
    let base: any WhisperTokenizer
    let allLanguageTokens: Set<Int>

    var specialTokens: SpecialTokens {
        base.specialTokens
    }

    func encode(text: String) -> [Int] {
        base.encode(text: text)
    }

    func decode(tokens: [Int]) -> String {
        base.decode(tokens: tokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        base.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        base.convertIdToToken(id)
    }

    func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        base.splitToWordTokens(tokenIds: tokenIds)
    }
}
