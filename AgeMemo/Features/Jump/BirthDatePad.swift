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

    /// 変更時の既存値。入力しない欄はこの値が使われる
    struct Placeholder: Equatable {
        let year: String
        let month: String
        let day: String
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

    /// 表示用の値。未入力ならプレースホルダーを返す
    func displayText(for field: BirthDateField) -> String {
        let typed = text(for: field)
        guard typed.isEmpty else { return typed }
        return placeholderText(for: field) ?? String(repeating: "–", count: field.digitCount)
    }

    func placeholderText(for field: BirthDateField) -> String? {
        guard let placeholder else { return nil }
        switch field {
        case .year: return placeholder.year
        case .month: return placeholder.month
        case .day: return placeholder.day
        }
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
        let current = text(for: focus)
        guard current.count < focus.digitCount else { return }
        let updated = current + String(digit)
        setText(updated, for: focus)
        // 桁が埋まったら次の欄へ自動で移動する
        if updated.count == focus.digitCount {
            advance()
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
        focus = next
    }

    mutating func moveFocus(to field: BirthDateField) {
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
