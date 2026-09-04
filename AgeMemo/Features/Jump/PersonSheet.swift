// 名簿から人を選んで現在年へ移動し、登録・変更・削除を行う

import SwiftUI

struct PersonSheet: View {
    @Environment(PersonStore.self) private var personStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var editorTarget: PersonEditorTarget?
    @State private var pendingDeletion: Person?

    let select: (Person) -> Void

    /// Listは常に画面いっぱいに広がるため、行数から必要最小限の高さを見積もる
    @ScaledMetric(relativeTo: .body) private var estimatedRowHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var estimatedChromeHeight: CGFloat = 140
    @ScaledMetric(relativeTo: .caption) private var summaryFontSize: CGFloat = 12

    /// 登録が増えても伸ばし続けず、この高さで止めてスクロールさせる
    @ScaledMetric(relativeTo: .body) private var maximumFittedHeight: CGFloat = 480

    private var fittedHeight: CGFloat {
        let rowCount = max(personStore.people.count, 1)
        let natural = estimatedChromeHeight + estimatedRowHeight * CGFloat(rowCount)
        return min(natural, maximumFittedHeight)
    }

    private var personSheetHelp: LocalizedStringKey {
        """
        家族・親戚・友人など、年齢を調べたい方を登録しておく名簿です。登録すると一覧がその方の生年月日を基準になり、各年に何歳になるかを確認できます。

        結婚記念日や開店日など、年ごとの区切りを数えたい日も「記念日」として登録できます。記念日を選ぶと、一覧の年齢の代わりに、その年で何周年にあたるかを表示します。

        【選ぶ】
        名前の行をタップすると、その方を基準にした一覧へ切り替わります。

        【追加】
        右上の＋を押し、「誕生日」か「記念日」を選んでから、名前（記念日は名称）と日付を入力して保存します。

        【変更】
        行の右端にある変更ボタンを押すと、内容を編集できます。行を左へスワイプして「変更」を選ぶこともできます。

        【削除】
        行を左へスワイプして「削除」を選びます。確認の後に削除され、取り消しはできません。

        【並べ替え】
        行を長押ししたまま上下へドラッグすると、好きな順序に並べ替えられます。並び順は保存され、追加や変更をしても崩れません。

        【周年の数え方】
        周年は月日を見ず、その年のうちは同じ数のままです。登録した年が0周年で、翌年から1周年になります。
        """
    }

    private var sheetColorScheme: ColorScheme? {
        settings.appearanceMode.colorScheme ?? colorScheme
    }

