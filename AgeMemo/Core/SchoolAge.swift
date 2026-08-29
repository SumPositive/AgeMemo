// 小学校入学から大学4年までの学年を求める

import Foundation

struct SchoolMilestone: CaseIterable, Sendable {
    /// 小学校1年から大学4年までの16学年を順に作る
    static let allCases = (0...15).map { SchoolMilestone(yearsAfterEntrance: $0) }

    /// 小学校入学から対象学年までの年数
    fileprivate let yearsAfterEntrance: Int

    /// 一覧の狭い幅に収めるための短い名前
    var shortName: String {
        switch yearsAfterEntrance {
        case 0...5: "小\(yearsAfterEntrance + 1)"
        case 6...8: "中\(yearsAfterEntrance - 5)"
        case 9...11: "高\(yearsAfterEntrance - 8)"
        default: "大\(yearsAfterEntrance - 11)"
        }
    }

    var name: String {
        switch yearsAfterEntrance {
        case 0...5: "小学校\(yearsAfterEntrance + 1)年"
        case 6...8: "中学校\(yearsAfterEntrance - 5)年"
        case 9...11: "高校\(yearsAfterEntrance - 8)年"
        default: "大学\(yearsAfterEntrance - 11)年"
        }
    }
}

enum SchoolAge {
    /// 学年の始まりとなる年。4月1日以前生まれ（早生まれ）は1年早く入学する
    static func entranceYear(
        for birthDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int? {
        let components = calendar.dateComponents([.year, .month, .day], from: birthDate)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        // 4月2日〜翌年4月1日生まれが同じ学年。4月1日以前は前の学年に入る
        let isEarlyBirth = month < 4 || (month == 4 && day <= 1)
        return year + 6 + (isEarlyBirth ? 0 : 1)
    }

    /// その年に在籍する学年
    static func milestone(
        inYear year: Int,
        birthDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> SchoolMilestone? {
        guard let entrance = entranceYear(for: birthDate, calendar: calendar) else { return nil }
        return SchoolMilestone.allCases.first { milestone in
            entrance + milestone.yearsAfterEntrance == year
        }
    }
}
