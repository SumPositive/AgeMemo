// 保存・読み込みの失敗を表す。文言は表示側で組み立てる

import SwiftUI

/// メモの保存・読み込みで起きた問題
enum MemoStoreError: Error, Sendable, Hashable {
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
enum PersonStoreError: Error, Sendable, Hashable {
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

/// 名簿とその人のメモをまとめて削除するときの問題
enum PersonDeletionError: Error, Sendable, Hashable {
    case deleteFailed
    case rollbackFailed

    var message: LocalizedStringKey {
        switch self {
        case .deleteFailed: "削除できませんでした。端末の空き容量を確認してください"
        case .rollbackFailed: "削除に失敗し、元の内容へも戻せませんでした。書き出したファイルから読み込み直してください"
        }
    }
}
