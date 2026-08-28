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
        currentYear: Int,
        reckoning: AgeReckoning = .actual
    ) -> Int? {
        let actualAge: Int?
        switch mode {
        case .age:
            // その年に生まれた人の当年時点の年齢を求める
            actualAge = currentYear - rowYear
        case .personal:
            actualAge = age(in: rowYear, birthDate: birthDate)
        case .person(let personBirthDate):
            actualAge = age(in: rowYear, birthDate: personBirthDate)
        }
        guard let actualAge else { return nil }
        // 生まれる前は数え年の考え方が当てはまらないので、そのまま負の値を返す
        guard 0 <= actualAge else { return actualAge }
        return reckoning.age(fromActual: actualAge)
    }

    /// 指定した年齢の人が生まれた年を求める。displayedAge の逆算にあたる
    static func birthYear(forAge age: Int, currentYear: Int, reckoning: AgeReckoning = .actual) -> Int {
        // 生まれる前は数え年の変換をしないため、逆算でも戻さない
        let actualAge = 0 <= age ? reckoning.actualAge(from: age) : age
        return currentYear - actualAge
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
