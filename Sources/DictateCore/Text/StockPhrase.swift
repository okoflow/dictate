struct StockPhrase {
    let text: String
    let trailingWords: Int

    init(_ text: String, trailingWords: Int = 0) {
        self.text = text
        self.trailingWords = trailingWords
    }

    static func phrases(for language: Language) -> [StockPhrase] {
        phrasesByLanguage[language] ?? []
    }
}

extension StockPhrase {
    fileprivate static let phrasesByLanguage: [Language: [StockPhrase]] = [
        .chinese: [
            StockPhrase("请不吝点赞 订阅 转发 打赏支持明镜与点点栏目"),
            StockPhrase("請不吝點贊 訂閱 轉發 打賞支持明鏡與點點欄目"),
            StockPhrase("字幕由Amara.org社区提供"),
            StockPhrase("谢谢观看"),
            StockPhrase("謝謝觀看"),
            StockPhrase("字幕志愿者", trailingWords: 2),
        ],
        .dutch: [
            StockPhrase("Ondertitels ingediend door de Amara.org gemeenschap"),
            StockPhrase("Ondertiteld door", trailingWords: 3),
            StockPhrase("TV Gelderland", trailingWords: 1),
        ],
        .english: [
            StockPhrase("Thanks for watching"),
            StockPhrase("Thank you for watching"),
            StockPhrase("Please subscribe"),
            StockPhrase("Subtitles by the Amara.org community"),
        ],
        .french: [
            StockPhrase("Sous-titres réalisés par la communauté d'Amara.org"),
            StockPhrase("Sous-titres réalisés para la communauté d'Amara.org"),
            StockPhrase("Sous-titrage ST' 501"),
            StockPhrase("par SousTitreur.com"),
            StockPhrase("Merci d'avoir regardé cette vidéo"),
        ],
        .german: [
            StockPhrase("Untertitel im Auftrag des ZDF", trailingWords: 3),
            StockPhrase("Untertitel der Amara.org-Community"),
            StockPhrase("Untertitel von Stephanie Geiges"),
            StockPhrase("Copyright WDR", trailingWords: 1),
            StockPhrase("SWR", trailingWords: 1),
            StockPhrase("Vielen Dank fürs Ansehen"),
        ],
        .italian: [
            StockPhrase("Sottotitoli creati dalla comunità Amara.org"),
            StockPhrase("Sottotitoli e revisione a cura di QTSS"),
            StockPhrase("Grazie per la visione"),
        ],
        .japanese: [
            StockPhrase("ご視聴ありがとうございました"),
            StockPhrase("見てくれてありがとう"),
            StockPhrase("チャンネル登録をよろしくお願いします"),
        ],
        .korean: [
            StockPhrase("시청해 주셔서 감사합니다"),
            StockPhrase("구독과 좋아요 부탁드립니다"),
            StockPhrase("MBC 뉴스", trailingWords: 3),
        ],
        .polish: [
            StockPhrase("Napisy stworzone przez społeczność Amara.org"),
            StockPhrase("Dziękuję za oglądanie"),
        ],
        .portuguese: [
            StockPhrase("Legendas pela comunidade Amara.org"),
            StockPhrase("Legendas pela comunidade de Amara.org"),
            StockPhrase("Legendas pela comunidade do Amara.org"),
            StockPhrase("Obrigado por assistir"),
            StockPhrase("Obrigada por assistir"),
        ],
        .russian: [
            StockPhrase("Продолжение следует"),
            StockPhrase("Спасибо за просмотр"),
            StockPhrase("Подписывайтесь на наш канал"),
            StockPhrase("Субтитры сделал", trailingWords: 3),
            StockPhrase("Субтитры добавил", trailingWords: 3),
            StockPhrase("Субтитры создавал", trailingWords: 3),
            StockPhrase("Редактор субтитров", trailingWords: 3),
        ],
        .spanish: [
            StockPhrase("Subtítulos realizados por la comunidad de Amara.org"),
            StockPhrase("¡Gracias por ver el video!"),
            StockPhrase("Suscríbete al canal"),
            StockPhrase("www.alimmenta.com"),
        ],
        .ukrainian: [
            StockPhrase("Дякую за перегляд"),
            StockPhrase("Підписуйтесь на наш канал"),
            StockPhrase("Субтитрувальниця Оля Шор"),
        ],
    ]
}
