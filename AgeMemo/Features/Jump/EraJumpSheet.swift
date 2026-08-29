// 年齢・西暦・元号年から該当年へ移動する

import SwiftUI

private enum EraJumpSelection: Hashable, Identifiable {
    case age
    case gregorian
    case era(EraChoice)

    var id: String {
        switch self {
        case .age: "age"
        case .gregorian: "gregorian"
        case .era(let choice): "era-\(choice.id)"
        }
    }

    var title: String {
        switch self {
        case .age: "年齢"
        case .gregorian: "西暦"
        case .era(let choice): choice.name
        }
    }
}

struct EraJumpSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var selection: EraJumpSelection
    @State private var isPickerExpanded = false
    @State private var digits = ""
    @State private var isNegative = false
    @State private var retainedInput: Int?
    @ScaledMetric(relativeTo: .largeTitle) private var displayFontSize: CGFloat = 44

    let rows: [YearRow]
    let ageDisplayMode: AgeDisplayMode
    let jump: (Int) -> Void

    private let currentYear = Calendar.current.component(.year, from: .now)

    init(
        rows: [YearRow],
        ageDisplayMode: AgeDisplayMode,
        initialSelectionID: String?,
        initialInput: Int?,
        jump: @escaping (Int) -> Void
    ) {
        self.rows = rows
        self.ageDisplayMode = ageDisplayMode
        self.jump = jump
        let eraChoices = JapaneseEra.eraChoices(from: rows)
        // 保存値がなければ対象範囲の最新元号を初期表示にする
        let restoredSelection = Self.restoredSelection(id: initialSelectionID, eraChoices: eraChoices)
        _selection = State(initialValue: restoredSelection)

        if let initialInput {
            let maximumInput = Self.maximumInput(for: restoredSelection)
            let magnitude = min(abs(initialInput), maximumInput)
            // 直前の値は入力済みにせず、最初の数字で置き換えられるよう保持する
            _retainedInput = State(initialValue: initialInput < 0 ? -magnitude : magnitude)
        } else {
            _retainedInput = State(initialValue: nil)
        }
    }

    private var isEmpty: Bool { digits.isEmpty }

    private var maximumInput: Int {
        Self.maximumInput(for: selection)
    }

    private static func maximumInput(for selection: EraJumpSelection) -> Int {
        switch selection {
        case .age: AppConfig.maximumAgeInput
        case .gregorian: 9999
        case .era: 999
        }
    }

    private static func restoredSelection(
        id: String?,
        eraChoices: [EraChoice]
    ) -> EraJumpSelection {
        if id == EraJumpSelection.age.id {
            return .age
        }
        if id == EraJumpSelection.gregorian.id {
            return .gregorian
        }
        if let choice = eraChoices.first(where: { EraJumpSelection.era($0).id == id }) {
            return .era(choice)
        }
        return eraChoices.last.map(EraJumpSelection.era) ?? .gregorian
    }

    private var placeholderInputYear: Int {
        switch selection {
        case .age:
            AgeCalculator.displayedAge(
                for: currentYear,
                mode: ageDisplayMode,
                birthDate: settings.birthDate,
                currentYear: currentYear,
                reckoning: settings.ageReckoning
            ) ?? settings.ageReckoning.age(fromActual: 0)
        case .gregorian:
            currentYear
        case .era(let choice):
            currentYear - choice.firstGregorianYear + 1
        }
    }

    private var inputYear: Int {
        guard let value = Int(digits) else { return retainedInput ?? placeholderInputYear }
        let magnitude = min(value, maximumInput)
        return isNegative ? -magnitude : magnitude
    }

    private var eraChoices: [EraChoice] {
        JapaneseEra.eraChoices(from: rows)
    }

    private var pickerOptions: [EraJumpSelection] {
        [.age, .gregorian] + eraChoices.reversed().map(EraJumpSelection.era)
    }

    private var pickerStyle: AZPickerStyle {
        var style = AZPickerStyle.form
        style.optionFont = .title2
        style.dropdownIndicator = .chevron
        style.dropdownTextFitMode = .scale(minimumScaleFactor: 0.6)
        style.dropdownOptionHorizontalPadding = 12
        return style
    }

    private var convertedYear: Int {
        switch selection {
        case .age:
            destinationYear(forAge: inputYear)
        case .gregorian:
            inputYear
        case .era(let choice):
            choice.firstGregorianYear + inputYear - 1
        }
    }

    private var boundedYear: Int {
        min(max(convertedYear, AppConfig.yearRange.lowerBound), AppConfig.yearRange.upperBound)
    }

    private func destinationYear(forAge age: Int) -> Int {
        switch ageDisplayMode {
        case .age:
            return AgeCalculator.birthYear(
                forAge: age,
                currentYear: currentYear,
                reckoning: settings.ageReckoning
            )
        case .personal:
            guard let birthDate = settings.birthDate else {
                return currentYear
            }
            return AgeCalculator.year(
                forAge: age,
                birthDate: birthDate,
                reckoning: settings.ageReckoning
            )
        case .person(let birthDate):
            return AgeCalculator.year(
                forAge: age,
                birthDate: birthDate,
                reckoning: settings.ageReckoning
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    inputRow

                    if convertedYear != boundedYear {
                        Text("表示範囲外のため \(String(boundedYear))年へ移動します")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NumericKeypad(trailingKey: .sign) { key in
                        handle(key)
                    }

                    Button {
                        jump(boundedYear)
                        dismiss()
                    } label: {
                        Label("移動", systemImage: "arrow.up.forward")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .measuredSheetContent()
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .navigationTitle("移動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .fittedSheetHeight()
        .presentationDragIndicator(.visible)
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            AZDropdownPicker(
                options: pickerOptions,
                selection: $selection,
                isExpanded: $isPickerExpanded,
                minWidth: 0,
                fillsWidth: true,
                style: pickerStyle
            ) { option in
                Text(option.title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Textの数値補間を避け、桁区切りなしで表示する
            Text(verbatim: inputDisplayText)
                .font(.system(size: displayFontSize, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(isEmpty ? Color(.tertiaryLabel) : Color(.label))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.snappy, value: digits)
                .frame(maxWidth: .infinity, alignment: .center)

            if case .gregorian = selection {
                // 西暦選択時も中央列の位置を保つ
                Color.clear
                    .frame(maxWidth: .infinity)
            } else {
                Text(verbatim: "\(convertedYear)年")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("移動先 西暦\(convertedYear)年")
            }
        }
        .onChange(of: selection) { _, _ in
            // 年号の桁制限に合わせて未入力状態へ戻す
            digits = ""
            isNegative = false
            retainedInput = nil
            settings.lastJumpSelectionID = selection.id
            settings.lastJumpInput = nil
        }
    }

    private var inputDisplayText: String {
        if isEmpty {
            let placeholder = retainedInput ?? placeholderInputYear
            return placeholder < 0 ? "−\(-placeholder)" : String(placeholder)
        }
        return "\(isNegative ? "−" : "")\(digits)"
    }

    private func handle(_ key: NumericKeypadKey) {
        switch key {
        case .digit(let digit):
            append(digit)
        case .delete:
            if !digits.isEmpty { digits.removeLast() }
        case .auxiliary:
            break
        case .toggleSign:
            isNegative.toggle()
        }
        // 閉じた後も直前の選択と入力を復元できるよう随時保存する
        settings.lastJumpSelectionID = selection.id
        settings.lastJumpInput = signedInput ?? retainedInput
    }

    private func append(_ digit: Int) {
        // 先頭ゼロを残さず、選択中の上限まで入力する
        let next = (digits.isEmpty || digits == "0") ? String(digit) : digits + String(digit)
        guard let value = Int(next), value <= maximumInput else { return }
        // 最初の数字で直前値のプレースホルダーを上書きする
        retainedInput = nil
        digits = String(value)
    }

    private var signedInput: Int? {
        guard let value = Int(digits) else { return nil }
        return isNegative ? -value : value
    }
}
