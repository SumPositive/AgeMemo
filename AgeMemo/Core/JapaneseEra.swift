// Foundationの和暦から年表示と改元日を構築する

import Foundation

enum JapaneseEra {
    static func makeRows(range: ClosedRange<Int> = AppConfig.yearRange) -> [YearRow] {
        range.map { year in
            YearRow(
                id: year,
                gregorian: year,
                eraSpans: spans(in: year),
                stemBranch: StemBranch.value(for: year)
            )
        }
    }

    static func eraChoices(from rows: [YearRow]) -> [EraChoice] {
        var choices: [Int: EraChoice] = [:]
        for row in rows {
            for span in row.eraSpans where choices[span.eraIdentifier] == nil {
                choices[span.eraIdentifier] = EraChoice(
                    id: span.eraIdentifier,
                    name: span.eraName,
                    firstGregorianYear: row.gregorian - span.eraYear + 1
                )
            }
        }
        return choices.values.sorted { $0.firstGregorianYear < $1.firstGregorianYear }
    }

    static func spans(in year: Int) -> [EraSpan] {
        let start = date(year: year, month: 1, day: 1)
        let end = date(year: year, month: 12, day: 31)
        let first = span(for: start, startYear: year, startMonth: 1, startDay: 1)
        let lastEra = japaneseCalendar.component(.era, from: end)
        guard first.eraIdentifier != lastEra else { return [first] }

        let transition = firstDateOfNewEra(from: start, through: end, previousEra: first.eraIdentifier)
        let components = gregorianCalendar.dateComponents([.month, .day], from: transition)
        var second = span(
            for: transition,
            startYear: year,
            startMonth: components.month ?? 1,
            startDay: components.day ?? 1
        )
        // 元号の年数えは一般的な西暦・和暦対照表と同じ Foundation のものを使い、改元日だけ差し替える
        if let actual = preMeijiStartDays[second.eraName] {
            second = EraSpan(
                eraIdentifier: second.eraIdentifier,
                eraName: second.eraName,
                eraYear: second.eraYear,
                startYear: actual.year,
                startMonth: actual.month,
                startDay: actual.day
            )
        }
        return [first, second]
    }

    /// 西暦の年月に改元した元号を日ごとに返す。改元日が翌年1月にあたる元号もあるため、
    /// 年の一覧の行ではなく改元日そのもので引く
    static func transitions(year: Int, month: Int) -> [Int: EraSpan] {
        var result: [Int: EraSpan] = [:]
        for span in allTransitions where span.startYear == year && span.startMonth == month {
            result[span.startDay] = span
        }
        return result
    }

    private static let allTransitions: [EraSpan] = makeRows().flatMap { $0.eraSpans.dropFirst() }

    private struct GregorianDay {
        let year: Int
        let month: Int
        let day: Int
    }

