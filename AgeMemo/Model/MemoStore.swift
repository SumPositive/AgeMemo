// 持ち主ごとに、年ごとのメモをJSONへ自動保存する

import Foundation
import Observation

struct YearMemo: Codable, Equatable, Sendable {
    var text: String
    var updatedAt: Date
}

/// version 1。メモは自分のぶんしか無く、年をそのままキーにしていた
private struct LegacyMemoDocument: Codable {
    let version: Int
    var memos: [Int: YearMemo]
}

/// version 2。自分と名簿の各人を分けて持つ。人はUUIDの文字列で引く
private struct MemoDocument: Codable {
    let version: Int
    var myself: [Int: YearMemo]
    var people: [String: [Int: YearMemo]]
}

@MainActor
@Observable
final class MemoStore {
    private(set) var lastError: MemoStoreError?

    /// 持ち主ごとのメモ。空になった持ち主はキーごと捨てる
    private(set) var memos: [MemoOwner: [Int: YearMemo]] = [:]

    private let fileURL: URL
    private var pendingSaveTask: Task<Void, Never>?
    private var hasUnsavedChanges = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    func text(for year: Int, owner: MemoOwner) -> String? {
        memos[owner]?[year]?.text
    }

    /// その持ち主がメモを1件でも持っているか。人を消すときの確認に使う
    func hasMemos(for owner: MemoOwner) -> Bool {
        !(memos[owner]?.isEmpty ?? true)
    }

    func update(year: Int, text: String, owner: MemoOwner) {
        let limitedText = String(text.prefix(AppConfig.maximumMemoLength))
        var ownerMemos = memos[owner] ?? [:]
        if limitedText.isEmpty {
            ownerMemos.removeValue(forKey: year)
        } else {
            ownerMemos[year] = YearMemo(text: limitedText, updatedAt: .now)
        }
        setMemos(ownerMemos, for: owner)
        hasUnsavedChanges = true
        scheduleSave()
    }

    /// 名簿から人を消したときに、その人のメモも道連れにする
    @discardableResult
    func removeAll(for owner: MemoOwner) -> Bool {
        guard memos[owner] != nil else { return true }
        var replacement = memos
        replacement.removeValue(forKey: owner)
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        do {
            // 削除は保存成功後に画面へ反映し、失敗時の内容を失わない
            try write(replacement)
            memos = replacement
            hasUnsavedChanges = false
            lastError = nil
            return true
        } catch {
            lastError = .saveFailed
            if hasUnsavedChanges {
                scheduleSave()
            }
            return false
        }
    }

    /// 書き出し用に、保存しているものと同じ形を渡す。
    ///
    /// ここも正規化を通すので `replaceAll(with: snapshot())` は
    /// 元の状態へ戻す操作になる。復元の巻き戻しがこれに依存している
    func snapshot() -> MemoBackup {
        let source = Self.normalized(memos)
        var people: [String: [Int: YearMemo]] = [:]
        for (owner, ownerMemos) in source {
            guard case .person(let id) = owner else { continue }
            people[id.uuidString] = ownerMemos
        }
        return MemoBackup(myself: source[.myself] ?? [:], people: people)
    }

    /// 読み込んだ内容を保存できた場合だけ、現在のメモと置き換える
    func replaceAll(with backup: MemoBackup) throws {
        var replacement: [MemoOwner: [Int: YearMemo]] = [:]
        replacement[.myself] = backup.myself
        for (identifier, ownerMemos) in backup.people {
            guard let id = UUID(uuidString: identifier) else { continue }
            replacement[.person(id)] = ownerMemos
        }
        // 読み込んだメモも保存前と同じ形にそろえる。
        // 通さないと空白付きのメモや空のメモがそのまま残り、
        // 手で入力したメモと扱いが変わってしまう
        replacement = Self.normalized(replacement)

        // 保存できたときだけ差し替えるので、待機中の保存は先に止める
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        do {
            try write(replacement)
            memos = replacement
            hasUnsavedChanges = false
            lastError = nil
        } catch {
            lastError = .saveFailed
            // メモリ上の内容は差し替えていないが、待機中だった保存を
            // 止めたままにすると未保存の変更が二度と書き出されない。
            // 書き出しが必要なら改めて予約しておく
            if hasUnsavedChanges {
                scheduleSave()
            }
            throw MemoStoreError.saveFailed
        }
    }

