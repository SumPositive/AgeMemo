// 日本の旧暦の月日を求める

import Foundation

/// 日本の旧暦の月日。一般的な日本のカレンダーと同じく、日本時間の朔で月が替わる。
/// 中国暦（Calendar.chinese）は中国時間で朔を判定するため日本の旧暦と1日ずれることがあり、使わない
struct LunarDate: Equatable, Sendable {
    /// 閏月は元の月と同じ番号
    let month: Int
    let day: Int
    /// 望（満月の瞬間）を含む日か
    let isFullMoon: Bool
}

extension LunarDate {
    /// 西暦の年月日から求める。表の範囲外なら nil
    init?(year: Int, month: Int, day: Int) {
        let key = (year * 100 + month) * 100 + day
        let starts = LunarMonthTable.starts
        // key 以前で最後に始まった月を二分探索する
        var low = 0
        var high = starts.count
        while low < high {
            let mid = (low + high) / 2
            if starts[mid] / 10000 <= key {
                low = mid + 1
            } else {
                high = mid
            }
        }
        // 表の最後の月は終わりが分からないので使わない
        guard 0 < low, low < starts.count else { return nil }
        let start = starts[low - 1]
        let startDate = start / 10000
        let lunarDay = Self.dayNumber(year: year, month: month, day: day)
            - Self.dayNumber(year: startDate / 10000, month: startDate / 100 % 100, day: startDate % 100) + 1
        self.month = start / 100 % 100
        self.day = lunarDay
        self.isFullMoon = lunarDay == start % 100
    }

    /// 1970年1月1日からの日数。時差の影響を受けないよう Date を介さず計算する
    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (0 <= y ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month <= 2 ? 9 : -3)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
