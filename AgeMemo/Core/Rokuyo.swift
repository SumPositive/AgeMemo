// 六曜（大安・仏滅など）を求める

import Foundation

enum Rokuyo: Int, CaseIterable, Identifiable, Sendable {
    case taian
    case shakko
    case sensho
    case tomobiki
    case sakimake
    case butsumetsu

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .taian: "大安"
        case .shakko: "赤口"
        case .sensho: "先勝"
        case .tomobiki: "友引"
        case .sakimake: "先負"
        case .butsumetsu: "仏滅"
        }
    }

    var kana: String {
        switch self {
        case .taian: "たいあん"
        case .shakko: "しゃっこう"
        case .sensho: "せんしょう"
        case .tomobiki: "ともびき"
        case .sakimake: "せんぶ"
        case .butsumetsu: "ぶつめつ"
        }
    }

    /// 日本語を読めない利用者向けの読み。ja では出さない
    var romaji: String {
        switch self {
        case .taian: "taian"
        case .shakko: "shakko"
        case .sensho: "senshō"
        case .tomobiki: "tomobiki"
        case .sakimake: "senbu"
        case .butsumetsu: "butsumetsu"
        }
    }

    /// 漢字の意味。何を表す言葉なのかを一言で示す
    var literalMeaning: LocalizedStringResource {
        switch self {
        case .taian: "大いに安らか"
        case .shakko: "赤い口"
        case .sensho: "先んずれば勝ち"
        case .tomobiki: "友を引く"
        case .sakimake: "先んずれば負け"
        case .butsumetsu: "仏も滅する"
        }
    }

    /// その日の吉凶と、日取りを選ぶときの目安
    var detail: LocalizedStringResource {
        switch self {
        case .taian:
            """
            六曜でもっとも縁起のよい日とされます。一日を通して吉で、結婚式や入籍、開店、契約など、めでたい事を始める日に選ばれます。結婚式場の料金が大安の日だけ高いこともあります。
            """
        case .shakko:
            """
            凶の日とされ、正午前後（おおよそ11時から13時）だけが吉とされます。「赤」の字から火や刃物、血を連想させるとして、祝い事は避けられます。
            """
        case .sensho:
            """
            「先んずれば即ち勝つ」の意味で、午前が吉、午後が凶とされます。急ぎの用事や訴訟ごとを午前中に済ませるとよい日とされます。
            """
        case .tomobiki:
            """
            「友を引く」と読まれ、葬儀を避ける日として広く知られています。友引の日は休業する火葬場も多くあります。一方で幸せを引き寄せるとして、結婚式や引き出物には好まれます。朝夕が吉、正午だけが凶とされます。
            """
        case .sakimake:
            """
            「先んずれば即ち負ける」の意味で、午前が凶、午後が吉とされます。急がず、静かに過ごすのがよい日とされ、勝負事や急用は避けられます。
            """
        case .butsumetsu:
            """
            六曜でもっとも凶とされる日です。「仏も滅する」と書き、一日を通して凶とされるため、結婚式や開店などの祝い事は避けられます。逆に法事は差し支えないとされ、結婚式場では割引されることもあります。
            """
        }
    }

    /// タップしたときに見せる解説
    var term: CalendarTerm {
        CalendarTerm(
            kanji: name,
            kana: kana,
            romaji: romaji,
            subtitle: literalMeaning,
            detail: detail,
            footnote: CalendarTermGlossary.rokuyo.detail
        )
    }

    /// 旧暦の月と日から求める。月が変わるたびに並びが飛ぶのはこの式によるもの
    static func forDate(_ date: Date, calendar: Calendar = .lunisolar) -> Rokuyo? {
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return nil }
        return Rokuyo(rawValue: (month + day) % 6)
    }
}

extension Calendar {
    /// 六曜の算出に使う旧暦。日本の暦に合わせて日本時間で扱う
    static let lunisolar: Calendar = {
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }()
}
