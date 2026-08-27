// シートへ外観と文字サイズの設定を引き継ぐ

import SwiftUI

private struct AppAppearance: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    private var effectiveDynamicTypeSize: DynamicTypeSize {
        settings.fontScale.followsSystem ? systemDynamicTypeSize : settings.fontScale.dynamicTypeSize
    }

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(settings.appearanceMode.colorScheme)
            .dynamicTypeSize(effectiveDynamicTypeSize)
            // 背後の一覧は数字が密なため、既定のブラーだと透けて読みにくい。
            // .background は環境によって半透明扱いになるため不透過色を明示する
            .presentationBackground(Color(.systemBackground))
    }
}

extension View {
    /// シートは別ウインドウ層に出るため、外観と文字サイズを明示的に引き継ぐ
    func appAppearance() -> some View {
        modifier(AppAppearance())
    }
}
