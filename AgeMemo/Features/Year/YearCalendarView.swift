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
    @ScaledMetric(relativeTo: .caption2) private var scaledRokuyoFontSize: CGFloat = 9
    @ScaledMetric(relativeTo: .caption2) private var scaledMoonFontSize: CGFloat = 8
    // 1か月表示になり余裕ができたので日付を大きくする。六曜と月齢の行の分だけ高くする
    @ScaledMetric(relativeTo: .body) private var scaledDayHeight: CGFloat = 64

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
        VStack(spacing: 3) {
            // 月名は上部の切り替えUIに集約したのでここでは出さない
            LazyVGrid(columns: dayColumns, spacing: 1) {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let era = eraSpans.first { $0.startMonth == month && $0.startDay == day && !(month == 1 && day == 1) }
        let rokuyo = rokuyo(for: day)
        let moon = moonPhase(for: day)
        return VStack(spacing: 0) {
            if let era {
                Text(era.eraName)
                    .font(.system(size: scaledEraFontSize, weight: .bold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
            }
            Text(String(day))
                .font(.caption.monospacedDigit())
            if let rokuyo {
                // 大安は日取りを選ぶときに真っ先に探されるので赤系で目立たせる
                let isTaian = rokuyo == .taian
                Text(rokuyo.name)
                    .font(.system(size: scaledRokuyoFontSize, weight: isTaian ? .bold : .regular))
                    .foregroundStyle(isTaian ? AnyShapeStyle(Color(uiColor: .systemRed)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if let moon {
                // 満月（輝面比100%）は黄色系で示す
                let isFullMoon = moon.illuminationPercent == 100
                let moonStyle = isFullMoon
                    ? AnyShapeStyle(Color(uiColor: .systemYellow))
                    : AnyShapeStyle(.secondary)
                Image(systemName: moon.symbolName)
                    .font(.system(size: scaledMoonFontSize))
                    .foregroundStyle(moonStyle)
                Text("\(String(moon.illuminationPercent))%")
                    .font(.system(size: scaledMoonFontSize, weight: isFullMoon ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(moonStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: scaledDayHeight)
        .overlay(alignment: .top) {
            if era != nil {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .accessibilityLabel(accessibilityLabel(day: day, era: era, rokuyo: rokuyo, moon: moon))
    }

    private func moonPhase(for day: Int) -> MoonPhase? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else {
            return nil
        }
        return MoonPhase(date: date)
    }

    private func rokuyo(for day: Int) -> Rokuyo? {
        // 旧暦の日付から求めるため、時差で日がずれないよう正午で判定する
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else {
            return nil
        }
        return Rokuyo.forDate(date)
    }

    private func accessibilityLabel(day: Int, era: EraSpan?, rokuyo: Rokuyo?, moon: MoonPhase?) -> String {
        var label = "\(month)月\(day)日"
        if let rokuyo {
            label += " \(rokuyo.name)"
        }
        if let moon {
            label += " \(moon.name) \(moon.illuminationPercent)パーセント"
        }
        if let era {
            label += " \(era.eraName)改元"
        }
        return label
    }
}
