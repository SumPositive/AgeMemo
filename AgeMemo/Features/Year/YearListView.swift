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
                        if settings.displayMode == .beginner {
                            Text("年をタップすると、カレンダーとメモを表示します")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                HeaderBannerView()
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
            // シートは別ウインドウ層に出るため外観設定を明示的に引き継ぐ
            sheetContent(sheet)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
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
            if birthYear != nil {
                scroll(to: currentYear)
            } else {
                presentedSheet = .settings
            }
        case .person:
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
