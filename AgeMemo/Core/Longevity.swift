// 還暦・喜寿などの長寿祝い（賀寿）

import Foundation

struct Longevity: Sendable, Hashable {
    let name: String
    let kana: String
    /// 本来の数え年での祝い年齢
    let traditionalAge: Int

    /// 満年齢での祝い年齢。数え年より1つ若い
    var actualAge: Int { traditionalAge - 1 }

    private static let all: [Longevity] = [
        Longevity(name: "還暦", kana: "かんれき", traditionalAge: 61),
        Longevity(name: "緑寿", kana: "ろくじゅ", traditionalAge: 66),
        Longevity(name: "古希", kana: "こき", traditionalAge: 70),
        Longevity(name: "喜寿", kana: "きじゅ", traditionalAge: 77),
        Longevity(name: "傘寿", kana: "さんじゅ", traditionalAge: 80),
        Longevity(name: "半寿", kana: "はんじゅ", traditionalAge: 81),
        Longevity(name: "米寿", kana: "べいじゅ", traditionalAge: 88),
        Longevity(name: "卒寿", kana: "そつじゅ", traditionalAge: 90),
        Longevity(name: "白寿", kana: "はくじゅ", traditionalAge: 99),
        Longevity(name: "百寿", kana: "ももじゅ", traditionalAge: 100),
        Longevity(name: "茶寿", kana: "ちゃじゅ", traditionalAge: 108),
        Longevity(name: "皇寿", kana: "こうじゅ", traditionalAge: 111),
        Longevity(name: "大還暦", kana: "だいかんれき", traditionalAge: 121)
    ]

    /// 画面に出ている年齢から賀寿を探す。
    /// 還暦は数え61歳＝満60歳なので、設定した数え方に合わせて引き当てる
    static func forDisplayedAge(_ age: Int, reckoning: AgeReckoning) -> Longevity? {
        all.first { longevity in
            switch reckoning {
            case .actual: longevity.actualAge == age
            case .traditional: longevity.traditionalAge == age
            }
        }
    }
}
