// 保存・読み込みの失敗を表す。文言は表示側で組み立てる

import SwiftUI

/// メモの保存・読み込みで起きた問題
enum MemoStoreError: Sendable, Hashable {
    case unsupportedFormat
    case loadFailed
    case saveFailed

    /// 利用者に見せる説明。操作の案内にあたるため訳す
    var message: LocalizedStringKey {
        switch self {
        case .unsupportedFormat: "未対応のメモ形式です"
        case .loadFailed: "メモを読み込めませんでした"
        case .saveFailed: "メモを保存できませんでした"
        }
    }
}

/// 名簿の保存・読み込みで起きた問題
enum PersonStoreError: Sendable, Hashable {
    case unsupportedFormat
    case loadFailed
    case saveFailed

    var message: LocalizedStringKey {
        switch self {
        case .unsupportedFormat: "未対応の名簿データ形式です"
        case .loadFailed: "名簿を読み込めませんでした"
        case .saveFailed: "名簿を保存できませんでした"
        }
    }
}
