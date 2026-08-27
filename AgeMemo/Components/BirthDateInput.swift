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
}

/// 年月日を桁単位で保持し、確定した日付へ変換する
struct BirthDateEntry: Equatable {
    var year = ""
    var month = ""
    var day = ""
    var focus = BirthDateField.year

    init() {}

    /// 未入力の欄に薄く表示する既存値。欄ごとに保持し、
    /// フォーカスし直したときは入力済みの値をここへ退避して上書き入力に備える
    struct Placeholder: Equatable {
        var year: String
        var month: String
        var day: String
    }

    private(set) var placeholder: Placeholder?

    init(placeholderDate: Date, calendar: Calendar = Calendar(identifier: .gregorian)) {
        let components = calendar.dateComponents([.year, .month, .day], from: placeholderDate)
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
        return placeholderText(for: field) ?? String(repeating: "–", count: field.digitCount)
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
        effectiveText(for: .year).count == 4
            && !effectiveText(for: .month).isEmpty
            && !effectiveText(for: .day).isEmpty
    }

    /// 実在する日付のときだけ値を返す（2月30日などは弾く）
    func resolvedDate(calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        guard let y = Int(effectiveText(for: .year)),
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
        // 年は素直に4桁を埋める
        guard focus != .year else {
            let updated = year + String(digit)
            guard updated.count <= BirthDateField.year.digitCount else { return }
            year = updated
            if updated.count == BirthDateField.year.digitCount { advance() }
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

    var body: some View {
        VStack(spacing: 12) {
            fields

            NumericKeypad(
                auxiliaryTitle: "次",
                auxiliaryDisabled: entry.focus == .day
            ) { key in
                handle(key)
            }
        }
    }

    private var fields: some View {
        HStack(spacing: 8) {
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

            Text(field.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color(.secondarySystemGroupedBackground))
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
        }
    }
}

// MARK: - 生年月日入力シート

/// 生年月日をテンキーで入力する共通シート。
/// 日付欄より上に任意の入力欄（名前など）を差し込める
struct BirthDateInputSheet<Header: View>: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: BirthDateEntry

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

    /// 入力途中は警告を出さず、揃ってから不正な日付だけを知らせる
    private var showsInvalidDateWarning: Bool {
        entry.isComplete && resolvedBirthDate == nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                header

                BirthDatePad(entry: $entry)

                // 警告の有無でシート高が変わらないよう、領域は常に確保しておく
                Text("存在しない日付です")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .opacity(showsInvalidDateWarning ? 1 : 0)
                    .accessibilityHidden(!showsInvalidDateWarning)
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let resolvedBirthDate else { return }
                        commit(resolvedBirthDate)
                        dismiss()
                    }
                    .disabled(resolvedBirthDate == nil || !canSave)
                }
            }
        }
        .fittedSheetHeight()
        .presentationDragIndicator(.visible)
    }
}
