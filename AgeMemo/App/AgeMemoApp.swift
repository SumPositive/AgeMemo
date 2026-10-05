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

    /// 撮影用の状態づくり。DEBUG かつ -FASTLANE_SNAPSHOT のときだけ働く
    private func applySnapshotSetupIfNeeded() {
        #if DEBUG
        SnapshotSetup.applyIfNeeded(settings: settings, personStore: personStore, memoStore: memoStore)
        #endif
    }

    /// SDKを入れていないビルドでも通るようにしておく。
    /// 初期化とバナー用 WebView の起動はメインスレッドをふさぐため、
    /// init で呼ぶと最初の画面が出るまで空白が続く。一覧を描いた後に始める
    private func startAdMobIfAvailable() async {
        #if canImport(GoogleMobileAds)
        await MobileAds.shared.start()
        // 初期化が済んでからバナーを作らせる
        AdReadyState.shared.markReady()
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
                .task {
                    applySnapshotSetupIfNeeded()
                    // 一覧の最初の描画を先に済ませてから広告の準備に入る
                    await Task.yield()
                    await startAdMobIfAvailable()
                }
        }
    }
}
