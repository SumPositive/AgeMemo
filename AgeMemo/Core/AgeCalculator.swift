// 生年月日から各年の誕生日以降の満年齢を計算する

import Foundation

enum AgeDisplayMode: Equatable {
    /// その年に生まれた人の当年時点の年齢を表示する
    case age
    /// 自分の生年月日を基準に各年の年齢を表示する
    case personal
    /// 名簿から選んだ人の生年月日を基準に各年の年齢を表示する
    case person
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
        case .personal, .person:
            actualAge = age(in: rowYear, birthDate: birthDate)
        }
        guard let actualAge else { return nil }
        // 生まれる前は数え年の考え方が当てはまらないので、そのまま負の値を返す
        guard 0 <= actualAge else { return actualAge }
        return reckoning.age(fromActual: actualAge)
    }

    /// 指定した年齢の人が生まれた年を求める。displayedAge の逆算にあたる
    static func birthYear(forAge age: Int, currentYear: Int, reckoning: AgeReckoning = .actual) -> Int {
        // 数え年の0歳は1歳へ補正し、逆算結果のずれを防ぐ
        let normalizedAge = reckoning.clampedInputAge(age)
        // 生まれる前は数え年の変換をしないため、逆算でも戻さない
        let actualAge = 0 <= normalizedAge ? reckoning.actualAge(from: normalizedAge) : normalizedAge
        return currentYear - actualAge
    }

    /// 指定した人がその年齢になる西暦年を求める
    static func year(
        forAge age: Int,
        birthDate: Date,
        reckoning: AgeReckoning = .actual,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        let birthYear = calendar.component(.year, from: birthDate)
        // 数え年の0歳は1歳へ補正し、逆算結果のずれを防ぐ
        let normalizedAge = reckoning.clampedInputAge(age)
        // 生まれる前の負数はそのまま生年から逆方向へ足す
        let actualAge = 0 <= normalizedAge ? reckoning.actualAge(from: normalizedAge) : normalizedAge
        return birthYear + actualAge
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
