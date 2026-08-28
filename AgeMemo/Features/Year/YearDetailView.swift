// 年の詳細情報、カレンダー、メモ編集を一画面で提供する

import SwiftUI

struct YearDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MemoStore.self) private var memoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let row: YearRow
    @State private var memoText: String
    let ageDisplayMode: AgeDisplayMode

    init(row: YearRow, ageDisplayMode: AgeDisplayMode) {
        self.row = row
        self.ageDisplayMode = ageDisplayMode
        _memoText = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summary
                    if showsMemo {
                        memoEditor
                    }
                    YearCalendarView(row: row)
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("\(String(row.gregorian))年")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
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

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(String(row.gregorian))年  \(row.eraDisplayText)")
                .font(.title2.bold())

            if let age = displayedAge {
                Text(ageDescription(age))
                    .foregroundStyle(age < 0 ? .secondary : .primary)
            }

            Text("\(row.stemBranch.branch.emoji) \(row.stemBranch.kanji)（\(row.stemBranch.kana)）")
            Text("十二支 \(row.stemBranch.branch.kanji)（\(row.stemBranch.branch.kana)）")
                .foregroundStyle(.secondary)
        }
        // 改元年は元号が2つ並んで長くなるため、折り返さず縮小して1行に収める
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayedAge: Int? {
        AgeCalculator.displayedAge(
            for: row.gregorian,
            mode: ageDisplayMode,
            birthDate: settings.birthDate,
            currentYear: Calendar.current.component(.year, from: .now)
        )
    }

    private func ageDescription(_ age: Int) -> String {
        switch ageDisplayMode {
        case .age:
            // 年齢が負の年はまだ生まれていないため、経過年数で表す
            if age > 0 {
                "現在\(age)歳の方の誕生年"
            } else if age == 0 {
                "今年生まれた方の誕生年"
            } else {
                "\(-age)年後に生まれる方の誕生年"
            }
        case .personal, .person:
            // 生年より前の年は、生まれるまでの残り年数で表す
            if age > 0 {
                "この年の誕生日で満\(age)歳"
            } else if age == 0 {
                "この年に生まれました"
            } else {
                "生まれるまであと\(-age)年"
            }
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

            if let message = memoStore.lastErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
