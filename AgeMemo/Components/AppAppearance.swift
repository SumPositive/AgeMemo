// シートへ外観と文字サイズの設定を引き継ぐ

import SwiftUI

extension Color {
    /// ダークモードでは発光して見えないよう、移動操作の緑を落ち着かせる
    static let moveAction = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.42, blue: 0.20, alpha: 1)
            : UIColor.systemGreen
    })
}

private struct AppAppearance: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize
    let colorScheme: ColorScheme?

    private var effectiveDynamicTypeSize: DynamicTypeSize {
        settings.fontScale.followsSystem ? systemDynamicTypeSize : settings.fontScale.dynamicTypeSize
    }

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(colorScheme)
            .dynamicTypeSize(effectiveDynamicTypeSize)
            // 背後の一覧は数字が密なため、既定のブラーだと透けて読みにくい。
            // .background は環境によって半透明扱いになるため不透過色を明示する
            .presentationBackground(Color(.systemBackground))
    }
}

extension View {
    /// シートは別ウインドウ層に出るため、外観と文字サイズを明示的に引き継ぐ。
    ///
    /// `colorScheme` には呼び出し元（シートを出す側）で解決した配色を渡す。
    /// 「自動」を nil のまま渡すとシートには直前の明示値が残って追随しないため、
    /// 親画面の環境値（＝すでにシステム設定へ解決済み）で埋めておく必要がある
    func appAppearance(colorScheme: ColorScheme?) -> some View {
        modifier(AppAppearance(colorScheme: colorScheme))
    }
}
