// 画面上の漢字語をタップしたときに見せる解説

import Foundation

/// 暦の用語ひとつ分の解説。
/// 漢字・読み・字の意味・本文の4つで、どの用語も同じ形に揃える
struct CalendarTerm: Identifiable, Hashable, Sendable {
    /// 同じ用語を続けて開いても差し替わるよう、漢字を識別子にする
    var id: String { kanji }

    let kanji: String
    let kana: String
    /// 日本語を読めない利用者向けの読み。ja では出さない
    let romaji: String
    /// 字の意味や位置づけを一言で示す補助行。無い用語もある
    let subtitle: LocalizedStringResource?
    let detail: LocalizedStringResource
    /// 制度そのものの説明。個々の値を開いたときに、何の一部なのかを添える
    let footnote: LocalizedStringResource?

    init(
        kanji: String,
        kana: String,
        romaji: String,
        subtitle: LocalizedStringResource? = nil,
        detail: LocalizedStringResource,
        footnote: LocalizedStringResource? = nil
    ) {
        self.kanji = kanji
        self.kana = kana
        self.romaji = romaji
        self.subtitle = subtitle
        self.detail = detail
        self.footnote = footnote
    }

    // LocalizedStringResource は Hashable ではないため合成に頼れない。
    // 解説文は漢字ごとに決まるので、漢字だけで同一性を判定する
    static func == (lhs: CalendarTerm, rhs: CalendarTerm) -> Bool {
        lhs.kanji == rhs.kanji
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kanji)
    }
}

/// 表示言語の判定。読みの出し分けを1か所にまとめる
enum CalendarTermLocale {
    static var isJapanese: Bool {
        Locale.current.language.languageCode?.identifier == "ja"
    }

    /// ja はかな、en はローマ字。かなを読めない利用者にはローマ字だけで足り、
    /// 併記すると行が長くなって特大で折り返すため、片方だけを出す
    static func reading(kana: String, romaji: String) -> String {
        isJapanese ? kana : romaji
    }
}
