// 生年月日をテンキーで8桁入力する

import SwiftUI

enum BirthDateField: Int, CaseIterable {
    case year
    case month
    case day

    var digitCount: Int {
        switch self {
        case .year: 4
        case .month, .day: 2
        }
    }

    var title: String {
        switch self {
        case .year: "年"
        case .month: "月"
        case .day: "日"
        }
    }

    /// 欄に表示する単位。末尾を「日生」にして生年月日であることを示す
    var unitText: String {
        switch self {
        case .year: "年"
        case .month: "月"
        case .day: "日生"
        }
    }
}

/// 年の入力に使う暦。和暦を選ぶと元号年で入力できる
enum BirthYearCalendar: String, CaseIterable, Identifiable {
    case gregorian
    case showa
    case heisei
    case reiwa

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gregorian: "西暦"
        case .showa: "昭和"
        case .heisei: "平成"
        case .reiwa: "令和"
        }
    }

    /// 元号元年にあたる西暦。西暦入力では使わない
    var firstGregorianYear: Int? {
        switch self {
        case .gregorian: nil
        case .showa: 1926
        case .heisei: 1989
        case .reiwa: 2019
        }
    }

    /// その元号に存在する年の範囲（改元年をまたぐ分も含む）
    var yearRange: ClosedRange<Int>? {
        switch self {
        case .gregorian: nil
        case .showa: 1...64      // 昭和64年(1989)まで
        case .heisei: 1...31     // 平成31年(2019)まで
        case .reiwa: 1...82      // 令和82年(2100) = 表示上限
        }
    }

    var digitCount: Int {
        self == .gregorian ? 4 : 2
    }

    /// 入力された年をこの暦で解釈して西暦へ変換する
    func gregorianYear(fromEntered value: Int) -> Int? {
        guard let first = firstGregorianYear, let range = yearRange else {
            return value    // 西暦はそのまま
        }
        guard range.contains(value) else { return nil }
        return first + value - 1
    }

    /// 西暦をこの暦の年へ戻す（プレースホルダー表示用）
    func enteredYear(fromGregorian year: Int) -> Int? {
        guard let first = firstGregorianYear, let range = yearRange else { return year }
        let value = year - first + 1
        return range.contains(value) ? value : nil
    }
}

/// 年月日を桁単位で保持し、確定した日付へ変換する
struct BirthDateEntry: Equatable {
    var year = ""
    var month = ""
    var day = ""
    var focus = BirthDateField.year
    /// 年の入力に使う暦。切り替えると入力済みの年はクリアする
    var calendar = BirthYearCalendar.gregorian {
        didSet {
            guard calendar != oldValue else { return }
            year = ""
            setPlaceholderText("", for: .year)
        }
    }

    init() {}

    /// 未入力の欄に薄く表示する既存値。欄ごとに保持し、
    /// フォーカスし直したときは入力済みの値をここへ退避して上書き入力に備える
    struct Placeholder: Equatable {
        var year: String
        var month: String
        var day: String
    }

    private(set) var placeholder: Placeholder?

    init(placeholderDate: Date, gregorianCalendar: Calendar = Calendar(identifier: .gregorian)) {
        let components = gregorianCalendar.dateComponents([.year, .month, .day], from: placeholderDate)
        // 既存の日付は西暦で示す。元号を選ぶと年欄はクリアされる
        placeholder = Placeholder(
            year: String(format: "%04d", components.year ?? 0),
            month: String(format: "%02d", components.month ?? 0),
            day: String(format: "%02d", components.day ?? 0)
        )
        focus = .year
    }

    private mutating func setPlaceholderText(_ value: String, for field: BirthDateField) {
        var updated = placeholder ?? Placeholder(year: "", month: "", day: "")
        switch field {
        case .year: updated.year = value
        case .month: updated.month = value
        case .day: updated.day = value
        }
        placeholder = updated
    }

    /// 入力済みの値をプレースホルダーへ退避し、その欄を上書き待ちにする
    private mutating func demoteToPlaceholder(_ field: BirthDateField) {
        let typed = text(for: field)
        guard !typed.isEmpty else { return }
        setPlaceholderText(typed, for: field)
        setText("", for: field)
    }

    /// 表示用の値。未入力ならプレースホルダーを返す
    func displayText(for field: BirthDateField) -> String {
        let typed = text(for: field)
        guard typed.isEmpty else { return typed }
        let width = field == .year ? calendar.digitCount : field.digitCount
        return placeholderText(for: field) ?? String(repeating: "–", count: width)
    }

