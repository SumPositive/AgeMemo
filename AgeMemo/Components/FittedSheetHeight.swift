// シートの高さを中身の実寸に合わせる

import SwiftUI

private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// シート本体の自然な高さを測ってdetentへ伝える。
    /// ScrollViewの内側など、シート高に引き伸ばされない位置に付けること
    func measuredSheetContent() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SheetContentHeightKey.self, value: proxy.size.height)
            }
        }
    }
}

private struct FittedSheetHeight: ViewModifier {
    /// ナビゲーションバーとドラッグハンドルのぶん
    private static let chromeHeight: CGFloat = 64

    /// 中身の自然な高さ。ScrollView内側で測るためシート高に引きずられず、
    /// 測定→detent変更→再測定のループも起きない
    @State private var contentHeight: CGFloat?

    /// シートに使える高さの上限。画面上端の余白ぶんを残す
    private var maximumSheetHeight: CGFloat {
        UIScreen.main.bounds.height * 0.92
    }

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(SheetContentHeightKey.self) { height in
                guard height > 0 else { return }
                contentHeight = height
            }
            // 実測前は .medium で表示し、確定後に中身ぴったりの高さへ切り替える。
            // 測るのは ScrollView の中身だけなので、ナビゲーションバーとハンドルの
            // 分を足さないと最後の要素が下端で切れる。
            //
            // ただし中身が画面より高いときは、その高さをそのまま要求すると
            // シートが画面に収まらず下端が欠ける（iPhone SE で発生）。
            // 画面に収まる上限で頭打ちにし、あふれるぶんはスクロールで見せる
            .presentationDetents(
                contentHeight.map { [.height(min($0 + Self.chromeHeight, maximumSheetHeight)), .large] }
                    ?? [.medium, .large]
            )
    }
}

extension View {
    /// 中身の高さに合わせた必要最小限のシート高さにする
    func fittedSheetHeight() -> some View {
        modifier(FittedSheetHeight())
    }
}
