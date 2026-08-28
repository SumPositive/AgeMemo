// 年一覧と各操作を提供する主画面

import SwiftUI

private enum PresentedSheet: Identifiable {
    case detail(Int)
    case age
    case person
    case era
    case settings

    var id: String {
        switch self {
        case .detail(let year): "detail-\(year)"
        case .age: "age"
        case .person: "person"
        case .era: "era"
        case .settings: "settings"
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

    @State private var rows = JapaneseEra.makeRows()
    @State private var scrollRequest: YearScrollRequest?
    @State private var presentedSheet: PresentedSheet?
    @State private var didSetInitialPosition = false
    @State private var selectedToolbarAction = MainToolbarAction.age
    @State private var ageDisplayMode = AgeDisplayMode.age
    @State private var selectedPerson: Person?
    /// 年齢シートで指定された年齢に対応する生年。その行を選択色で示す
    @State private var selectedAgeYear: Int?

    private let currentYear = Calendar.current.component(.year, from: .now)

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

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isBeginner {
                            HStack(alignment: .center, spacing: 4) {
                                Text(listHint)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    // 文字が大きく折り返す時も中央に揃える
                                    .multilineTextAlignment(.center)
                                BeginnerHelpBanner(listHelp)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                        }

                        ForEach(rows) { row in
                            // 年ごとに単一のスクロール対象として識別する
                            VStack(spacing: 0) {
                                YearRowView(
                                    row: row,
                                    age: displayedAge(for: row.gregorian),
                                    memo: showsMemo ? memoStore.text(for: row.gregorian) : nil,
                                    isCurrentYear: row.gregorian == currentYear,
                                    isBirthYear: row.gregorian == highlightedBirthYear,
                                    isSelected: row.gregorian == selectedAgeYear,
                                    showsAgeFirst: ageDisplayMode == .age,
                                    compact: settings.displayMode == .expert
                                )
                                .onTapGesture {
                                    presentedSheet = .detail(row.gregorian)
                                }

                                Divider()
                                    .padding(.leading, 12)
                            }
                            .id(row.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .task {
                    guard !didSetInitialPosition else { return }
                    didSetInitialPosition = true
                    // 初回レイアウト後に当年へ移動する
                    await Task.yield()
                    proxy.scrollTo(currentYear, anchor: .center)
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
                        presentedSheet = .settings
                    } label: {
                        Label("設定", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentedSheet = .era
                    } label: {
                        Label("飛躍", systemImage: "arrow.up.forward")
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if isBeginner {
                        beginnerCaptions
                    }
                    HeaderBannerView()
                }
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomToolbar(
                    displayMode: settings.displayMode,
                    selection: selectedToolbarAction,
                    action: handleToolbarAction
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                memoStore.flushPendingSave()
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            sheetContent(sheet)
                .appAppearance(colorScheme: sheetColorScheme)
        }
    }

    private var isBeginner: Bool {
        settings.displayMode == .beginner
    }

    /// 一覧上のヒント。メモを表示しない設定のときはメモに触れない
    private var listHint: String {
        showsMemo ? "行をタップするとメモとカレンダーが現れます" : "行をタップするとカレンダーが現れます"
    }

    /// 一覧の使い方。モードごとに引く向きが違うので、それぞれに合わせて説明する
    private var listHelp: String {
        let tapGuide = showsMemo
            ? "行をタップすると、その年のカレンダーとメモが開きます。メモにはその年の出来事を書き留められます。"
            : "行をタップすると、その年のカレンダーが開きます。"
        switch ageDisplayMode {
        case .age:
            return "年齢を指定すると、その年齢の方が生まれた年へ移動します。" + tapGuide
        case .personal:
            return "自分の生年月日をもとに、各年に何歳になるかを表示します。" + tapGuide
        case .person:
            return "名簿で選んだ方の生年月日をもとに、各年に何歳になるかを表示します。" + tapGuide
        }
    }

    /// 初心者モードで一覧の読み方を示す。年齢一覧と自分／名簿では引く向きが逆になる
    private var listSummary: String {
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
            Text("飛躍")
                .minimumScaleFactor(0.4)
                .frame(width: sideCaptionWidth)
        }
        .overlay {
            Text(listSummary)
                // 縮むのは中央だけにして、左右はボタンの真下から動かさない
                .lineLimit(1)
                .minimumScaleFactor(0.4)
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

    private var navigationTitle: String {
        switch ageDisplayMode {
        case .age, .personal:
            "和暦年齢メモ"
        case .person:
            selectedPerson?.name ?? "和暦年齢メモ"
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: PresentedSheet) -> some View {
        switch sheet {
        case .detail(let year):
            if let row = rows.first(where: { $0.gregorian == year }) {
                YearDetailView(row: row, ageDisplayMode: ageDisplayMode)
            }
        case .age:
            AgeJumpSheet(placeholderAge: settings.lastEnteredAge, currentYear: currentYear) { enteredAge, year in
                // 次回のシート表示で前回の年齢を初期値にする
                settings.lastEnteredAge = enteredAge
                selectedAgeYear = year
                scroll(to: year)
            }
        case .person:
            PersonSheet(currentYear: currentYear) { person in
                selectedPerson = person
                ageDisplayMode = .person(person.birthDate)
                scroll(to: currentYear)
            }
        case .era:
            EraJumpSheet(rows: rows) { scroll(to: $0) }
        case .settings:
            SettingsView()
        }
    }

    private func handleToolbarAction(_ action: MainToolbarAction) {
        // 最後に選択した操作を下部タブへ反映する
        selectedToolbarAction = action
        switch action {
        case .age:
            ageDisplayMode = .age
            presentedSheet = .age
        case .personal:
            ageDisplayMode = .personal
            selectedAgeYear = nil
            if birthYear != nil {
                scroll(to: currentYear)
            } else {
                presentedSheet = .settings
            }
        case .person:
            selectedAgeYear = nil
            presentedSheet = .person
        }
    }

    private func scroll(to year: Int) {
        let boundedYear = min(max(year, AppConfig.yearRange.lowerBound), AppConfig.yearRange.upperBound)
        // 同じ年を再度選んだ場合もスクロールを実行する
        scrollRequest = YearScrollRequest(year: boundedYear)
        presentedSheet = nil
    }

    private func displayedAge(for year: Int) -> Int? {
        AgeCalculator.displayedAge(
            for: year,
            mode: ageDisplayMode,
            birthDate: settings.birthDate,
            currentYear: currentYear
        )
    }
}
