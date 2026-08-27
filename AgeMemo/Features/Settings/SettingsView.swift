// 表示方法と生年月日を変更する設定画面

import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @State private var isEditingBirthDate = false

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var birthDateText: String {
        guard let birthDate = settings.birthDate else { return "未設定" }
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: birthDate)
        return String(format: "%04d/%02d/%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("表示") {
                    Picker("表示モード", selection: $settings.displayMode) {
                        ForEach(DisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("文字サイズ", selection: $settings.fontScale) {
                        ForEach(AppFontScale.allCases) { scale in
                            Text(scale.title).tag(scale)
                        }
                    }

                    Picker("外観モード", selection: $settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("メモは自分だけに表示する", isOn: $settings.showsMemoOnlyForSelf)
                }

                Section("生年月日") {
                    Button {
                        isEditingBirthDate = true
                    } label: {
                        HStack {
                            Text("生年月日")
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Text(birthDateText)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(settings.birthDate == nil ? Color(.tertiaryLabel) : .secondary)
                        }
                    }
                }

                Section("サポート") {
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
                    Button("完了") { dismiss() }
                }
            }
            .sheet(isPresented: $isEditingBirthDate) {
                // シートは別ウインドウ層に出るため外観設定を明示的に引き継ぐ
                BirthDateInputSheet(title: "生年月日", birthDate: settings.birthDate) { newValue in
                    settings.birthDate = newValue
                }
                .preferredColorScheme(settings.appearanceMode.colorScheme)
            }
        }
    }
}
