// 年齢・西暦・元号年から該当年へ移動する

import SwiftUI

private enum EraJumpSelection: Hashable, Identifiable {
    case actualAge
    /// 数え年で指定する。設定「数え年を表示する」がONのときだけ選べる
    case traditionalAge
    case gregorian
    case era(EraChoice)

    var id: String {
        switch self {
        // 以前の "age" を引き継ぎ、保存済みの選択が満年齢のまま復元されるようにする
        case .actualAge: "age"
        case .traditionalAge: "traditionalAge"
        case .gregorian: "gregorian"
        case .era(let choice): "era-\(choice.id)"
        }
    }

    var title: String {
        switch self {
        case .actualAge: "満年齢"
        case .traditionalAge: "数え年齢"
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
    /// 自分または名簿人物の年齢換算に使う生年月日
    let birthDate: Date?
    /// 名簿で記念日を選んでいる場合は、年齢ではなく周年として扱う
    let isAnniversary: Bool
    let jump: (Int) -> Void

    private let currentYear = Calendar.current.component(.year, from: .now)
    /// よく使う種別タグの文字サイズ。小さめのタグにして入力欄の邪魔をしない
    @ScaledMetric(relativeTo: .caption2) private var frequentSelectionFontSize: CGFloat = 11

    init(
        rows: [YearRow],
        ageDisplayMode: AgeDisplayMode,
        birthDate: Date?,
        isAnniversary: Bool = false,
        initialSelectionID: String?,
        initialInput: Int?,
        jump: @escaping (Int) -> Void
    ) {
        self.rows = rows
        self.ageDisplayMode = ageDisplayMode
        self.birthDate = birthDate
        self.isAnniversary = isAnniversary
        self.jump = jump
        let eraChoices = JapaneseEra.eraChoices(from: rows)
        // 保存値がなければ対象範囲の最新元号を初期表示にする
        let savedSelection = Self.restoredSelection(id: initialSelectionID, eraChoices: eraChoices)
        // 記念日に数え年は存在しないため、保存値が数え年なら周年へ戻す
        let restoredSelection = isAnniversary && savedSelection == .traditionalAge
            ? EraJumpSelection.actualAge
            : savedSelection
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
        case .actualAge, .traditionalAge: AppConfig.maximumAgeInput
        case .gregorian: 9999
        case .era: 999
        }
    }

    private static func restoredSelection(
        id: String?,
        eraChoices: [EraChoice]
    ) -> EraJumpSelection {
        if id == EraJumpSelection.actualAge.id {
            return .actualAge
        }
        if id == EraJumpSelection.traditionalAge.id {
            return .traditionalAge
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
        placeholderInputYear(for: selection)
    }

    private func placeholderInputYear(for selection: EraJumpSelection) -> Int {
        switch selection {
        case .actualAge:
            AgeCalculator.displayedAge(
                for: currentYear,
                mode: ageDisplayMode,
                birthDate: birthDate,
                currentYear: currentYear
            ) ?? 0
        case .traditionalAge:
            AgeCalculator.traditionalAge(
                fromActual: AgeCalculator.displayedAge(
                    for: currentYear,
                    mode: ageDisplayMode,
                    birthDate: birthDate,
                    currentYear: currentYear
                ) ?? 0
            )
        case .gregorian:
            currentYear
        case .era(let choice):
            currentYear - choice.firstGregorianYear + 1
        }
    }

    private var inputYear: Int {
        guard let value = Int(digits) else {
            return boundedInput(retainedInput ?? placeholderInputYear, for: selection)
        }
        let magnitude = min(value, maximumInput)
        return boundedInput(isNegative ? -magnitude : magnitude, for: selection)
    }

    private var eraChoices: [EraChoice] {
        JapaneseEra.eraChoices(from: rows)
    }

    private var pickerOptions: [EraJumpSelection] {
        // 記念日は満年齢に相当する入力を周年として使い、数え年は表示しない
        if isAnniversary {
            return [.actualAge, .gregorian] + eraChoices.reversed().map(EraJumpSelection.era)
        }
        // 数え年での指定は、設定「数え年を表示する」がONのときだけ選べるようにする
        let ageOptions: [EraJumpSelection] = settings.showsTraditionalAge
            ? [.traditionalAge, .actualAge]
            : [.actualAge]
        return ageOptions + [.gregorian] + eraChoices.reversed().map(EraJumpSelection.era)
    }

    /// よく使う入力種別の上位5件。実行回数の多い順に並べ、
    /// 同数のときは選択肢の並び順を保って安定させる
    private var frequentSelections: [EraJumpSelection] {
        let counts = settings.jumpSelectionUseCounts
        let used = pickerOptions.enumerated()
            .compactMap { index, option -> (option: EraJumpSelection, count: Int, index: Int)? in
                guard let count = counts[option.id], 0 < count else { return nil }
                return (option, count, index)
            }
        return used
            .sorted { ($0.count, $1.index) > ($1.count, $0.index) }
            .prefix(Self.frequentSelectionLimit)
            .map(\.option)
    }

    /// 1行に収める上限
    private static let frequentSelectionLimit = 5

    private var pickerStyle: AZPickerStyle {
        var style = AZPickerStyle.form
        style.optionFont = .title2
        // 「数え年齢」のような長い選択肢が省略されないよう、
        // インジケータの分の幅を文字へ回す
        style.dropdownIndicator = .none
        style.dropdownTextFitMode = .scale(minimumScaleFactor: 0.6)
        style.dropdownOptionHorizontalPadding = 12
        return style
    }

    private var convertedYear: Int {
        convertedYear(for: selection, input: inputYear)
    }

    private func convertedYear(for selection: EraJumpSelection, input: Int) -> Int {
        switch selection {
        case .actualAge:
            // 記念日一覧では入力値を周年として登録年から逆算する
            if isAnniversary, let birthDate {
                return AgeCalculator.year(forAnniversary: input, startDate: birthDate)
            }
            return destinationYear(forAge: input)
        case .traditionalAge:
            // 数え年は満年齢へ直してから、満年齢と同じ計算に載せる
            return destinationYear(forAge: AgeCalculator.actualAge(fromTraditional: input))
        case .gregorian:
            return input
        case .era(let choice):
            return choice.firstGregorianYear + input - 1
        }
    }

    /// 同じ西暦年を新しい入力種別の値へ換算する
    private func input(for selection: EraJumpSelection, destinationYear: Int) -> Int {
        switch selection {
        case .actualAge:
            // 記念日一覧では移動先の西暦年を周年へ換算する
            if isAnniversary, let birthDate {
                return AgeCalculator.anniversaryCount(for: destinationYear, startDate: birthDate)
            }
            return AgeCalculator.displayedAge(
                for: destinationYear,
                mode: ageDisplayMode,
                birthDate: birthDate,
                currentYear: currentYear
            ) ?? 0
        case .traditionalAge:
            return AgeCalculator.traditionalAge(
                fromActual: AgeCalculator.displayedAge(
                    for: destinationYear,
                    mode: ageDisplayMode,
                    birthDate: birthDate,
                    currentYear: currentYear
                ) ?? 0
            )
        case .gregorian:
            return destinationYear
        case .era(let choice):
            return destinationYear - choice.firstGregorianYear + 1
        }
    }

    private func boundedInput(_ input: Int, for selection: EraJumpSelection) -> Int {
        let magnitude = min(abs(input), Self.maximumInput(for: selection))
        return input < 0 ? -magnitude : magnitude
    }

    private var boundedYear: Int {
        min(max(convertedYear, AppConfig.yearRange.lowerBound), AppConfig.yearRange.upperBound)
    }

    private func destinationYear(forAge age: Int) -> Int {
        switch ageDisplayMode {
        case .age:
            return AgeCalculator.birthYear(forAge: age, currentYear: currentYear)
        case .personal:
            guard let birthDate else {
                return currentYear
            }
            return AgeCalculator.year(forAge: age, birthDate: birthDate)
        case .person:
            guard let birthDate else {
                return currentYear
            }
            return AgeCalculator.year(forAge: age, birthDate: birthDate)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if !frequentSelections.isEmpty {
                        frequentSelectionRow
                    }

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
                        // よく使う種別をすぐ選べるよう、実行したものだけ数える
                        settings.recordJumpSelectionUse(id: selection.id)
                        jump(boundedYear)
                        dismiss()
                    } label: {
                        Label("移動", systemImage: "arrow.up.forward")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    // 移動先行と同じ緑系にして操作と結果を対応させる
                    .tint(Color.moveAction)
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
        .onAppear {
            // 数え年で保存されたまま設定がOFFになっていると、選べない値が
            // 選択されたままになるため満年齢へ戻す
            if selection == .traditionalAge, !settings.showsTraditionalAge {
                selection = .actualAge
            }
        }
    }

    /// よく使う入力種別をすぐ選べるタブ。押すと種別だけを切り替える
    private var frequentSelectionRow: some View {
        // 収まる倍率を上から順に試し、入らないときだけ全体を均等に縮める。
        // 候補は自然幅で測らせ、右寄せは外側で行う
        ViewThatFits(in: .horizontal) {
            ForEach(Self.frequentSelectionScales, id: \.self) { scale in
                frequentSelectionRow(scale: scale)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// 幅が足りないときに試す文字の倍率
    private static let frequentSelectionScales: [CGFloat] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]

    private func frequentSelectionRow(scale: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(frequentSelections) { option in
                let isSelected = option == selection
                Button {
                    // selection を変えれば onChange で換算と保存が走る
                    guard option != selection else { return }
                    selection = option
                } label: {
                    Text(selectionTitle(option))
                        .font(.system(size: frequentSelectionFontSize * scale, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 8 * scale)
                        .padding(.vertical, 3.5 * scale)
                        .background(
                            Capsule().fill(isSelected
                                           ? Color.accentColor.opacity(0.14)
                                           : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected
                                    ? Color.accentColor.opacity(0.55)
                                    : Color.secondary.opacity(0.30),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
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
                Text(selectionTitle(option))
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
                    .accessibilityLabel(Text("移動先 西暦\(convertedYear)年"))
            }
        }
        .onChange(of: selection) { previousSelection, newSelection in
            // 移動先の西暦年を保ったまま、新しい年号の値へ換算する
            let sourceInput = signedInput ?? retainedInput ?? placeholderInputYear(for: previousSelection)
            let destinationYear = convertedYear(for: previousSelection, input: sourceInput)
            let convertedInput = input(for: newSelection, destinationYear: destinationYear)
            digits = ""
            isNegative = false
            retainedInput = boundedInput(convertedInput, for: newSelection)
            settings.lastJumpSelectionID = newSelection.id
            settings.lastJumpInput = retainedInput
        }
    }

    /// 記念日一覧では満年齢の計算枠を「周年」として表示する
    private func selectionTitle(_ option: EraJumpSelection) -> String {
        if isAnniversary, option == .actualAge {
            return "周年"
        }
        return option.title
    }

    private var inputDisplayText: String {
        if isEmpty {
            let placeholder = boundedInput(retainedInput ?? placeholderInputYear, for: selection)
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
            // 0は符号を持たせず、−0表示を防ぐ
            if digits != "0" { isNegative.toggle() }
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
        let normalizedInput = boundedInput(isNegative ? -value : value, for: selection)
        isNegative = normalizedInput < 0
        digits = String(abs(normalizedInput))
    }

    private var signedInput: Int? {
        guard let value = Int(digits) else { return nil }
        return isNegative ? -value : value
    }
}