    func placeholderText(for field: BirthDateField) -> String? {
        guard let placeholder else { return nil }
        let value: String
        switch field {
        case .year: value = placeholder.year
        case .month: value = placeholder.month
        case .day: value = placeholder.day
        }
        return value.isEmpty ? nil : value
    }

    func isShowingPlaceholder(for field: BirthDateField) -> Bool {
        text(for: field).isEmpty && placeholderText(for: field) != nil
    }

    /// 未入力の欄はプレースホルダーで補って確定する
    private func effectiveText(for field: BirthDateField) -> String {
        let typed = text(for: field)
        return typed.isEmpty ? (placeholderText(for: field) ?? "") : typed
    }

    func text(for field: BirthDateField) -> String {
        switch field {
        case .year: year
        case .month: month
        case .day: day
        }
    }

    private mutating func setText(_ value: String, for field: BirthDateField) {
        switch field {
        case .year: year = value
        case .month: month = value
        case .day: day = value
        }
    }

    var isComplete: Bool {
        !effectiveText(for: .year).isEmpty
            && !effectiveText(for: .month).isEmpty
            && !effectiveText(for: .day).isEmpty
    }

    /// 実在する日付のときだけ値を返す（2月30日などは弾く）
    func resolvedDate(calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        guard let enteredYear = Int(effectiveText(for: .year)),
              let y = self.calendar.gregorianYear(fromEntered: enteredYear),
              let m = Int(effectiveText(for: .month)),
              let d = Int(effectiveText(for: .day)) else { return nil }
        guard AppConfig.yearRange.contains(y), (1...12).contains(m), d >= 1 else { return nil }
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        guard let date = calendar.date(from: components) else { return nil }
        // 存在しない日はCalendarが繰り上げるため、往復して一致を確認する
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == y, roundTrip.month == m, roundTrip.day == d else { return nil }
        return date
    }

    mutating func append(_ digit: Int) {
        // 年は素直に桁を埋める。和暦は2桁、西暦は4桁
        guard focus != .year else {
            let limit = calendar.digitCount
            let updated = year + String(digit)
            guard updated.count <= limit else { return }
            year = updated
            if updated.count == limit { advance() }
            return
        }

        let current = text(for: focus)

        // 2桁目は、繋げて有効な値になるときだけ同じ欄へ入れる。
        // 例: 月の1に3が続くと13は月として不正なので、1月を確定して3は日へ送る
        if current.count == 1 {
            let combined = current + String(digit)
            if let value = Int(combined), isValid(value, in: focus) {
                setText(combined, for: focus)
                advance()
            } else if BirthDateField(rawValue: focus.rawValue + 1) != nil {
                // 繋げると不正になるので今の欄を確定し、この数字は次の欄へ送る。
                // 送り先に既存値があっても、繰り越した数字で上書きを始める
                advance()
                append(digit)
            }
            // 次の欄がない（日）の場合は入力を捨てる
            return
        }

        guard current.isEmpty else { return }

        setText(String(digit), for: focus)
        // 2桁目があり得ない先頭桁ならその場で確定して次の欄へ移動する
        // 例: 月に9を入れると9月が確定し、続く数字は日へ流れる
        if !canAcceptMoreDigits(digit, in: focus) {
            advance()
        }
    }

    /// その先頭桁に続けてもう1桁あり得るか
    private func canAcceptMoreDigits(_ firstDigit: Int, in field: BirthDateField) -> Bool {
        switch field {
        case .year:
            return true
        case .month:
            // 10・11・12のみ2桁目がある。0は01〜09の途中
            return firstDigit == 0 || firstDigit == 1
        case .day:
            // 10〜31が2桁。0は01〜09の途中
            return (0...3).contains(firstDigit)
        }
    }

    private func isValid(_ value: Int, in field: BirthDateField) -> Bool {
        switch field {
        case .year: return true
        case .month: return (1...12).contains(value)
        case .day: return (1...31).contains(value)
        }
    }

    mutating func deleteLast() {
        var current = text(for: focus)
        if current.isEmpty {
            // 空欄で削除したら前の欄へ戻って1桁消す
            guard let previous = BirthDateField(rawValue: focus.rawValue - 1) else { return }
            focus = previous
            current = text(for: focus)
        }
        guard !current.isEmpty else { return }
        setText(String(current.dropLast()), for: focus)
    }

    mutating func advance() {
        guard let next = BirthDateField(rawValue: focus.rawValue + 1) else { return }
        // 移動先に入力済みの値があれば退避し、続けて打つと上書きになるようにする
        demoteToPlaceholder(next)
        focus = next
    }