    var body: some View {
        NavigationStack {
            List {
                if personStore.people.isEmpty {
                    Section {
                        Text("名簿が空です。右上の＋から追加してください。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(personStore.people) { person in
                            Button {
                                select(person)
                                dismiss()
                            } label: {
                                row(for: person)
                            }
                            .buttonStyle(.plain)
                            // 端までスワイプしただけで消えないよう、必ずボタンを押させる
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeletion = person
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }

                                Button {
                                    editorTarget = .edit(person)
                                } label: {
                                    Label("変更", systemImage: "pencil")
                                }
                                .tint(.accentColor)
                            }
                        }
                        .onMove { source, destination in
                            personStore.move(from: source, to: destination)
                        }
                    }
                }

                if let error = personStore.lastError {
                    Section {
                        Text(error.message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("名簿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // 説明はタイトルの右に添える
                    HStack(alignment: .center, spacing: 4) {
                        Text("名簿")
                            .font(.headline)
                        BeginnerHelpBanner(personSheetHelp)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = .add
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
            .sheet(item: $editorTarget) { target in
                PersonEditorSheet(target: target)
                    .appAppearance(colorScheme: sheetColorScheme)
            }
            .alert("削除しますか？", isPresented: deletionBinding, presenting: pendingDeletion) { person in
                Button("削除", role: .destructive) {
                    personStore.delete(id: person.id)
                }
                Button("キャンセル", role: .cancel) {}
            } message: { person in
                Text("「\(person.name)」を削除します。この操作は取り消せません。")
            }
        }
        // 行数に応じた高さから始め、ハンドルで最大化もできるようにする
        .presentationDetents([.height(fittedHeight), .large])
        .presentationDragIndicator(.visible)
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    /// 1行表示と日付後で改行する2行表示を用意する
    private struct PersonDateSummary {
        let singleLine: String
        let twoLines: String
    }

    private func birthDateSummary(for person: Person) -> PersonDateSummary {
        let monthDay = person.birthMonthDay
        let year = String(person.birthYear)
        let month = String(monthDay.month)
        let day = String(monthDay.day)

        switch person.kind {
        case .birthday:
            // 満年齢は誕生日を迎えたかどうかで変わるので、月日まで見て求める
            let actual = String(AgeCalculator.currentActualAge(birthDate: person.birthDate))
            if settings.showsTraditionalAge {
                // 数え年は元日ごとに増えるため、誕生日は見ずに年の差へ1を足す
                let currentYear = Calendar.current.component(.year, from: .now)
                let traditional = String(currentYear - person.birthYear + 1)
                return PersonDateSummary(
                    singleLine: String(localized: "誕生日：\(year)年\(month)月\(day)日・満\(actual)歳・数え\(traditional)歳"),
                    twoLines: String(localized: "誕生日：\(year)年\(month)月\(day)日\n・満\(actual)歳・数え\(traditional)歳")
                )
            }
            return PersonDateSummary(
                singleLine: String(localized: "誕生日：\(year)年\(month)月\(day)日・満\(actual)歳"),
                twoLines: String(localized: "誕生日：\(year)年\(month)月\(day)日\n・満\(actual)歳")
            )
        case .anniversary:
            let currentYear = Calendar.current.component(.year, from: .now)
            let count = String(AgeCalculator.anniversaryCount(for: currentYear, startDate: person.birthDate))
            return PersonDateSummary(
                singleLine: String(localized: "記念日：\(year)年\(month)月\(day)日・\(count)周年"),
                twoLines: String(localized: "記念日：\(year)年\(month)月\(day)日\n・\(count)周年")
            )
        }
    }

    /// 1行、2行、2行縮小の順で収まる表示を選ぶ
    private func fittedSummary(_ summary: PersonDateSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            summaryText(summary.singleLine, lineLimit: 1, scale: 1)

            ForEach(summaryScales, id: \.self) { scale in
                summaryText(summary.twoLines, lineLimit: 2, scale: scale)
            }
        }
    }

    private func summaryText(_ text: String, lineLimit: Int, scale: CGFloat) -> some View {
        Text(verbatim: text)
            .font(.system(size: summaryFontSize * scale))
            .monospacedDigit()
            .lineLimit(lineLimit)
            .fixedSize(horizontal: true, vertical: true)
    }

    /// 2行でも収まらない場合の縮小倍率
    private var summaryScales: [CGFloat] {
        [1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5, 0.45, 0.4]
    }

    private func row(for person: Person) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                fittedSummary(birthDateSummary(for: person))
                    .foregroundStyle(.secondary)
            }
            // 編集ボタンを除いた残り幅を表示判定へ渡す
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 8)

            // 行のタップは一覧の切り替えに使うため、変更は独立したボタンにする。
            // スワイプでも変更・削除できるが気づきにくいので、常に見える導線を置く
            Button {
                editorTarget = .edit(person)
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 6)
                    .padding(.leading, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(person.name)を変更"))
        }
        .contentShape(Rectangle())
    }
}

enum PersonEditorTarget: Identifiable {
    case add
    case edit(Person)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let person): person.id.uuidString
        }
    }
}

private struct PersonEditorSheet: View {
    @Environment(PersonStore.self) private var personStore

    @State private var name: String
    @State private var gender: Gender
    @State private var kind: PersonKind
    /// 追加のときは名前が未入力なので、開いた直後に入力を始められるようにする
    @FocusState private var isNameFocused: Bool

    let target: PersonEditorTarget

    init(target: PersonEditorTarget) {
        self.target = target
        switch target {
        case .add:
            _name = State(initialValue: "")
            _gender = State(initialValue: .unspecified)
            _kind = State(initialValue: .birthday)
        case .edit(let person):
            _name = State(initialValue: person.name)
            _gender = State(initialValue: person.gender)
            _kind = State(initialValue: person.kind)
        }
    }

