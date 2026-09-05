// メモの持ち主を表す。自分のメモと名簿の各人のメモを別々に保存する

import Foundation

enum MemoOwner: Hashable, Sendable {
    /// 設定に登録した自分自身
    case myself
    /// 名簿に登録した人。誕生日と記念日のどちらもここに含む
    case person(UUID)
}