    func flushPendingSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        saveIfNeeded()
    }

    /// 空になった持ち主を残すと、書き出すたびに空の辞書が増えていく
    private func setMemos(_ ownerMemos: [Int: YearMemo], for owner: MemoOwner) {
        if ownerMemos.isEmpty {
            memos.removeValue(forKey: owner)
        } else {
            memos[owner] = ownerMemos
        }
    }

    /// 各メモの前後の空白と改行を取り除き、空になったものは削除する
    private func trimAll() {
        let normalized = Self.normalized(memos)
        guard normalized != memos else { return }
        memos = normalized
        hasUnsavedChanges = true
    }

    /// 保存する形へそろえる。前後の空白を落とし、空になったメモと
    /// 空になった持ち主を取り除く。
    ///
    /// 保存前の整形（trimAll）と読み込み（replaceAll）の両方がこれを通る。
    /// 片方だけ通すと、読み込んだメモに空白が残って `hasMemos(for:)` の
    /// 判定や一覧の表示が保存経路と食い違う。
    /// `snapshot()` が返す形もこの形なので、`replaceAll(snapshot())` は
    /// 元に戻す操作として使える
    static func normalized(
        _ source: [MemoOwner: [Int: YearMemo]]
    ) -> [MemoOwner: [Int: YearMemo]] {
        var result: [MemoOwner: [Int: YearMemo]] = [:]
        for (owner, ownerMemos) in source {
            var trimmedMemos: [Int: YearMemo] = [:]
            for (year, memo) in ownerMemos {
                // 前の版は上限が長かったため、読み込んだメモが今の上限を
                // 超えていることがある。入力時と同じ長さへそろえておかないと、
                // あとで編集したときに黙って切り詰められる
                let normalizedText = String(
                    memo.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        .prefix(AppConfig.maximumMemoLength)
                )
                guard !normalizedText.isEmpty else { continue }
                trimmedMemos[year] = normalizedText == memo.text
                    ? memo
                    : YearMemo(text: normalizedText, updatedAt: memo.updatedAt)
            }
            guard !trimmedMemos.isEmpty else { continue }
            result[owner] = trimmedMemos
        }
        return result
    }

    private func scheduleSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: AppConfig.memoSaveDelayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.pendingSaveTask = nil
            self?.saveIfNeeded()
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // version を先に読み、各形式を現在の持ち主別データへ変換する
            let version = try decoder.decode(DocumentVersion.self, from: data).version
            var loaded: [MemoOwner: [Int: YearMemo]] = [:]
            var needsRewrite = false
            switch version {
            case 1:
                let legacy = try decoder.decode(LegacyMemoDocument.self, from: data)
                loaded[.myself] = legacy.memos
                needsRewrite = true
            case 2:
                let document = try decoder.decode(MemoDocument.self, from: data)
                loaded[.myself] = document.myself
                for (identifier, ownerMemos) in document.people {
                    guard let id = UUID(uuidString: identifier) else {
                        needsRewrite = true
                        continue
                    }
                    loaded[.person(id)] = ownerMemos
                }
            default:
                lastError = .unsupportedFormat
                return
            }

            let normalized = Self.normalized(loaded)
            memos = normalized
            // 旧形式や現在の入力制限と異なる内容は読み込み時に整える
            if needsRewrite || normalized != loaded {
                do {
                    try write(normalized)
                } catch {
                    lastError = .saveFailed
                }
            }
        } catch {
            lastError = .loadFailed
        }
    }

    private func saveIfNeeded() {
        guard hasUnsavedChanges else { return }
        // 入力中のtrimは打鍵の邪魔になるため、書き出す直前に整形する
        trimAll()
        do {
            try write(memos)
            hasUnsavedChanges = false
            lastError = nil
        } catch {
            lastError = .saveFailed
        }
    }

    /// 指定された内容を端末へ原子的に保存する
    private func write(_ source: [MemoOwner: [Int: YearMemo]]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document(from: source))
        try data.write(to: fileURL, options: .atomic)
    }

    /// 保存用の持ち主別辞書をJSON形式へ組み立てる
    private func document(from source: [MemoOwner: [Int: YearMemo]]) -> MemoDocument {
        var people: [String: [Int: YearMemo]] = [:]
        for (owner, ownerMemos) in source {
            guard case .person(let id) = owner else { continue }
            people[id.uuidString] = ownerMemos
        }
        return MemoDocument(version: 2, myself: source[.myself] ?? [:], people: people)
    }

    private static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("AgeMemo", isDirectory: true)
            .appendingPathComponent("memos.json", isDirectory: false)
    }
}

/// 形が変わっても version だけは読めるようにする
private struct DocumentVersion: Codable {
    let version: Int
}
