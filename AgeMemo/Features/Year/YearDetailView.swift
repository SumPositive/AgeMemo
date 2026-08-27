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
                    YearCalendarView(row: row)
                    if showsMemo {
                        memoEditor
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("\(String(row.gregorian))年")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
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
            "\(String(row.gregorian))年生まれの当年時点 \(age)歳"
        case .personal, .person:
            "誕生日以降の満年齢 \(age)歳"
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
