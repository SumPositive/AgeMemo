// 生年月日から各年の誕生日以降の満年齢を計算する

import Foundation

enum AgeCalculator {
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
