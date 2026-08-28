// シートを閉じる操作の見た目を揃える

import SwiftUI

/// シートを下ろして閉じるボタン。
/// ドラッグで下へ払う操作と意味を合わせるため、下向きの山型を使う
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel("閉じる")
    }
}