    mutating func moveFocus(to field: BirthDateField) {
        // 同じ欄を選び直したときも含め、入力済みなら上書き待ちに戻す
        demoteToPlaceholder(field)
        focus = field
    }
}

struct BirthDatePad: View {
    @Binding var entry: BirthDateEntry

    @ScaledMetric(relativeTo: .title2) private var scaledFieldHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var scaledCalendarWidth: CGFloat = 38

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            fields

            NumericKeypad(
                trailingKey: .auxiliary(title: "次", disabled: entry.focus == .day)
            ) { key in
                handle(key)
            }
            .padding(.top, 6)
        }
    }

    private var fields: some View {
        HStack(spacing: 8) {
            calendarMenu

            ForEach(BirthDateField.allCases, id: \.rawValue) { field in
                Button {
                    entry.moveFocus(to: field)
                } label: {
                    fieldLabel(field)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(field.title) \(entry.displayText(for: field))")
            }
        }
    }

    private var calendarMenu: some View {
        Menu {
            Picker("暦", selection: $entry.calendar) {
                ForEach(BirthYearCalendar.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            // 漢字2文字を縦に積んで幅を詰める
            VStack(spacing: -2) {
                ForEach(Array(entry.calendar.title), id: \.self) { character in
                    Text(String(character))
                        .font(.caption.weight(.semibold))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 6)
            // 2文字が窮屈にならない最小幅を確保しつつ、日付欄より狭く保つ
            .frame(minWidth: scaledCalendarWidth, minHeight: scaledFieldHeight)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityLabel("暦 \(entry.calendar.title)")
    }

    private func fieldLabel(_ field: BirthDateField) -> some View {
        let isFocused = entry.focus == field
        // 未入力の欄はグレーで前回値を示し、数字を押すと上書きされる
        let isPlaceholder = entry.isShowingPlaceholder(for: field) || entry.text(for: field).isEmpty

        return HStack(spacing: 2) {
            Text(entry.displayText(for: field))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isPlaceholder ? Color(.tertiaryLabel) : Color(.label))
                .contentTransition(.numericText())
                .animation(.snappy, value: entry.text(for: field))

            Text(field.unitText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        // 特大でも折り返さず1行に収める
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: scaledFieldHeight)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 2)
        )
    }

    private func handle(_ key: NumericKeypadKey) {
        switch key {
        case .digit(let digit):
            entry.append(digit)
        case .delete:
            entry.deleteLast()
        case .auxiliary:
            entry.advance()
        case .toggleSign:
            // 生年月日に符号はないため、このキーは置いていない
            break
        }
    }
}

// MARK: - 生年月日入力シート

/// 生年月日をテンキーで入力する共通シート。
/// 日付欄より上に任意の入力欄（名前など）を差し込める
struct BirthDateInputSheet<Header: View>: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: BirthDateEntry
    /// 保存を押したか。押すまでは入力途中とみなして警告を出さない
    @State private var didAttemptSave = false

    private let title: String
    private let canSave: Bool
    private let header: Header
    private let commit: (Date) -> Void

    init(
        title: String,
        birthDate: Date?,
        canSave: Bool = true,
        commit: @escaping (Date) -> Void,
        @ViewBuilder header: () -> Header = { EmptyView() }
    ) {
        self.title = title
        self.canSave = canSave
        self.commit = commit
        self.header = header()
        _entry = State(initialValue: birthDate.map { BirthDateEntry(placeholderDate: $0) } ?? BirthDateEntry())
    }

    private var resolvedBirthDate: Date? {
        entry.resolvedDate()
    }

    /// 入力中は警告を出さず、保存を押した時だけ知らせる
    private var showsInvalidDateWarning: Bool {
        didAttemptSave && resolvedBirthDate == nil
    }

    var body: some View {
        NavigationStack {
            // 文字サイズを大きくすると小型端末では収まらないためスクロール可能にする
            ScrollView {
                VStack(spacing: 14) {
                    header

                    BirthDatePad(entry: $entry)
                        // 直し始めたら警告は引っ込める
                        .onChange(of: entry) { _, _ in didAttemptSave = false }

                    // 警告の有無でシート高が変わらないよう、領域は常に確保しておく
                    Text("存在しない日付です")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .opacity(showsInvalidDateWarning ? 1 : 0)
                        .accessibilityHidden(!showsInvalidDateWarning)
                }
                .padding()
                .measuredSheetContent()
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 押せるようにしておき、不正な日付はここで知らせる
                        didAttemptSave = true
                        guard let resolvedBirthDate else { return }
                        commit(resolvedBirthDate)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .fittedSheetHeight()
        .presentationDragIndicator(.visible)
    }
}
