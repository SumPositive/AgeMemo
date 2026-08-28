// 学齢（入学・卒業の年）

import Foundation

enum SchoolMilestone: CaseIterable, Sendable {
    case elementaryEntrance
    case elementaryGraduation
    case juniorHighGraduation
    case highSchoolGraduation
    case universityGraduation

    /// 小学校入学からその節目までの年数
    fileprivate var yearsAfterEntrance: Int {
        switch self {
        case .elementaryEntrance: 0
        case .elementaryGraduation: 6
        case .juniorHighGraduation: 9
        case .highSchoolGraduation: 12
        case .universityGraduation: 16
        }
    }

    /// 一覧の狭い幅に収めるための短い名前
    var shortName: String {
        switch self {
        case .elementaryEntrance: "小入学"
        case .elementaryGraduation: "小卒業"
        case .juniorHighGraduation: "中卒業"
        case .highSchoolGraduation: "高卒業"
        case .universityGraduation: "大卒業"
        }
    }

    var name: String {
        switch self {
        case .elementaryEntrance: "小学校入学"
        case .elementaryGraduation: "小学校卒業・中学校入学"
        case .juniorHighGraduation: "中学校卒業・高校入学"
        case .highSchoolGraduation: "高校卒業・大学入学"
        case .universityGraduation: "大学卒業"
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

    /// その年に迎える学齢の節目
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
