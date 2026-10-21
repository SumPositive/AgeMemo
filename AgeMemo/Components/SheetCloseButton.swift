// シートを閉じる操作の見た目を揃える

import SwiftUI

/// シートを下ろして閉じるボタン。
/// ドラッグで下へ払う操作と意味を合わせるため、下向きの山型を使う
/// 置き場所は全シートで左上（`.cancellationAction`）にそろえる
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel("閉じる")
        // UIテストから言語に依存せず閉じられるようにする
        .accessibilityIdentifier("sheet.close")
    }
}
