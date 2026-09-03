// 年一覧と各操作を提供する主画面

import SwiftUI

private enum PresentedSheet: Identifiable {
    case detail(Int)
    case age
    case person
    case era
    case settings(requestsBirthDateRegistration: Bool)

    var id: String {
        switch self {
        case .detail(let year): "detail-\(year)"
        case .age: "age"
        case .person: "person"
        case .era: "era"
        case .settings(let requestsBirthDateRegistration):
            requestsBirthDateRegistration ? "settings-birth-date" : "settings"
        }
    }
}

private struct YearScrollRequest: Equatable {
    let id = UUID()
    let year: Int
}

struct YearListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(MemoStore.self) private var memoStore
    @Environment(PersonStore.self) private var personStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var rows = JapaneseEra.makeRows()
    @State private var scrollRequest: YearScrollRequest?
    @State private var presentedSheet: PresentedSheet?
    @State private var didSetInitialPosition = false
    @State private var selectedToolbarAction = MainToolbarAction.age
    @State private var ageDisplayMode = AgeDisplayMode.age
    /// 選択人物は値コピーではなくIDで保持し、名簿の編集へ追随させる
    @State private var selectedPersonID: UUID?
    /// シートから移動した年。その行を移動先として明示する
    @State private var selectedDestinationYear: Int?
    /// selectedDestinationYear が年齢指定ジャンプによるものか。
    /// 元号指定ジャンプや名簿選択でも同じ状態を使うため、区別しないと
    /// それらの移動先にも「誕生日前なら」カプセルが出てしまう
    @State private var isAgeJumpDestination = false
    /// 一覧でタップした年。次の一覧切り替えまたは移動まで明示する
    @State private var tappedYear: Int?

    /// 復帰時に年越しを反映できるよう状態値として保持する
    @State private var currentYear = Calendar.current.component(.year, from: .now)

    private var selectedPerson: Person? {
        guard let selectedPersonID else { return nil }
        return personStore.people.first { $0.id == selectedPersonID }
    }

    private var birthYear: Int? {
        AgeCalculator.birthYear(from: settings.birthDate)
    }

    /// 設定がONのあいだは「自分」のときだけメモを表示する
    private var showsMemo: Bool {
        settings.showsMemoOnlyForSelf ? ageDisplayMode == .personal : true
    }

    /// 一覧で強調する生年。自分／名簿の各モードで基準となる年を示す
    private var highlightedBirthYear: Int? {
        switch ageDisplayMode {
        case .age: nil
        case .personal: birthYear
        case .person: selectedPerson?.birthYear
        }
    }

    /// 年齢列の下に添える、もう一方の年齢の可能性。
    /// 年齢一覧はジャンプ先の行に、自分／名簿一覧は当年の1つ前の行（＝当年行の直前）に付ける
    /// 「1つ前の年」の行に付けるヒント。カプセルはその行の下＝次の年（選択行／当年行）の
    /// 直前に表示され、上向き矢印でその行を指す
    private func alternateAgeHint(for year: Int) -> AlternateAgeHint? {
        switch ageDisplayMode {
        case .age:
            // 生年月日が分からないため、指定した年齢の人は「選択行の年に生まれた」
            // 可能性と「その1年前に生まれ、まだ誕生日前」の可能性の両方がある
            guard isAgeJumpDestination,
                  let selectedDestinationYear,
                  year == selectedDestinationYear - 1,
                  AppConfig.yearRange.contains(selectedDestinationYear - 1) else { return nil }
            return AlternateAgeHint(kind: .ageJump, value: selectedDestinationYear - 1)
        case .personal, .person:
            guard year == currentYear - 1,
                  let birthDate = effectiveBirthDate,
                  AgeCalculator.isBeforeBirthday(birthDate: birthDate),
                  let currentAge = displayedAge(for: currentYear) else { return nil }
            let alternateAge = currentAge - 1
            // 今年生まれた人（数え年1歳・満年齢0歳）は「誕生日前」が生まれる前を
            // 意味してしまうため、その手前の値は出さない
            let lowerBound = settings.ageReckoning.age(fromActual: 0)
            guard lowerBound <= alternateAge else { return nil }
            return AlternateAgeHint(kind: .beforeBirthdayToday, value: alternateAge)
        }
    }

    /// 1行分の表示。body 側に直接書くと式が大きくなりすぎて型チェックが
    /// 破綻するため、独立した関数として切り出す
    @ViewBuilder
    private func rowView(for row: YearRow) -> some View {
        let rowAge: Int? = displayedAge(for: row.gregorian)
        let rowMemo: String? = showsMemo ? memoStore.text(for: row.gregorian) : nil
        let rowIsCurrentYear: Bool = row.gregorian == currentYear
        let rowIsBirthYear: Bool = row.gregorian == highlightedBirthYear
        let rowIsSelected: Bool = row.gregorian == selectedDestinationYear
        let rowIsTapped: Bool = row.gregorian == tappedYear
        let rowShowsAgeFirst: Bool = ageDisplayMode == .age
        let rowLongevity: Longevity? = longevity(for: row.gregorian)
        let rowUnluckyYear: UnluckyYear? = unluckyYear(for: row.gregorian)
        let rowSchoolMilestone: SchoolMilestone? = schoolMilestone(for: row.gregorian)
        let rowNineStar: NineStar? = nineStar(for: row.gregorian)
        let rowCompact: Bool = effectiveDisplayMode == .expert
        let rowAlternateAgeHint: AlternateAgeHint? = alternateAgeHint(for: row.gregorian)
        let rowAccessibilityID = "row.\(row.gregorian)"

        VStack(spacing: 0) {
            YearRowView(
                row: row,
                age: rowAge,
                memo: rowMemo,
                isCurrentYear: rowIsCurrentYear,
                isBirthYear: rowIsBirthYear,
                isSelected: rowIsSelected,
                isTapped: rowIsTapped,
                showsAgeFirst: rowShowsAgeFirst,
                showsZodiac: settings.showsZodiac,
                longevity: rowLongevity,
                unluckyYear: rowUnluckyYear,
                schoolMilestone: rowSchoolMilestone,
                nineStar: rowNineStar,
                reservesBadgeColumn: reservesBadgeColumn,
                alternateAgeHint: rowAlternateAgeHint,
                compact: rowCompact
            )
            .onTapGesture {
                // 詳細を閉じた後も、どの行を開いたか分かるようにする
                tappedYear = row.gregorian
                presentedSheet = .detail(row.gregorian)
            }
            // 行の中身は個別の Text に分かれていて、そのままでは
            // コンテナに付けた識別子が公開されない。1要素にまとめる
            .accessibilityElement(children: .combine)
            // fastlane snapshot から特定の年を開くため
            .accessibilityIdentifier(rowAccessibilityID)

            Divider()
                .padding(.leading, 12)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            rowView(for: row)
                                .id(row.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .task {
                    guard !didSetInitialPosition else { return }
                    didSetInitialPosition = true
                    var initialYear = currentYear
#if DEBUG
                    if SnapshotSetup.isActive {
                        // 撮影時の1枚目は2026年を移動先として明示する
                        initialYear = SnapshotSetup.initialListYear
                        selectedDestinationYear = initialYear
                    }
#endif
                    // 初回レイアウト後に撮影用の年または当年へ移動する
                    await Task.yield()
                    proxy.scrollTo(initialYear, anchor: .center)
                }
                .onChange(of: scrollRequest) { _, request in
                    guard let request else { return }
                    withAnimation(.easeInOut) {
                        proxy.scrollTo(request.year, anchor: .center)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        presentedSheet = .settings(requestsBirthDateRegistration: false)
                    } label: {
                        // ToolbarItem の外側に付けた識別子は公開されないことがあるため、
                        // ラベル側にも同じ識別子を持たせる
                        Label("設定", systemImage: "gearshape")
                            .accessibilityIdentifier("nav.settings")
                    }
                    .accessibilityIdentifier("nav.settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentedSheet = .era
                    } label: {
                        Label("移動", systemImage: "arrow.up.forward")
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if isBeginner {
                        beginnerCaptions
                    }
                    // 横向きは一覧に使える高さが少ないためバナーを出さない。
                    // ただし中身が空になると safeAreaInset がレイアウトを確定できず
                    // インセットが画面全体へ膨張するため、高さ0の実体を必ず置く
                    if isLandscape {
                        Color.clear.frame(height: 0)
                    } else {
                        HeaderBannerView()
                    }
                }
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomToolbar(
                    displayMode: effectiveDisplayMode,
                    selection: selectedToolbarAction,
                    action: handleToolbarAction
                )
            }
        }
        .overlay(alignment: .topLeading) {
#if DEBUG
            if SnapshotSetup.isActive {
                // UIテストから1963年詳細を直接開くための撮影専用操作
                Button {
                    presentedSheet = .detail(SnapshotSetup.detailYear)
                } label: {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("1963年詳細を開く")
                .accessibilityIdentifier("snapshot.open1963Detail")
            }
#endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshCurrentYear()
            } else {
                memoStore.flushPendingSave()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            // 起動したまま日付が変わった場合も当年を更新する
            refreshCurrentYear()
        }
        .onChange(of: personStore.people) { _, people in
            // 選択中人物が削除されたら年齢一覧へ安全に戻す
            guard ageDisplayMode == .person,
                  let selectedPersonID,
                  !people.contains(where: { $0.id == selectedPersonID }) else { return }
            self.selectedPersonID = nil
            ageDisplayMode = .age
            selectedToolbarAction = .age
            selectedDestinationYear = nil
            isAgeJumpDestination = false
            tappedYear = nil
            // 名簿シートを閉じずに当年へ戻す
            scrollRequest = YearScrollRequest(year: currentYear)
        }
        .sheet(item: $presentedSheet) { sheet in
            sheetContent(sheet)
                .appAppearance(colorScheme: sheetColorScheme)
        }
    }

    /// 横向きは縦の余白が乏しい。ヒントや広告に高さを使うと一覧が数行しか
    /// 見えなくなるため、設定が初心者でも達人として扱う
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    /// 画面の向きまで加味した実効の表示モード
    private var effectiveDisplayMode: DisplayMode {
        isLandscape ? .expert : settings.displayMode
    }

    private var isBeginner: Bool {
        effectiveDisplayMode == .beginner
    }

    /// 一覧の使い方。モードごとに引く向きが違うので、それぞれに合わせて説明する
    /// 一覧の使い方。モードとメモ表示の組み合わせごとに1つの訳文とする。
    /// 文を連結すると訳したときに語順が崩れるため、あえて分割しない
    private var listHelp: LocalizedStringKey {
        switch (ageDisplayMode, showsMemo) {
        case (.age, true):
            "年齢を指定すると、その年齢の方が生まれた年へ移動します。行をタップすると、その年のカレンダーとメモが開きます。メモにはその年の出来事を書き留められます。"
        case (.age, false):
            "年齢を指定すると、その年齢の方が生まれた年へ移動します。行をタップすると、その年のカレンダーが開きます。"
        case (.personal, true):
            "自分の生年月日をもとに、各年に何歳になるかを表示します。行をタップすると、その年のカレンダーとメモが開きます。メモにはその年の出来事を書き留められます。"
        case (.personal, false):
            "自分の生年月日をもとに、各年に何歳になるかを表示します。行をタップすると、その年のカレンダーが開きます。"
        case (.person, true):
            "名簿で選んだ方の生年月日をもとに、各年に何歳になるかを表示します。行をタップすると、その年のカレンダーとメモが開きます。メモにはその年の出来事を書き留められます。"
        case (.person, false):
            "名簿で選んだ方の生年月日をもとに、各年に何歳になるかを表示します。行をタップすると、その年のカレンダーが開きます。"
        }
    }

    /// 初心者モードで一覧の読み方を示す。年齢一覧と自分／名簿では引く向きが逆になる
    private var listSummary: LocalizedStringKey {
        switch ageDisplayMode {
        case .age: "年齢と生まれた年の早見表"
        case .personal, .person: "年と年齢の早見表"
        }
    }

    /// ツールバーのボタン1つ分の幅。説明をその真下で中央寄せにする。
    /// ボタン自体は文字サイズで広がらないため、ここも固定幅にして中央の説明の幅を確保する
    private let sideCaptionWidth: CGFloat = 44
    /// ツールバーボタンの画面端からの余白。キャプションの枠をボタンと同じ位置に置く
    private let toolbarHorizontalInset: CGFloat = 16

    /// 初心者モードの説明行。ボタンのカプセルに収めると文字が欠けるため、
    /// ナビゲーションバーの下に別の行として置く
    private var beginnerCaptions: some View {
        // 左右はボタンの真下に固定し、中央の説明は残りの幅の中だけで縮める。
        // HStack に並べると中央が左右を押し出すため、重ねて配置する
        HStack(alignment: .top, spacing: 0) {
            Text("設定")
                .minimumScaleFactor(0.4)
                .frame(width: sideCaptionWidth)
            Spacer(minLength: 0)
            Text("移動")
                .minimumScaleFactor(0.4)
                .frame(width: sideCaptionWidth)
        }
        .overlay {
            // 中央の要約に (i) を添えて、一覧の読み方とタップ操作の説明を開けるようにする
            HStack(spacing: 2) {
                Text(listSummary)
                    // 縮むのは中央だけにして、左右はボタンの真下から動かさない
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                BeginnerHelpBanner(listHelp)
            }
            .padding(.horizontal, sideCaptionWidth + 4)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, toolbarHorizontalInset)
        // タイトルとの間は詰め、一覧との間は空けて区切りを分かりやすくする
        .padding(.top, -6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // シートでは「自動」も現在の外観へ解決して渡す。
    // nil のままだと直前の明示値が残り、自動へ戻した時に追随しない
    private var sheetColorScheme: ColorScheme? {
        settings.appearanceMode.colorScheme ?? colorScheme
    }

    /// アプリ名は en ではラテンブランド名を出す。
    /// 名簿の人物名は訳す対象ではないため、ここは `String` のまま組み立てる
    private var navigationTitle: String {
        let appName = String(localized: "和暦年齢メモ")
        switch ageDisplayMode {
        case .age, .personal:
            return appName
        case .person:
            return selectedPerson?.name ?? appName
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: PresentedSheet) -> some View {
        switch sheet {
        case .detail(let year):
            if let row = rows.first(where: { $0.gregorian == year }) {
                YearDetailView(
                    row: row,
                    ageDisplayMode: ageDisplayMode,
                    selectedPersonID: selectedPersonID
                )
            }
        case .age:
            AgeJumpSheet(placeholderAge: settings.lastEnteredAge, currentYear: currentYear) { enteredAge, year in
                // 次回のシート表示で前回の年齢を初期値にする
                settings.lastEnteredAge = enteredAge
                selectedDestinationYear = year
                isAgeJumpDestination = true
                scroll(to: year)
            }
        case .person:
            PersonSheet { person in
                selectedPersonID = person.id
                ageDisplayMode = .person
                scroll(to: currentYear)
            }
        case .era:
            EraJumpSheet(
                rows: rows,
                ageDisplayMode: ageDisplayMode,
                birthDate: effectiveBirthDate,
                initialSelectionID: settings.lastJumpSelectionID,
                initialInput: settings.lastJumpInput
            ) { year in
                // 年号指定でも移動先の行を明示する
                selectedDestinationYear = year
                isAgeJumpDestination = false
                scroll(to: year)
            }
        case .settings(let requestsBirthDateRegistration):
            SettingsView(requestsBirthDateRegistration: requestsBirthDateRegistration)
        }
    }

    private func handleToolbarAction(_ action: MainToolbarAction) {
        // 最後に選択した操作を下部タブへ反映する
        selectedToolbarAction = action
        // 一覧を切り替えた時点でタップ行の明示を解除する
        tappedYear = nil
        switch action {
        case .age:
            ageDisplayMode = .age
            presentedSheet = .age
        case .personal:
            ageDisplayMode = .personal
            selectedDestinationYear = nil
            isAgeJumpDestination = false
            if birthYear != nil {
#if DEBUG
                // 撮影時は設定画面を経由せず、自分一覧の補助表示をすべて有効にする
                SnapshotSetup.enableAuxiliaryDisplaysIfNeeded(settings: settings)
#endif
                scroll(to: currentYear)
            } else {
                // 設定画面から生年月日入力を直接開き、登録が必要な理由を案内する
                presentedSheet = .settings(requestsBirthDateRegistration: true)
            }
        case .person:
            selectedDestinationYear = nil
            isAgeJumpDestination = false
            presentedSheet = .person
        }
    }

    private func scroll(to year: Int) {
        let boundedYear = min(max(year, AppConfig.yearRange.lowerBound), AppConfig.yearRange.upperBound)
        // 移動操作では以前にタップした行の明示を解除する
        tappedYear = nil
        // 同じ年を再度選んだ場合もスクロールを実行する
        scrollRequest = YearScrollRequest(year: boundedYear)
        presentedSheet = nil
    }

    /// 年をまたいで復帰した場合は当年を更新して中央へ移動する
    private func refreshCurrentYear() {
        let refreshedYear = Calendar.current.component(.year, from: .now)
        guard currentYear != refreshedYear else { return }
        currentYear = refreshedYear
        scroll(to: refreshedYear)
    }

    /// その年に迎える賀寿。生まれる前の年には出さない
    /// 学齢・賀寿・厄年のいずれかがONなら、該当しない年でも列幅を確保する。
    /// 行ごとに列位置がずれると一覧として読みにくいため
    private var reservesBadgeColumn: Bool {
        settings.showsLongevity || settings.showsSchoolAge || settings.showsUnluckyYear
    }

    private func longevity(for year: Int) -> Longevity? {
        guard settings.showsLongevity,
              let age = displayedAge(for: year), 0 <= age else { return nil }
        return Longevity.forDisplayedAge(age, reckoning: settings.ageReckoning)
    }

    /// 九星は年そのものの性質なので、どの年の行でも出す。
    /// 本人の生まれ年だけは、立春の区切りを見て正確な星に差し替える
    private func nineStar(for year: Int) -> NineStar? {
        guard settings.showsNineStar else { return nil }
        if let birthDate = effectiveBirthDate,
           let birthYear = AgeCalculator.birthYear(from: birthDate),
           birthYear == year {
            return NineStar.forBirthDate(birthDate)
        }
        return NineStar.forStarYear(year)
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

    /// 学齢の判定に使う生年月日。年齢一覧は特定の人ではないので対象外
    private var effectiveBirthDate: Date? {
        switch ageDisplayMode {
        case .age: nil
        case .personal: settings.birthDate
        case .person: selectedPerson?.birthDate
        }
    }

    /// その年に在籍する学年
    private func schoolMilestone(for year: Int) -> SchoolMilestone? {
        guard settings.showsSchoolAge, let birthDate = effectiveBirthDate else { return nil }
        return SchoolAge.milestone(inYear: year, birthDate: birthDate)
    }

    /// その年の厄年。生まれる前の年には出さない
    private func unluckyYear(for year: Int) -> UnluckyYear? {
        guard settings.showsUnluckyYear,
              effectiveGender != .unspecified,
              let age = displayedAge(for: year), 0 <= age else { return nil }
        return UnluckyYear.forDisplayedAge(age, gender: effectiveGender, reckoning: settings.ageReckoning)
    }

    private func displayedAge(for year: Int) -> Int? {
        AgeCalculator.displayedAge(
            for: year,
            mode: ageDisplayMode,
            birthDate: effectiveBirthDate,
            currentYear: currentYear,
            reckoning: settings.ageReckoning
        )
    }
}
