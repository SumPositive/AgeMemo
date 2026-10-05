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

    init(
        memos: MemoBackup,
        people: [Person],
        exportedAt: Date = .now,
        version: Int = Self.currentVersion
    ) {
        self.version = version
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

/// 読み込み前にバックアップ全体の対応形式と参照関係を確かめる
enum BackupValidator {
    static func validate(_ document: BackupDocument) throws {
        guard document.version == BackupDocument.currentVersion else {
            throw BackupError.unsupportedVersion
        }

        let personIDs = document.people.map(\.id)
        guard Set(personIDs).count == personIDs.count else { throw BackupError.decodeFailed }
        guard document.people.allSatisfy({ person in
            let name = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return !name.isEmpty && AppConfig.yearRange.contains(person.birthYear)
        }) else {
            throw BackupError.decodeFailed
        }

        let validPersonIDs = Set(personIDs)
        for (identifier, memos) in document.memos.people {
            guard let id = UUID(uuidString: identifier), validPersonIDs.contains(id) else {
                throw BackupError.decodeFailed
            }
            guard memos.keys.allSatisfy(AppConfig.yearRange.contains) else {
                throw BackupError.decodeFailed
            }
        }
        guard document.memos.myself.keys.allSatisfy(AppConfig.yearRange.contains) else {
            throw BackupError.decodeFailed
        }
    }
}

/// 書き出し・取り込みで起きた問題
enum BackupError: Error, Sendable, Hashable {
    case encodeFailed
    case exportFailed
    case importFailed
    case decodeFailed
    case unsupportedVersion
    case restoreFailed
    /// 復元に失敗したうえ、元の内容へも戻せなかった。
    /// 端末には取り込み途中の内容が残っている
    case rollbackFailed

    /// 利用者に見せる説明
    var message: LocalizedStringKey {
        switch self {
        case .encodeFailed: "書き出せませんでした"
        case .exportFailed: "ファイルへ書き出せませんでした"
        case .importFailed: "ファイルを選択できませんでした"
        case .decodeFailed: "このファイルは読み込めませんでした。書き出したファイルを選んでください"
        case .unsupportedVersion: "このバックアップ形式には対応していません"
        case .restoreFailed: "メモと名簿を復元できませんでした。データを確認してください"
        case .rollbackFailed: "復元に失敗し、元の内容へも戻せませんでした。端末の空き容量を確かめて、書き出したファイルから読み込み直してください"
        }
    }
}

/// ファイル選択のキャンセルと実際の失敗を区別する
enum BackupFileOperation {
    static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
}

/// 2つの保存先をまとめて置き換え、途中で失敗したら元へ戻す
@MainActor
enum BackupRestorer {
    static func apply(
        _ document: BackupDocument,
        memoStore: MemoStore,
        personStore: PersonStore
    ) throws {
        try BackupValidator.validate(document)
        // 名簿の置き換えで失敗したときにメモを戻すため、先に控えておく。
        // 名簿は最後に書くので、名簿側の以前の内容は要らない
        let previousMemos = memoStore.snapshot()

        // メモが先。ここで失敗したときはまだ何も書き換わっていないので、
        // 戻す操作は要らない
        do {
            try memoStore.replaceAll(with: document.memos)
        } catch {
            throw BackupError.restoreFailed
        }

        // 名簿で失敗すると、メモだけ置き換わった状態が残る。
        // メモを元へ戻し、それも失敗したときは取り込み途中の内容が
        // 端末に残るため、別のエラーとして知らせる
        do {
            try personStore.replaceAll(with: document.people)
        } catch {
            do {
                try memoStore.replaceAll(with: previousMemos)
            } catch {
                throw BackupError.rollbackFailed
            }
            throw BackupError.restoreFailed
        }
    }
}

/// 名簿とその人のメモを一体として削除する
@MainActor
enum PersonDeletionCoordinator {
    static func delete(
        id: UUID,
        memoStore: MemoStore,
        personStore: PersonStore
    ) throws {
        let previousMemos = memoStore.snapshot()
        let previousPeople = personStore.snapshot()
        var remainingMemos = previousMemos
        remainingMemos.people.removeValue(forKey: id.uuidString)
        let remainingPeople = previousPeople.filter { $0.id != id }

        // 先に名簿を消す。途中終了時にメモを失うより、孤立メモが残る方が安全
        do {
            try personStore.replaceAll(with: remainingPeople)
        } catch {
            throw PersonDeletionError.deleteFailed
        }

        do {
            try memoStore.replaceAll(with: remainingMemos)
        } catch {
            do {
                try personStore.replaceAll(with: previousPeople)
            } catch {
                throw PersonDeletionError.rollbackFailed
            }
            throw PersonDeletionError.deleteFailed
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
        // バックアップ名の年は端末の暦に関係なく西暦にする
        formatter.calendar = AppConfig.gregorianCalendar
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
