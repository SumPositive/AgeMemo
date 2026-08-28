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
            Text(title)
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
                    radioRow("表示モード", selection: $settings.displayMode) { mode in
                        Text(mode.title)
                    }

                    radioRow("文字サイズ", selection: $settings.fontScale) { scale in
                        Text(scale.title)
                    }

                    radioRow("外観モード", selection: $settings.appearanceMode) { mode in
                        Text(mode.title)
                    }
                }

                Section {
                    Button {
                        isEditingBirthDate = true
                    } label: {
                        AZAdaptiveControlRow {
                            Text("自分の生年月日")
                                .foregroundStyle(Color(.label))
                        } control: {
                            Text(birthDateText)
                                .font(.body.monospacedDigit())
                                .lineLimit(1)
                                .foregroundStyle(settings.birthDate == nil ? Color(.tertiaryLabel) : .secondary)
                        }
                    }

                    Toggle("メモは自分だけに表示する", isOn: $settings.showsMemoOnlyForSelf)
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
