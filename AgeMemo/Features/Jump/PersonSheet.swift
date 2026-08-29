// 名簿から人を選んで現在年へ移動し、登録・変更・削除を行う

import SwiftUI

struct PersonSheet: View {
    @Environment(PersonStore.self) private var personStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var editorTarget: PersonEditorTarget?
    @State private var pendingDeletion: Person?

    let currentYear: Int
    let select: (Person) -> Void

    /// Listは常に画面いっぱいに広がるため、行数から必要最小限の高さを見積もる
    @ScaledMetric(relativeTo: .body) private var estimatedRowHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var estimatedChromeHeight: CGFloat = 140

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

        【選ぶ】
        名前の行をタップすると、その方を基準にした一覧へ切り替わります。

        【追加】
        右上の＋を押し、名前と生年月日を入力して保存します。

        【変更】
        行の右端にある変更ボタンを押すと、名前と生年月日を編集できます。行を左へスワイプして「変更」を選ぶこともできます。

        【削除】
        行を左へスワイプして「削除」を選びます。確認の後に削除され、取り消しはできません。

        【並べ替え】
        行を長押ししたまま上下へドラッグすると、好きな順序に並べ替えられます。並び順は保存され、追加や変更をしても崩れません。
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

    private func row(for person: Person) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                Text("\(String(person.birthYear))年生まれ・\(String(settings.ageReckoning.age(fromActual: currentYear - person.birthYear)))歳")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

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
    /// 追加のときは名前が未入力なので、開いた直後に入力を始められるようにする
    @FocusState private var isNameFocused: Bool

    let target: PersonEditorTarget

    init(target: PersonEditorTarget) {
        self.target = target
        switch target {
        case .add:
            _name = State(initialValue: "")
            _gender = State(initialValue: .unspecified)
        case .edit(let person):
            _name = State(initialValue: person.name)
            _gender = State(initialValue: person.gender)
        }
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
            onContentInteraction: { isNameFocused = false }
        ) { birthDate in
            switch target {
            case .add:
                personStore.add(name: trimmedName, birthDate: birthDate, gender: gender)
            case .edit(let person):
                personStore.update(id: person.id, name: trimmedName, birthDate: birthDate, gender: gender)
            }
        } header: {
            VStack(alignment: .leading, spacing: 8) {
                TextField("名前", text: $name)
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

                // 厄年の判定に使う。生年月日の前に置く
                AZAdaptiveRadioRow(
                    options: Gender.allCases,
                    selection: $gender,
                    minOptionWidth: 0,
                    maxOptionWidth: 120,
                    horizontalPadding: 6,
                    optionSpacing: 4,
                    groupPadding: 5
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
