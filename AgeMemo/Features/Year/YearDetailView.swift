// 年の詳細情報、カレンダー、メモ編集を一画面で提供する

import SwiftUI

struct YearDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MemoStore.self) private var memoStore
    @Environment(PersonStore.self) private var personStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let row: YearRow
    @State private var memoText: String
    /// 漢字語をタップしたときに開く解説
    @State private var selectedTerm: CalendarTerm?
    let ageDisplayMode: AgeDisplayMode
    /// 名簿人物を同姓同日でも区別するためのID
    let selectedPersonID: UUID?

    init(row: YearRow, ageDisplayMode: AgeDisplayMode, selectedPersonID: UUID? = nil) {
        self.row = row
        self.ageDisplayMode = ageDisplayMode
        self.selectedPersonID = selectedPersonID
        _memoText = State(initialValue: "")
    }

    private var selectedPerson: Person? {
        guard let selectedPersonID else { return nil }
        return personStore.people.first { $0.id == selectedPersonID }
    }

    /// 名簿で選んだ方が記念日（結婚記念日など）か
    private var isShowingAnniversary: Bool {
        ageDisplayMode == .person && selectedPerson?.kind == .anniversary
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isBeginner {
                        // 漢字がタップできることは見た目では分からないため案内する
                        Text("漢字（熟語）をタップすると解説を表示します")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    summary
                    if showsMemo {
                        memoEditor
                    }
                    YearCalendarView(row: row)
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            // 年は本文の見出しに出るため、シートのタイトルには置かない
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .sheet(item: $selectedTerm) { term in
            CalendarTermSheet(term: term)
        }
        .presentationDragIndicator(.visible)
        // iPadでは内容量に合わせた中間サイズで表示する
        .modifier(
            YearDetailPresentationSizingModifier(
                usesBalancedSize: horizontalSizeClass == .regular && verticalSizeClass == .regular,
                includesMemo: showsMemo
            )
        )
        .onAppear {
            memoText = memoStore.text(for: row.gregorian) ?? ""
        }
        .onChange(of: memoText) { _, newValue in
            // メモ欄を出していないときは空文字で既存メモを消さないようにする
            guard showsMemo else { return }
            let limitedText = String(newValue.prefix(AppConfig.maximumMemoLength))
            if limitedText != newValue {
                memoText = limitedText
                return
            }
            memoStore.update(year: row.gregorian, text: limitedText)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                memoStore.flushPendingSave()
            }
        }
        .onDisappear {
            memoStore.flushPendingSave()
        }
    }

    /// その年に元年が始まった元号。1月1日開始（＝前年からの継続）は改元ではないので除く
    /// 見出しに出す元号。改元年は年初の元号だけにし、新元号は次の行へ回す
    private var headlineEraText: String {
        guard ganNenSpan != nil, let first = row.eraSpans.first else {
            return row.eraDisplayText
        }
        return first.displayText
    }

    /// 見出しに出す元号。改元年でない年は元号がひとつに定まるため、
    /// 名の部分だけを切り出してタップできるようにする
    private var headlineEraSpan: EraSpan? {
        guard ganNenSpan == nil, row.eraSpans.count == 1 else { return nil }
        return row.eraSpans.first
    }

    /// 「令和8年」から元号名を除いた「8年」の部分
    private var headlineEraSuffix: String {
        guard let span = headlineEraSpan else { return "" }
        return String(span.displayText.dropFirst(span.eraName.count))
    }

    private var isBeginner: Bool {
        settings.displayMode == .beginner
    }

    /// 暦の属性ラベルの幅。「十二支」の3文字が収まる幅を文字サイズに追従させる
    @ScaledMetric(relativeTo: .caption) private var attributeLabelWidth: CGFloat = 42
    /// 年齢説明を設定文字サイズから段階的に縮小する基準
    @ScaledMetric(relativeTo: .body) private var descriptionFontSize: CGFloat = 17

    private var ganNenSpan: EraSpan? {
        row.eraSpans.first { $0.isGanNen && !($0.startMonth == 1 && $0.startDay == 1) }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 改元年は元号を並べず、年初の元号だけを見出しに置く。
            // 元号の名だけを切り出してタップできるようにする
            HStack(spacing: 0) {
                Text(verbatim: "\(String(row.gregorian))年  ")
                if let headlineEra = headlineEraSpan {
                    Text(verbatim: headlineEra.eraName)
                        .calendarTermTappable(EraGlossary.term(for: headlineEra.eraName), selection: $selectedTerm)
                    Text(verbatim: headlineEraSuffix)
                } else {
                    Text(verbatim: headlineEraText)
                }
            }
            .font(.title2.bold())
            // 撮影時に開いた年を検証できるようにする
            .accessibilityIdentifier("detail.year.\(row.gregorian)")

            if let ganNen = ganNenSpan {
                // 改元があった年は、いつから元年になったのかを次の行に添える
                HStack(spacing: 0) {
                    Text(verbatim: ganNen.eraName)
                        .calendarTermTappable(EraGlossary.term(for: ganNen.eraName), selection: $selectedTerm)
                    Text("元年（\(String(ganNen.startMonth))月\(String(ganNen.startDay))日〜）")
                }
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // 年齢（または周年）の説明は暦の属性と性格が違うので、
            // 薄い背景でひとまとまりにして読み分けやすくする
            if displayedAge != nil || anniversaryCount != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let age = displayedAge {
                        fittedDescription(ageDescription(age), isSecondary: age < 0)
                    }

                    if let anniversaryCount {
                        fittedDescription(
                            anniversaryDescription(anniversaryCount),
                            isSecondary: anniversaryCount < 0
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color(.secondarySystemFill),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }

            if let longevity {
                HStack(spacing: 0) {
                    Text(verbatim: "🎉 ")
                    Text(verbatim: "\(longevity.name)（\(longevity.kana)）")
                        .calendarTermTappable(longevity.term, selection: $selectedTerm)
                }
                .foregroundStyle(.tint)
            }

            if let unluckyYear {
                Text(verbatim: unluckyYear.isMajor ? "\(unluckyYear.name)（大厄）" : unluckyYear.name)
                    .foregroundStyle(.red)
                    .calendarTermTappable(unluckyYear.term, selection: $selectedTerm)
            }

            if let schoolMilestone {
                HStack(spacing: 0) {
                    Text(verbatim: "🎓 ")
                    Text(schoolMilestone.name)
                        .calendarTermTappable(CalendarTermGlossary.schoolYear, selection: $selectedTerm)
                }
                .foregroundStyle(.secondary)
            }

            // 暦の属性はラベルの幅を揃えて、値の先頭を縦にそろえる。
            // 干支・十二支は関わりが深いので隣に並べ、九星はその後に置く
            attributeRow(
                label: Text(verbatim: "干支")
                    .calendarTermTappable(CalendarTermGlossary.stemBranch, selection: $selectedTerm)
            ) {
                Text(verbatim: "\(row.stemBranch.branch.emoji) \(row.stemBranch.kanji)\(reading(kana: row.stemBranch.kana, romaji: row.stemBranch.romaji))")
                    .calendarTermTappable(row.stemBranch.term, selection: $selectedTerm)
            }

            attributeRow(
                label: Text(verbatim: "十二支")
                    .calendarTermTappable(CalendarTermGlossary.earthlyBranch, selection: $selectedTerm)
            ) {
                Text(verbatim: "\(row.stemBranch.branch.kanji)\(reading(kana: row.stemBranch.branch.kana, romaji: row.stemBranch.branch.romaji))")
                    .calendarTermTappable(row.stemBranch.branch.term, selection: $selectedTerm)
            }

            if let nineStar {
                // 「九星」は暦の用語なので訳さない。読みだけ言語に合わせる。
                // ラベルは制度の説明、星の名は星ごとの説明へ分けて開く
                attributeRow(
                    label: Text(verbatim: "九星")
                        .calendarTermTappable(CalendarTermGlossary.nineStar, selection: $selectedTerm)
                ) {
                    Text(verbatim: "\(nineStar.name)\(reading(kana: nineStar.kana, romaji: nineStar.romaji))")
                        .calendarTermTappable(nineStar.term, selection: $selectedTerm)
                }
            }
        }
        // 改元年は元号が2つ並んで長くなるため、折り返さず縮小して1行に収める
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 暦の属性（九星・干支・十二支）を「ラベル＋値」で1行に並べる。
    /// ラベルは幅を固定して薄く小さくし、値の先頭を縦にそろえて読みやすくする
    private func attributeRow<Value: View>(
        label: some View,
        @ViewBuilder value: () -> Value
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            label
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: attributeLabelWidth, alignment: .leading)
            value()
                .foregroundStyle(.secondary)
        }
    }

    /// 明示した改行だけを残し、各行が収まるまで全体を縮小する
    private func fittedDescription(_ text: String, isSecondary: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            ForEach(descriptionScales, id: \.self) { scale in
                Text(verbatim: text)
                    .font(.system(size: descriptionFontSize * scale))
                    .foregroundStyle(isSecondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .lineLimit(3)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
    }

    /// 説明文が収まる倍率を上から順に試す
    private var descriptionScales: [CGFloat] {
        [1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5, 0.45, 0.4]
    }

    /// その年に迎える賀寿。生まれる前の年には出さない
    private var longevity: Longevity? {
        guard let age = displayedAge, 0 <= age else { return nil }
        return Longevity.forActualAge(age)
    }

    /// 学齢の判定に使う生年月日。年齢一覧は特定の人ではないので対象外
    private var effectiveBirthDate: Date? {
        switch ageDisplayMode {
        case .age: nil
        case .personal: settings.birthDate
        case .person: selectedPerson?.birthDate
        }
    }

    /// その年に在籍する学年。記念日には学齢の概念が無い
    private var schoolMilestone: SchoolMilestone? {
        guard !isShowingAnniversary, let birthDate = effectiveBirthDate else { return nil }
        return SchoolAge.milestone(inYear: row.gregorian, birthDate: birthDate)
    }

    /// 本命星。生年月日が分かるときは立春の区切りを見て正確に求める
    /// 九星は年そのものの性質なので、どの年の行でも表示する。
    /// 本人の生まれ年だけは、立春の区切りを見て正確な星に差し替える。
    /// 記念日には生まれ年の概念が無いため、立春区切りの精密判定は行わない
    private var nineStar: NineStar? {
        if !isShowingAnniversary,
           let birthDate = effectiveBirthDate,
           let birthYear = AgeCalculator.birthYear(from: birthDate),
           birthYear == row.gregorian {
            return NineStar.forBirthDate(birthDate)
        }
        return NineStar.forStarYear(row.gregorian)
    }

    /// 厄年の判定に使う性別。自分は設定、名簿は選んだ人のものを使う
    private var effectiveGender: Gender {
        switch ageDisplayMode {
        // 年齢一覧は不特定の人を並べたものなので性別が決まらない
        case .age: .unspecified
        case .personal: settings.gender
        case .person: selectedPerson?.gender ?? .unspecified
        }
    }

    /// その年の厄年。生まれる前の年には出さない
    private var unluckyYear: UnluckyYear? {
        guard effectiveGender != .unspecified,
              let age = displayedAge, 0 <= age else { return nil }
        return UnluckyYear.forActualAge(age, gender: effectiveGender)
    }

    private var displayedAge: Int? {
        // 記念日には年齢の概念が無いため、賀寿・厄年の判定にも使う
        // この値は記念日選択時に nil になり、それらを自動的に非表示にする
        guard !isShowingAnniversary else { return nil }
        return AgeCalculator.displayedAge(
            for: row.gregorian,
            mode: ageDisplayMode,
            birthDate: effectiveBirthDate,
            currentYear: Calendar.current.component(.year, from: .now)
        )
    }

    /// 記念日を選んでいるときの周年数
    private var anniversaryCount: Int? {
        guard isShowingAnniversary, let startDate = effectiveBirthDate else { return nil }
        return AgeCalculator.anniversaryCount(for: row.gregorian, startDate: startDate)
    }

    /// 日本語の読み。ja はかなのみ、en はかなとローマ字を併記する
    private func reading(kana: String, romaji: String) -> String {
        isJapanese ? "（\(kana)）" : "（\(kana) / \(romaji)）"
    }

    private var isJapanese: Bool {
        Locale.current.language.languageCode?.identifier == "ja"
    }

    /// 年の意味を1行で説明する。操作の案内にあたるため訳す
    private func ageDescription(_ age: Int) -> String {
        // 数え年は元日に1つ増えるので、その年の満年齢より1つ多い
        let showsTraditional = settings.showsTraditionalAge && 0 < age
        let traditional = AgeCalculator.traditionalAge(fromActual: age)

        switch ageDisplayMode {
        case .age:
            // 年齢が負の年はまだ生まれていないため、経過年数で表す
            if age > 0 {
                // 数え年と満年齢をひと続きの文にまとめ、最後で「誕生年です」と結ぶ
                return showsTraditional
                    ? String(localized: "今年の元日で数え\(traditional)歳\n今年の誕生日で満\(age)歳\nになる方の誕生年です")
                    : String(localized: "今年の誕生日で満\(age)歳になる方の誕生年です")
            } else if age == 0 {
                return String(localized: "今年生まれた方の誕生年")
            } else {
                return String(localized: "\(-age)年後に生まれる方の誕生年")
            }
        case .personal, .person:
            // 生年より前の年は、生まれるまでの残り年数で表す
            if age > 0 {
                return showsTraditional
                    ? String(localized: "この年の元日で数え\(traditional)歳\nこの年の誕生日で満\(age)歳")
                    : String(localized: "この年の誕生日で満\(age)歳")
            } else if age == 0 {
                return String(localized: "この年に生まれました")
            } else {
                return String(localized: "生まれるまであと\(-age)年")
            }
        }
    }

    /// 記念日の周年を1行で説明する。操作の案内にあたるため訳す
    private func anniversaryDescription(_ count: Int) -> String {
        if count > 0 {
            String(localized: "この年で\(count)周年")
        } else if count == 0 {
            String(localized: "この年から数え始めます")
        } else {
            String(localized: "始まるまであと\(-count)年")
        }
    }

    /// 設定がONのあいだは「自分」のときだけメモを表示する
    private var showsMemo: Bool {
        settings.showsMemoOnlyForSelf ? ageDisplayMode == .personal : true
    }

    private var memoEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("メモ")
                    .font(.headline)
                Spacer()
                Text("\(AppConfig.maximumMemoLength - memoText.count)文字")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $memoText)
                .frame(minHeight: 140)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                }

            if let error = memoStore.lastError {
                Text(error.message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// iPadでは概要・メモ・カレンダーが収まる中間サイズにする
private struct YearDetailPresentationSizingModifier: ViewModifier {
    let usesBalancedSize: Bool
    let includesMemo: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), usesBalancedSize {
            content.presentationSizing(YearDetailBalancedSizing(includesMemo: includesMemo))
        } else {
            content
        }
    }
}

/// メモの有無に応じて余白が大きくなりすぎない高さを提案する
@available(iOS 18.0, *)
private struct YearDetailBalancedSizing: PresentationSizing {
    let includesMemo: Bool

    func proposedSize(for root: PresentationSizingRoot, context: PresentationSizingContext) -> ProposedViewSize {
        ProposedViewSize(width: 720, height: includesMemo ? 1_040 : 820)
    }
}