    private var personKindHelp: LocalizedStringKey {
        """
        「誕生日」は人の生年月日を登録し、一覧にその方の年齢を表示します。

        「記念日」は結婚記念日など、年ごとに区切りを数えたい日を登録します。一覧には年齢の代わりに、その年で何回目（何周年）にあたるかを表示します。月日は経過に関係なく、その年のうちは同じ周年数のままです。
        """
    }

    private var personGenderHelp: LocalizedStringKey {
        """
        厄年を表示するために使います。「未指定」を選ぶと、この方の厄年は表示されません。

        厄年は、人生の中で災いに遭いやすいとされる年齢です。数え年で見るのが基本で、本厄の前後1年をそれぞれ前厄・後厄と呼びます。

        男性は25歳・42歳・61歳、女性は19歳・33歳・37歳・61歳が本厄にあたります（いずれも数え年）。男性の42歳と女性の33歳はとくに「大厄」と呼ばれます。

        年齢や数え方は神社や地域によって異なる場合があります。目安としてご覧ください。
        """
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        switch target {
        case .add: "名簿に追加"
        case .edit: "名簿を変更"
        }
    }

    private var existingBirthDate: Date? {
        switch target {
        case .add: nil
        case .edit(let person): person.birthDate
        }
    }

    var body: some View {
        BirthDateInputSheet(
            title: title,
            birthDate: existingBirthDate,
            canSave: !trimmedName.isEmpty,
            isBirthDate: kind == .birthday,
            onContentInteraction: { isNameFocused = false }
        ) { birthDate in
            switch target {
            case .add:
                personStore.add(name: trimmedName, birthDate: birthDate, gender: gender, kind: kind)
            case .edit(let person):
                personStore.update(id: person.id, name: trimmedName, birthDate: birthDate, gender: gender, kind: kind)
            }
        } header: {
            VStack(alignment: .leading, spacing: 8) {
                // 種別で名前欄・性別欄・日付の単位が変わるため、名前より上に置く
                AZAdaptiveRadioRow(
                    options: PersonKind.allCases,
                    selection: $kind,
                    minOptionWidth: 0,
                    maxOptionWidth: 200,
                    horizontalPadding: 6,
                    optionSpacing: 4,
                    groupPadding: 5,
                    keepsLabelOnOneLine: true
                ) {
                    HStack(alignment: .center, spacing: 4) {
                        Text("種類")
                        BeginnerHelpBanner(personKindHelp)
                    }
                } label: { option in
                    Text(option.title)
                }
                .simultaneousGesture(TapGesture().onEnded { _ in
                    isNameFocused = false
                })
                // 記念日には厄年の概念が無いため、種類を切り替えたら未指定へ戻す
                .onChange(of: kind) { _, newValue in
                    if !newValue.showsGenderPicker { gender = .unspecified }
                }

                TextField(kind.nameFieldLabel, text: $name)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit {
                        // 改行せず名前入力を完了してキーボードを閉じる
                        isNameFocused = false
                    }
                    // 変更のときは既に名前が入っているため、勝手にキーボードを出さない
                    .onAppear {
                        guard case .add = target else { return }
                        isNameFocused = true
                    }
                    .onChange(of: name) { _, newValue in
                        if newValue.count > AppConfig.maximumPersonNameLength {
                            name = String(newValue.prefix(AppConfig.maximumPersonNameLength))
                        }
                    }

                if kind.showsGenderPicker {
                    // 厄年の判定に使う。生年月日の前に置く
                    AZAdaptiveRadioRow(
                        options: Gender.allCases,
                        selection: $gender,
                        minOptionWidth: 0,
                        maxOptionWidth: 200,
                        horizontalPadding: 6,
                        optionSpacing: 4,
                        groupPadding: 5,
                        keepsLabelOnOneLine: true
                    ) {
                        HStack(alignment: .center, spacing: 4) {
                            Text("性別")
                            BeginnerHelpBanner(personGenderHelp)
                        }
                    } label: { option in
                        Text(option.title)
                    }
                    .simultaneousGesture(TapGesture().onEnded { _ in
                        // 同じ性別を選び直した場合もキーボードを閉じる
                        isNameFocused = false
                    })
                }
            }
        }
    }
}
