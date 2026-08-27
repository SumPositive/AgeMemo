// 生年月日から各年の誕生日以降の満年齢を計算する

import Foundation

enum AgeDisplayMode {
    case current
    case personal
}

enum AgeCalculator {
    static func displayedAge(
        for rowYear: Int,
        mode: AgeDisplayMode,
        birthDate: Date?,
        currentYear: Int
    ) -> Int? {
        switch mode {
        case .current:
            // その年に生まれた人の当年時点の年齢を求める
            return currentYear - rowYear
        case .personal:
            return age(in: rowYear, birthDate: birthDate)
        }
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
