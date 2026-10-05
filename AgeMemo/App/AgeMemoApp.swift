// アプリの依存関係と表示設定を組み立てる

import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct AgeMemoApp: App {
    @State private var settings = AppSettings.shared
    @State private var memoStore = MemoStore()
    @State private var personStore = PersonStore()
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    private var effectiveDynamicTypeSize: DynamicTypeSize {
        settings.fontScale.followsSystem ? systemDynamicTypeSize : settings.fontScale.dynamicTypeSize
    }

    init() {
        startAdMobIfAvailable()
    }

    /// 撮影用の状態づくり。DEBUG かつ -FASTLANE_SNAPSHOT のときだけ働く
    private func applySnapshotSetupIfNeeded() {
        #if DEBUG
        SnapshotSetup.applyIfNeeded(settings: settings, personStore: personStore, memoStore: memoStore)
        #endif
    }

    /// SDKを入れていないビルドでも通るようにしておく
    private func startAdMobIfAvailable() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            YearListView()
                // 画面内の日付表示も西暦を基準にする
                .environment(\.calendar, AppConfig.gregorianCalendar)
                .environment(settings)
                .environment(memoStore)
                .environment(personStore)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
                .dynamicTypeSize(effectiveDynamicTypeSize)
                .task { applySnapshotSetupIfNeeded() }
        }
    }
}
