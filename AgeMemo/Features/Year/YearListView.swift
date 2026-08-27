// 年一覧と下部ツールバーから各操作を提供する主画面

import SwiftUI

private enum PresentedSheet: Identifiable {
    case detail(Int)
    case age
    case zodiac
    case era
    case settings

    var id: String {
        switch self {
        case .detail(let year): "detail-\(year)"
        case .age: "age"
        case .zodiac: "zodiac"
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
    @Environment(\.scenePhase) private var scenePhase

    @State private var rows = JapaneseEra.makeRows()
    @State private var scrollRequest: YearScrollRequest?
    @State private var presentedSheet: PresentedSheet?
    @State private var didSetInitialPosition = false
    @State private var selectedToolbarAction = MainToolbarAction.current
    @State private var ageDisplayMode = AgeDisplayMode.current

    private let currentYear = Calendar.current.component(.year, from: .now)

    private var birthYear: Int? {
        AgeCalculator.birthYear(from: settings.birthDate)
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
                                    memo: memoStore.text(for: row.gregorian),
                                    isCurrentYear: row.gregorian == currentYear,
                                    isBirthYear: row.gregorian == birthYear,
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
            .navigationTitle("和暦年齢メモ")
            .navigationBarTitleDisplayMode(.inline)
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
            sheetContent(sheet)
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
            AgeJumpSheet { scroll(to: $0) }
        case .zodiac:
            ZodiacSheet(rows: rows, ageDisplayMode: ageDisplayMode) { scroll(to: $0) }
        case .era:
            EraJumpSheet(rows: rows) { scroll(to: $0) }
        case .settings:
            SettingsView()
        }
    }

    private func handleToolbarAction(_ action: MainToolbarAction) {
        // 最後に選択した操作を下部ツールバーへ反映する
        selectedToolbarAction = action
        switch action {
        case .current:
            ageDisplayMode = .current
            scroll(to: currentYear)
        case .personal:
            ageDisplayMode = .personal
            if birthYear != nil {
                scroll(to: currentYear)
            } else {
                presentedSheet = .settings
            }
        case .age:
            presentedSheet = settings.birthDate == nil ? .settings : .age
        case .zodiac:
            presentedSheet = .zodiac
        case .era:
            presentedSheet = .era
        case .settings:
            presentedSheet = .settings
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
