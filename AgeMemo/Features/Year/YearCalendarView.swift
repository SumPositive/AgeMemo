// 指定年のカレンダーを1か月ずつ表示し、前後の月へ切り替える

import SwiftUI

struct YearCalendarView: View {
    let row: YearRow

    @State private var month: Int
    @State private var isMonthPickerExpanded = false

    /// AZDropdownPicker は Identifiable を要求するため、月を包む
    private struct MonthOption: Hashable, Identifiable {
        let value: Int
        var id: Int { value }
        /// ja は「9月」、en は「9月 Sep.」。月名は暦の表記なので漢数字表記を残し、
        /// 読めない利用者のために英略号を添える
        var title: String {
            CalendarTermLocale.isJapanese ? "\(value)月" : "\(value)月 \(Self.englishAbbreviations[value - 1])"
        }

        private static let englishAbbreviations = [
            "Jan.", "Feb.", "Mar.", "Apr.", "May", "Jun.",
            "Jul.", "Aug.", "Sep.", "Oct.", "Nov.", "Dec."
        ]
    }

    private static let monthOptions = (1...12).map { MonthOption(value: $0) }

    private var selectedMonthOption: Binding<MonthOption> {
        Binding(
            get: { MonthOption(value: month) },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.15)) { month = newValue.value }
            }
        )
    }

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

    private var calendarHelp: LocalizedStringKey {
        """
        その年のカレンダーです。日付の下に六曜と月の満ち欠けを添えています。

        【六曜】
        先勝・友引・先負・仏滅・大安・赤口の6日周期で、旧暦の月日から求めます。日取りを選ぶときに探すことの多い大安は赤色で示します。

        【月の満ち欠け】
        パーセントは輝面率といい、月の光っている部分の面積の割合です。新月が0％、満月が100％になります。

        夕方から夜にかけて実際に空へ出ている月に合わせて計算しているので、その晩に見上げる月の姿とおおよそ一致します。満月（100％）は黄色で示します。

        旧暦をもとにした概算のため、実際の満月と1日ずれることがあります。

        【改元】
        改元があった年は、元号が変わる日に区切り線と新しい元号を表示します。
        """
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

            // 月を直接選べるようにして12か月へ一度に移動できる。
            // 標準の Picker はラベルが折り返し、文字サイズ設定にも追従しないため
            // アプリ共通の AZDropdownPicker を使う
            AZDropdownPicker(
                options: Self.monthOptions,
                selection: selectedMonthOption,
                isExpanded: $isMonthPickerExpanded,
                minWidth: 0
            ) { option in
                Text(option.title)
            }
            // 幅が足りないときに削られるのはヘルプ側であって月ではない
            .layoutPriority(1)

            BeginnerHelpBanner(calendarHelp)

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
    @ScaledMetric(relativeTo: .caption2) private var scaledWeekdayEnglishFontSize: CGFloat = 9
    // 1か月表示になり余裕ができたので日付を大きくする。六曜と月齢の行の分だけ高くする
    @ScaledMetric(relativeTo: .body) private var scaledDayHeight: CGFloat = 64

    /// 漢字語をタップしたときに開く解説
    @State private var selectedTerm: CalendarTerm?

    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
    /// en では曜日の漢字の下に英語の略号を添える
    private let weekdayEnglishSymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
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
                    let weekdayStyle: Color = index == 0 ? .red : (index == 6 ? .blue : .secondary)
                    VStack(spacing: 0) {
                        Text(symbol)
                            .font(.caption.bold())
                        if !CalendarTermLocale.isJapanese {
                            Text(weekdayEnglishSymbols[index])
                                .font(.system(size: scaledWeekdayEnglishFontSize))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .foregroundStyle(weekdayStyle)
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
        .sheet(item: $selectedTerm) { term in
            CalendarTermSheet(term: term)
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
                // 漢字だけでは意味が分からないので、触れると解説を開けるようにする
                Text(rokuyo.name)
                    .font(.system(size: scaledRokuyoFontSize, weight: isTaian ? .bold : .regular))
                    .foregroundStyle(isTaian ? AnyShapeStyle(Color(uiColor: .systemRed)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .calendarTermTappable(rokuyo.term, selection: $selectedTerm)
                    .accessibilityLabel(Text(verbatim: rokuyo.name))
            }
            if let moon {
                // 満月はライト時も読める濃さへ切り替える
                let isFullMoon = moon.illuminationPercent == 100
                let moonStyle = isFullMoon
                    ? AnyShapeStyle(fullMoonColor)
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

    /// 満月の色を外観ごとに読みやすくする
    private var fullMoonColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .systemYellow : .systemOrange
        })
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

