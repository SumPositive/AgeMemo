// 年の詳細情報、カレンダー、メモ編集を一画面で提供する

import SwiftUI

struct YearDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MemoStore.self) private var memoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let row: YearRow
    @State private var memoText: String

    init(row: YearRow) {
        self.row = row
        _memoText = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summary
                    YearCalendarView(row: row)
                    memoEditor
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("\(row.gregorian)年")
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
            Text("\(row.gregorian)年  \(row.eraDisplayText)")
                .font(.title2.bold())

            if let age = AgeCalculator.age(in: row.gregorian, birthDate: settings.birthDate) {
                Text("誕生日以降の満年齢 \(age)歳")
                    .foregroundStyle(age < 0 ? .secondary : .primary)
            }

            Text("\(row.stemBranch.branch.emoji) \(row.stemBranch.kanji)（\(row.stemBranch.kana)）")
            Text("十二支 \(row.stemBranch.branch.kanji)（\(row.stemBranch.branch.kana)）")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
