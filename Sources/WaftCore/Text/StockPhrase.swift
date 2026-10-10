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
        .arabic: [
            StockPhrase("ترجمة نانسي قنقر", trailingWords: 3),
            StockPhrase("شكرا للمشاهدة"),
            StockPhrase("شكرا على المشاهدة"),
            StockPhrase("اشتركوا في القناة"),
        ],
        .chinese: [
            StockPhrase("请不吝点赞 订阅 转发 打赏支持明镜与点点栏目"),
            StockPhrase("請不吝點贊 訂閱 轉發 打賞支持明鏡與點點欄目"),
            StockPhrase("字幕由Amara.org社区提供"),
            StockPhrase("谢谢观看"),
            StockPhrase("謝謝觀看"),
            StockPhrase("字幕志愿者", trailingWords: 2),
        ],
        .czech: [
            StockPhrase("Titulky vytvořil JohnyX"),
        ],
        .danish: [
            StockPhrase("Danske tekster af Nicolai Winther"),
            StockPhrase("Danske tekster af Jesper Buhl"),
            StockPhrase("Tak fordi du så med"),
            StockPhrase("Tak for at du så med"),
            StockPhrase("Takk for at du så på"),
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
        .finnish: [
            StockPhrase("Kiitos kun katsoit", trailingWords: 1),
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
        .greek: [
            StockPhrase("Υπότιτλοι AUTHORWAVE"),
            StockPhrase("AUTHORWAVE"),
            StockPhrase("Ευχαριστώ που παρακολουθήσατε"),
        ],
        .hindi: [
            StockPhrase("झाल", trailingWords: 3),
        ],
        .hungarian: [
            StockPhrase("Köszönöm, hogy megnézted"),
            StockPhrase("Köszi, hogy megnézted"),
            StockPhrase("Feliratok az Amara.org közösségétől"),
            StockPhrase("A feliratot készítette", trailingWords: 3),
            StockPhrase("Namaste"),
        ],
        .indonesian: [
            StockPhrase("Terima kasih telah menonton"),
            StockPhrase("Terima kasih sudah menonton"),
            StockPhrase("Sampai jumpa di video selanjutnya"),
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
        .malay: [
            StockPhrase("Terima kasih kerana menonton"),
            StockPhrase("Terima kasih telah menonton"),
            StockPhrase("Sari kata oleh", trailingWords: 3),
        ],
        .norwegian: [
            StockPhrase("Teksting av Nicolai Winther"),
            StockPhrase("Tekstet av Nicolai Winther"),
            StockPhrase("Norsk teksting av", trailingWords: 3),
            StockPhrase("Undertekster av", trailingWords: 2),
            StockPhrase("Takk for at du så på"),
            StockPhrase("Takk for at du så med"),
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
        .romanian: [
            StockPhrase("Să vă mulțumim pentru vizionare"),
            StockPhrase("Să vă mulțumesc pentru vizionare"),
            StockPhrase("Mulțumesc pentru vizionare"),
            StockPhrase("Mulțumim pentru vizionare"),
            StockPhrase("Mersi de vizionare"),
            StockPhrase("Să vă mulțumesc pentru like"),
            StockPhrase("Să ne vedem la următoarea mea", trailingWords: 1),
            StockPhrase("Să ne vedem în următoarea mea", trailingWords: 1),
            StockPhrase("Nu uitați să vă abonați", trailingWords: 3),
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
        .swedish: [
            StockPhrase("Textning.nu"),
            StockPhrase("Svensktextning.nu"),
            StockPhrase("Tack till elever och personal vid", trailingWords: 2),
            StockPhrase("Undertexter från Amara.org-gemenskapen"),
            StockPhrase("Tack för att du tittade"),
        ],
        .thai: [
            StockPhrase("ขอบคุณที่รับชม", trailingWords: 1),
            StockPhrase("โปรดติดตามตอนต่อไป"),
            StockPhrase("อย่าลืมกดติดตาม", trailingWords: 1),
            StockPhrase("อย่าลืมกดไลค์กดติดตาม"),
        ],
        .turkish: [
            StockPhrase("Altyazı M.K.", trailingWords: 4),
            StockPhrase("Çeviri ve Altyazı M.K."),
            StockPhrase("Abone olmayı unutmayın"),
            StockPhrase("Kanalıma abone olmayı unutmayın"),
            StockPhrase("İzlediğiniz için teşekkürler"),
            StockPhrase("İzlediğiniz için teşekkür ederim"),
        ],
        .ukrainian: [
            StockPhrase("Дякую за перегляд"),
            StockPhrase("Підписуйтесь на наш канал"),
            StockPhrase("Субтитрувальниця Оля Шор"),
        ],
        .vietnamese: [
            StockPhrase("Hãy subscribe cho kênh Ghiền Mì Gõ Để không bỏ lỡ những video hấp dẫn"),
            StockPhrase("Hãy subscribe cho kênh La La School Để không bỏ lỡ những video hấp dẫn"),
            StockPhrase("Hãy subscribe cho kênh lalaschool Để không bỏ lỡ những video hấp dẫn"),
            StockPhrase("Hãy đăng ký kênh để ủng hộ", trailingWords: 3),
            StockPhrase("Cảm ơn các bạn đã theo dõi"),
        ],
    ]
}
