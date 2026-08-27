// 指定年のカレンダーを1か月ずつ表示し、前後の月へ切り替える

import SwiftUI

struct YearCalendarView: View {
    let row: YearRow

    @State private var month: Int

    init(row: YearRow, initialMonth: Int = Calendar.current.component(.month, from: .now)) {
        self.row = row
        _month = State(initialValue: min(max(initialMonth, 1), 12))
    }

    var body: some View {
        VStack(spacing: 10) {
            monthSwitcher

            MonthCalendarView(year: row.gregorian, month: month, eraSpans: row.eraSpans)
                // 月をまたぐたびに切り替わりが分かるようにする
                .id(month)
                .transition(.opacity)
        }
        // 左右スワイプでも月を移動できる
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    move(by: value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var monthSwitcher: some View {
        HStack {
            Button {
                move(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 34)
                    .contentShape(Rectangle())
            }
            .disabled(month == 1)

            Spacer(minLength: 0)

            // 月を直接選べるようにして12か月へ一度に移動できる
            Picker("月", selection: $month) {
                ForEach(1...12, id: \.self) { value in
                    Text("\(String(value))月").tag(value)
                }
            }
            .pickerStyle(.menu)
            .font(.headline)

            Spacer(minLength: 0)

            Button {
                move(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 34)
                    .contentShape(Rectangle())
            }
            .disabled(month == 12)
        }
    }

    private func move(by delta: Int) {
        let next = month + delta
        guard (1...12).contains(next) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            month = next
        }
    }
}

private struct MonthCalendarView: View {
    let year: Int
    let month: Int
    let eraSpans: [EraSpan]

    @ScaledMetric(relativeTo: .caption2) private var scaledEraFontSize: CGFloat = 9
    // 1か月表示になり余裕ができたので日付を大きくする
    @ScaledMetric(relativeTo: .body) private var scaledDayHeight: CGFloat = 40

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
            // 月名は上部の切り替えUIに集約したのでここでは出さない
            LazyVGrid(columns: dayColumns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption.bold())
                        .foregroundStyle(index == 0 ? .red : (index == 6 ? .blue : .secondary))
                }

                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear
                            .frame(height: scaledDayHeight)
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
                    .font(.system(size: scaledEraFontSize, weight: .bold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
            }
            Text(String(day))
                .font(.caption.monospacedDigit())
        }
        .frame(maxWidth: .infinity, minHeight: scaledDayHeight)
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
