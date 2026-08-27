// 表示方法と生年月日を変更する設定画面

import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var minimumBirthDate: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: AppConfig.yearRange.lowerBound, month: 1, day: 1)) ?? .distantPast
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
                    if settings.birthDate == nil {
                        Button("生年月日を設定") {
                            settings.birthDate = .now
                        }
                    } else {
                        DatePicker(
                            "生年月日",
                            selection: Binding(
                                get: { settings.birthDate ?? .now },
                                set: { settings.birthDate = $0 }
                            ),
                            in: minimumBirthDate...Date.now,
                            displayedComponents: .date
                        )

                        Button("生年月日をクリア", role: .destructive) {
                            settings.birthDate = nil
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
        }
    }
}
