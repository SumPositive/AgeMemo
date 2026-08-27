// 指定年の12か月と改元日を月ごとに表示する

import SwiftUI

struct YearCalendarView: View {
    let row: YearRow

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
            ForEach(1...12, id: \.self) { month in
                MonthCalendarView(year: row.gregorian, month: month, eraSpans: row.eraSpans)
            }
        }
    }
}

private struct MonthCalendarView: View {
    let year: Int
    let month: Int
    let eraSpans: [EraSpan]

    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 1
        return calendar
    }

    private var cells: [Int?] {
        guard let firstDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDate) else {
            return []
        }
        let leadingCount = calendar.component(.weekday, from: firstDate) - 1
        return Array(repeating: nil, count: leadingCount) + dayRange.map(Optional.some)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("\(month)月")
                .font(.headline.monospacedDigit())

            LazyVGrid(columns: dayColumns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(index == 0 ? .red : (index == 6 ? .blue : .secondary))
                }

                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear
                            .frame(height: 30)
                    }
                }
            }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let era = eraSpans.first { $0.startMonth == month && $0.startDay == day && !(month == 1 && day == 1) }
        return VStack(spacing: 0) {
            if let era {
                Text(era.eraName)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
            }
            Text(String(day))
                .font(.caption.monospacedDigit())
        }
        .frame(maxWidth: .infinity, minHeight: 30)
        .overlay(alignment: .top) {
            if era != nil {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .accessibilityLabel(era.map { "\(month)月\(day)日 \($0.eraName)改元" } ?? "\(month)月\(day)日")
    }
}
