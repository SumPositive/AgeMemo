// シートの高さを中身の実寸に合わせる

import SwiftUI

private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FittedSheetHeight: ViewModifier {
    /// 実測した高さ。detentを与えると測定値がそれに追従してしまうため、
    /// 一度確定したら更新せず、測定→detent変更→再測定のループを断ち切る
    @State private var contentHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SheetContentHeightKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(SheetContentHeightKey.self) { height in
                guard height > 0, contentHeight == nil else { return }
                contentHeight = height
            }
            // 実測前は .medium で表示し、確定後に中身ぴったりの高さへ切り替える。
            // .large も併せて許可し、ハンドルで引き上げられるようにする
            .presentationDetents(contentHeight.map { [.height($0), .large] } ?? [.medium, .large])
    }
}

extension View {
    /// 中身の高さに合わせた必要最小限のシート高さにする
    func fittedSheetHeight() -> some View {
        modifier(FittedSheetHeight())
    }
}
