// 生年月日から各年の誕生日以降の満年齢を計算する

import Foundation

enum AgeDisplayMode: Equatable {
    /// その年に生まれた人の当年時点の年齢を表示する
    case age
    /// 自分の生年月日を基準に各年の年齢を表示する
    case personal
    /// 名簿から選んだ人の生年月日を基準に各年の年齢を表示する
    case person(Date)
}

enum AgeCalculator {
    static func displayedAge(
        for rowYear: Int,
        mode: AgeDisplayMode,
        birthDate: Date?,
        currentYear: Int
    ) -> Int? {
        switch mode {
        case .age:
            // その年に生まれた人の当年時点の年齢を求める
            return currentYear - rowYear
        case .personal:
            return age(in: rowYear, birthDate: birthDate)
        case .person(let personBirthDate):
            return age(in: rowYear, birthDate: personBirthDate)
        }
    }

    /// 指定した年齢の人が生まれた年を求める
    static func birthYear(forAge age: Int, currentYear: Int) -> Int {
        currentYear - age
    }

    static func age(
        in year: Int,
        birthDate: Date?,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int? {
        guard let birthDate else { return nil }
        return year - calendar.component(.year, from: birthDate)
    }

    static func birthYear(
        from birthDate: Date?,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int? {
        guard let birthDate else { return nil }
        return calendar.component(.year, from: birthDate)
    }
}
