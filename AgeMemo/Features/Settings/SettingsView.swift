// 表示方法と生年月日を変更する設定画面

import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @State private var isEditingBirthDate = false

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var sheetColorScheme: ColorScheme? {
        settings.appearanceMode.colorScheme ?? colorScheme
    }

    private var birthDateText: String {
        guard let birthDate = settings.birthDate else { return "未設定" }
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: birthDate)
        return String(format: "%04d/%02d/%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// 見出し＋ラジオボタンの1行。幅が足りなければ2段組みへ自動で切り替わる
    @ViewBuilder
    private func radioRow<Option: CaseIterable & Hashable & Identifiable, Label: View>(
        _ title: String,
        help: String,
        selection: Binding<Option>,
        @ViewBuilder label: @escaping (Option) -> Label
    ) -> some View where Option.AllCases == [Option] {
        AZAdaptiveRadioRow(
            options: Option.allCases,
            selection: selection,
            minOptionWidth: 0,
            maxOptionWidth: 120,
            horizontalPadding: 6,
            optionSpacing: 4,
            groupPadding: 5
        ) {
            // 設定項目の説明は見出しの右に集約する
            HStack(alignment: .center, spacing: 4) {
                Text(title)
                BeginnerHelpBanner(help)
            }
        } label: { option in
            label(option)
        }
        .padding(.vertical, 2)
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    radioRow(
                        "表示モード",
                        help: "初心者を選ぶと、ボタンの名前や一覧の見方といった説明が画面に表示されます。操作に慣れたら達人に切り替えると、説明が消えて一覧を広く使えます。",
                        selection: $settings.displayMode
                    ) { mode in
                        Text(mode.title)
                    }

                    radioRow(
                        "文字サイズ",
                        help: "アプリ内の文字の大きさを決めます。自動を選ぶと、iPhoneの「設定」→「画面表示と明るさ」→「テキストサイズ」に合わせて変わります。標準・大・特大を選ぶと、端末の設定に関わらずその大きさになります。",
                        selection: $settings.fontScale
                    ) { scale in
                        Text(scale.title)
                    }

                    radioRow(
                        "外観モード",
                        help: "画面の明るさの見た目を決めます。自動を選ぶと、iPhone本体のライトモード・ダークモードの設定に合わせて変わります。ライトまたはダークを選ぶと、端末の設定に関わらずその見た目に固定されます。",
                        selection: $settings.appearanceMode
                    ) { mode in
                        Text(mode.title)
                    }
                }

                Section {
                    Button {
                        isEditingBirthDate = true
                    } label: {
                        AZAdaptiveControlRow {
                            HStack(alignment: .center, spacing: 4) {
                                Text("自分の生年月日")
                                    .foregroundStyle(Color(.label))
                                BeginnerHelpBanner("ここに自分の生年月日を登録すると、「自分」の一覧で各年に自分が何歳になるかが表示されます。生まれた年には目印が付きます。")
                            }
                        } control: {
                            Text(birthDateText)
                                .font(.body.monospacedDigit())
                                .lineLimit(1)
                                .foregroundStyle(settings.birthDate == nil ? Color(.tertiaryLabel) : .secondary)
                        }
                    }

                    Toggle(isOn: $settings.showsMemoOnlyForSelf) {
                        HStack(alignment: .center, spacing: 4) {
                            Text("メモは自分だけに表示する")
                            BeginnerHelpBanner("オンにすると、年に書いたメモは「自分」の一覧でだけ表示されます。年齢や名簿の一覧ではメモが隠れるため、他の人に画面を見せるときに便利です。オフにするとどの一覧でもメモが表示されます。")
                        }
                    }
                }

                Section {
                    Button("取扱説明") {
                        if let url = URL(string: "https://docs.azukid.com/jp/sumpo/AgeMemo/") {
                            openURL(url)
                        }
                    }

                    Button("レビューする") {
                        requestReview()
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        Text(versionText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
            .sheet(isPresented: $isEditingBirthDate) {
                BirthDateInputSheet(title: "生年月日", birthDate: settings.birthDate) { newValue in
                    settings.birthDate = newValue
                }
                .appAppearance(colorScheme: sheetColorScheme)
            }
        }
        .presentationDragIndicator(.visible)
    }
}
