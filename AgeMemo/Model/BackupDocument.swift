// メモと名簿を1つのJSONへまとめて書き出し、読み込む

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// メモの持ち主別の中身。保存ファイルと同じ形にしておき、
/// 取り込み後にそのまま MemoStore へ渡せるようにする
struct MemoBackup: Codable, Equatable, Sendable {
    var myself: [Int: YearMemo]
    var people: [String: [Int: YearMemo]]
}

/// 書き出すファイルの中身
struct BackupDocument: Codable, Equatable, Sendable {
    /// このファイル自体の形式。将来の変更に備えて持つ
    let version: Int
    /// 書き出した日時。取り込み前の確認に見せる
    let exportedAt: Date
    /// 書き出したアプリのバージョン。問い合わせの手掛かりにする
    let appVersion: String
    var memos: MemoBackup
    var people: [Person]

    static let currentVersion = 1

    init(memos: MemoBackup, people: [Person], exportedAt: Date = .now) {
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.appVersion = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        self.memos = memos
        self.people = people
    }

    /// 取り込んだ内容の規模。上書き前の確認に見せる
    var summary: (memoCount: Int, personCount: Int) {
        let memoCount = memos.myself.count + memos.people.values.reduce(0) { $0 + $1.count }
        return (memoCount, people.count)
    }
}

/// 書き出し・取り込みで起きた問題
enum BackupError: Sendable, Hashable {
    case encodeFailed
    case decodeFailed
    case unsupportedVersion

    /// 利用者に見せる説明
    var message: LocalizedStringKey {
        switch self {
        case .encodeFailed: "書き出せませんでした"
        case .decodeFailed: "このファイルは読み込めませんでした。書き出したファイルを選んでください"
        case .unsupportedVersion: "新しいバージョンのアプリで書き出したファイルです。アプリを更新してください"
        }
    }
}

enum BackupCoder {
    static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    static func decode(_ data: Data) throws -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupDocument.self, from: data)
    }

    /// 書き出すファイル名。同じ日に複数回書き出しても分かるよう時刻まで入れる
    static func fileName(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "Nenrin-\(formatter.string(from: date)).json"
    }
}

/// fileExporter へ渡すための入れ物
struct BackupFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
