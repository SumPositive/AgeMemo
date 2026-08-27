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
        let first = span(for: start, startMonth: 1, startDay: 1)
        let lastEra = japaneseCalendar.component(.era, from: end)
        guard first.eraIdentifier != lastEra else { return [first] }

        let transition = firstDateOfNewEra(from: start, through: end, previousEra: first.eraIdentifier)
        let components = gregorianCalendar.dateComponents([.month, .day], from: transition)
        let second = span(
            for: transition,
            startMonth: components.month ?? 1,
            startDay: components.day ?? 1
        )
        return [first, second]
    }

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

    private static func span(for date: Date, startMonth: Int, startDay: Int) -> EraSpan {
        let components = japaneseCalendar.dateComponents([.era, .year], from: date)
        let eraIdentifier = components.era ?? 0
        return EraSpan(
            eraIdentifier: eraIdentifier,
            eraName: eraName(for: eraIdentifier),
            eraYear: components.year ?? 1,
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
