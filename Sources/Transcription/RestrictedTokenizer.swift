@preconcurrency import WhisperKit

/// A tokenizer that knows only some of Whisper's ~100 languages.
///
/// WhisperKit's `detectLangauge` picks the best of *all* languages and returns only that one, so a
/// Russian clip that Whisper takes for Ukrainian cannot be corrected afterwards. Its language filter
/// is built from `allLanguageTokens`, and that is the one place to narrow the choice down to ours:
/// the model then answers with the most probable of the allowed languages.
struct RestrictedTokenizer: WhisperTokenizer {
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
