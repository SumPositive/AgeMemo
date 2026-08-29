// 年の詳細情報、カレンダー、メモ編集を一画面で提供する

import SwiftUI

struct YearDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MemoStore.self) private var memoStore
    @Environment(PersonStore.self) private var personStore
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
            // 年は本文の見出しに出るため、シートのタイトルには置かない
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

    /// その年に元年が始まった元号。1月1日開始（＝前年からの継続）は改元ではないので除く
    /// 見出しに出す元号。改元年は年初の元号だけにし、新元号は次の行へ回す
    private var headlineEraText: String {
        guard ganNenSpan != nil, let first = row.eraSpans.first else {
            return row.eraDisplayText
        }
        return first.displayText
    }

    private var ganNenSpan: EraSpan? {
        row.eraSpans.first { $0.isGanNen && !($0.startMonth == 1 && $0.startDay == 1) }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 改元年は元号を並べず、年初の元号だけを見出しに置く
            Text("\(String(row.gregorian))年  \(headlineEraText)")
                .font(.title2.bold())

            if let ganNen = ganNenSpan {
                // 改元があった年は、いつから元年になったのかを次の行に添える
                Text("\(ganNen.eraName)元年（\(String(ganNen.startMonth))月\(String(ganNen.startDay))日〜）")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let age = displayedAge {
                Text(ageDescription(age))
                    .foregroundStyle(age < 0 ? .secondary : .primary)
            }

            if let longevity {
                Text("🎉 \(longevity.name)（\(longevity.kana)）")
                    .foregroundStyle(.tint)
            }

            if let unluckyYear {
                Text(unluckyYear.isMajor ? "\(unluckyYear.name)（大厄）" : unluckyYear.name)
                    .foregroundStyle(.red)
            }

            if let schoolMilestone {
                Text("🎓 \(schoolMilestone.name)")
                    .foregroundStyle(.secondary)
            }

            if let nineStar {
                Text("九星 \(nineStar.name)")
                    .foregroundStyle(.secondary)
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

    /// その年に迎える賀寿。生まれる前の年には出さない
    private var longevity: Longevity? {
        guard let age = displayedAge, 0 <= age else { return nil }
        return Longevity.forDisplayedAge(age, reckoning: settings.ageReckoning)
    }

    /// 学齢の判定に使う生年月日。年齢一覧は特定の人ではないので対象外
    private var effectiveBirthDate: Date? {
        switch ageDisplayMode {
        case .age: nil
        case .personal: settings.birthDate
        case .person(let birthDate): birthDate
        }
    }

    /// その年に迎える入学・卒業の節目
    private var schoolMilestone: SchoolMilestone? {
        guard let birthDate = effectiveBirthDate else { return nil }
        return SchoolAge.milestone(inYear: row.gregorian, birthDate: birthDate)
    }

    /// 本命星。生年月日が分かるときは立春の区切りを見て正確に求める
    /// 九星は年そのものの性質なので、どの年の行でも表示する。
    /// 本人の生まれ年だけは、立春の区切りを見て正確な星に差し替える
    private var nineStar: NineStar? {
        if let birthDate = effectiveBirthDate,
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
        case .person(let birthDate): personGender(for: birthDate)
        }
    }

    /// 名簿から選ばれている人の性別を生年月日で引き当てる
    private func personGender(for birthDate: Date) -> Gender {
        personStore.people.first { $0.birthDate == birthDate }?.gender ?? .unspecified
    }

    /// その年の厄年。生まれる前の年には出さない
    private var unluckyYear: UnluckyYear? {
        guard effectiveGender != .unspecified,
              let age = displayedAge, 0 <= age else { return nil }
        return UnluckyYear.forDisplayedAge(age, gender: effectiveGender, reckoning: settings.ageReckoning)
    }

    private var displayedAge: Int? {
        AgeCalculator.displayedAge(
            for: row.gregorian,
            mode: ageDisplayMode,
            birthDate: settings.birthDate,
            currentYear: Calendar.current.component(.year, from: .now),
            reckoning: settings.ageReckoning
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
                switch settings.ageReckoning {
                // 数え年は元日に増えるので、誕生日を持ち出さない
                case .actual: "この年の誕生日で満\(age)歳"
                case .traditional: "この年は数え\(age)歳"
                }
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