    /// 明治より前の改元日（西暦）。Foundation の和暦は旧暦の月日をそのまま西暦の月日として持っていて、
    /// 実際の改元日より1〜2か月早くなるため使わない。出典は Wikipedia「元号一覧 (日本)」のグレゴリオ暦換算。
    /// 行末のコメントは旧暦での改元日
    private static let preMeijiStartDays: [String: GregorianDay] = [
        "元和": GregorianDay(year: 1615, month: 9, day: 5),  // 慶長20年7月13日
        "寛永": GregorianDay(year: 1624, month: 4, day: 17),  // 元和10年2月30日
        "正保": GregorianDay(year: 1645, month: 1, day: 13),  // 寛永21年12月16日
        "慶安": GregorianDay(year: 1648, month: 4, day: 7),  // 正保5年2月15日
        "承応": GregorianDay(year: 1652, month: 10, day: 20),  // 慶安5年9月18日
        "明暦": GregorianDay(year: 1655, month: 5, day: 18),  // 承応4年4月13日
        "万治": GregorianDay(year: 1658, month: 8, day: 21),  // 明暦4年7月23日
        "寛文": GregorianDay(year: 1661, month: 5, day: 23),  // 万治4年4月25日
        "延宝": GregorianDay(year: 1673, month: 10, day: 30),  // 寛文13年9月21日
        "天和": GregorianDay(year: 1681, month: 11, day: 9),  // 延宝9年9月29日
        "貞享": GregorianDay(year: 1684, month: 4, day: 5),  // 天和4年2月21日
        "元禄": GregorianDay(year: 1688, month: 10, day: 23),  // 貞享5年9月30日
        "宝永": GregorianDay(year: 1704, month: 4, day: 16),  // 元禄17年3月13日
        "正徳": GregorianDay(year: 1711, month: 6, day: 11),  // 宝永8年4月25日
        "享保": GregorianDay(year: 1716, month: 8, day: 9),  // 正徳6年6月22日
        "元文": GregorianDay(year: 1736, month: 6, day: 7),  // 享保21年4月28日
        "寛保": GregorianDay(year: 1741, month: 4, day: 12),  // 元文6年2月27日
        "延享": GregorianDay(year: 1744, month: 4, day: 3),  // 寛保4年2月21日
        "寛延": GregorianDay(year: 1748, month: 8, day: 5),  // 延享5年7月12日
        "宝暦": GregorianDay(year: 1751, month: 12, day: 14),  // 寛延4年10月27日
        "明和": GregorianDay(year: 1764, month: 6, day: 30),  // 宝暦14年6月2日
        "安永": GregorianDay(year: 1772, month: 12, day: 10),  // 明和9年11月16日
        "天明": GregorianDay(year: 1781, month: 4, day: 25),  // 安永10年4月2日
        "寛政": GregorianDay(year: 1789, month: 2, day: 19),  // 天明9年1月25日
        "享和": GregorianDay(year: 1801, month: 3, day: 19),  // 寛政13年2月5日
        "文化": GregorianDay(year: 1804, month: 3, day: 22),  // 享和4年2月11日
        "文政": GregorianDay(year: 1818, month: 5, day: 26),  // 文化15年4月22日
        "天保": GregorianDay(year: 1831, month: 1, day: 23),  // 文政13年12月10日
        "弘化": GregorianDay(year: 1845, month: 1, day: 9),  // 天保15年12月2日
        "嘉永": GregorianDay(year: 1848, month: 4, day: 1),  // 弘化5年2月28日
        "安政": GregorianDay(year: 1855, month: 1, day: 15),  // 嘉永7年11月27日
        "万延": GregorianDay(year: 1860, month: 4, day: 8),  // 安政7年3月18日
        "文久": GregorianDay(year: 1861, month: 3, day: 29),  // 万延2年2月19日
        "元治": GregorianDay(year: 1864, month: 3, day: 27),  // 文久4年2月20日
        "慶応": GregorianDay(year: 1865, month: 5, day: 1),  // 元治2年4月7日
    ]

    private static let gregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let japaneseCalendar: Calendar = {
        var calendar = Calendar(identifier: .japanese)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static func date(year: Int, month: Int, day: Int) -> Date {
        gregorianCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private static func span(for date: Date, startYear: Int, startMonth: Int, startDay: Int) -> EraSpan {
        let components = japaneseCalendar.dateComponents([.era, .year], from: date)
        let eraIdentifier = components.era ?? 0
        return EraSpan(
            eraIdentifier: eraIdentifier,
            eraName: eraName(for: eraIdentifier),
            eraYear: components.year ?? 1,
            startYear: startYear,
            startMonth: startMonth,
            startDay: startDay
        )
    }

    private static func eraName(for identifier: Int) -> String {
        guard japaneseCalendar.eraSymbols.indices.contains(identifier) else { return "?" }
        return japaneseCalendar.eraSymbols[identifier]
    }

    private static func firstDateOfNewEra(from start: Date, through end: Date, previousEra: Int) -> Date {
        let dayCount = gregorianCalendar.dateComponents([.day], from: start, to: end).day ?? 0
        var lower = 1
        var upper = dayCount
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let candidate = gregorianCalendar.date(byAdding: .day, value: middle, to: start) ?? end
            if japaneseCalendar.component(.era, from: candidate) == previousEra {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return gregorianCalendar.date(byAdding: .day, value: lower, to: start) ?? end
    }
}
