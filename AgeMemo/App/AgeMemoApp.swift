// アプリの依存関係と表示設定を組み立てる

import SwiftUI

@main
struct AgeMemoApp: App {
    @State private var settings = AppSettings.shared
    @State private var memoStore = MemoStore()
    @State private var personStore = PersonStore()
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    private var effectiveDynamicTypeSize: DynamicTypeSize {
        settings.fontScale.followsSystem ? systemDynamicTypeSize : settings.fontScale.dynamicTypeSize
    }

    var body: some Scene {
        WindowGroup {
            YearListView()
                .environment(settings)
                .environment(memoStore)
                .environment(personStore)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
                .dynamicTypeSize(effectiveDynamicTypeSize)
        }
    }
}
