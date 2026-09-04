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
    /// 一覧や詳細に出す年齢。常に満年齢で数える
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
        case .personal, .person:
            return age(in: rowYear, birthDate: birthDate)
        }
    }

    /// 満年齢から数え年へ直す。数え年は生まれた時点で1歳、以後元日ごとに増えるため、
    /// その年の誕生日を迎えた後の満年齢に1を足した値になる。
    /// 生まれる前の負の値は数え年の考え方が当てはまらないのでそのまま返す
    static func traditionalAge(fromActual actualAge: Int) -> Int {
        0 <= actualAge ? actualAge + 1 : actualAge
    }

    /// 数え年から満年齢へ戻す
    static func actualAge(fromTraditional age: Int) -> Int {
        0 < age ? age - 1 : age
    }

    /// 記念日の周年数。月日は見ず、その年のうちは同じ数のままとする
    /// （結婚記念日が10月でも、1月時点で「今年で5周年」と数える慣習に合わせる）。
    /// 登録した年自体は0周年（まだ迎えていない）で、翌年から1周年になる
    static func anniversaryCount(for rowYear: Int, startDate: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        rowYear - calendar.component(.year, from: startDate)
    }

    /// 指定した周年を迎える西暦年を求める
    static func year(
        forAnniversary count: Int,
        startDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        calendar.component(.year, from: startDate) + count
    }

    /// 指定した満年齢の人が生まれた年を求める。displayedAge の逆算にあたる
    static func birthYear(forAge age: Int, currentYear: Int) -> Int {
        currentYear - age
    }

    /// 指定した人がその満年齢になる西暦年を求める
    static func year(
        forAge age: Int,
        birthDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        calendar.component(.year, from: birthDate) + age
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

    /// 今日時点の正確な満年齢。年だけの引き算とは違い、月日まで見て
    /// 誕生日をまだ迎えていない年は1つ引く
    static func currentActualAge(
        birthDate: Date,
        today: Date = .now,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: today).year ?? 0
    }

    /// 今日がまだ誕生日を迎えていないか。月日だけを比べる
    static func isBeforeBirthday(
        birthDate: Date,
        today: Date = .now,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Bool {
        let birthComponents = calendar.dateComponents([.month, .day], from: birthDate)
        let todayComponents = calendar.dateComponents([.month, .day], from: today)
        guard let birthMonth = birthComponents.month, let birthDay = birthComponents.day,
              let todayMonth = todayComponents.month, let todayDay = todayComponents.day else {
            return false
        }
        return (todayMonth, todayDay) < (birthMonth, birthDay)
    }
}
