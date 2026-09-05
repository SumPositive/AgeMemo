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
    func removeAll(for owner: MemoOwner) {
        guard memos[owner] != nil else { return }
        memos.removeValue(forKey: owner)
        hasUnsavedChanges = true
        scheduleSave()
    }

    /// 書き出し用に、保存しているものと同じ形を渡す
    func snapshot() -> MemoBackup {
        var people: [String: [Int: YearMemo]] = [:]
        for (owner, ownerMemos) in memos {
            guard case .person(let id) = owner else { continue }
            people[id.uuidString] = ownerMemos
        }
        return MemoBackup(myself: memos[.myself] ?? [:], people: people)
    }

    /// 読み込んだ内容で全て置き換える。取り込みは上書きなので、
    /// 呼ぶ側が確認を取ってから使う
    func replaceAll(with backup: MemoBackup) {
        memos = [:]
        setMemos(backup.myself, for: .myself)
        for (identifier, ownerMemos) in backup.people {
            guard let id = UUID(uuidString: identifier) else { continue }
            setMemos(ownerMemos, for: .person(id))
        }
        hasUnsavedChanges = true
        flushPendingSave()
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
        for (owner, ownerMemos) in memos {
            var trimmedMemos = ownerMemos
            for (year, memo) in ownerMemos {
                let trimmed = memo.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed != memo.text else { continue }
                if trimmed.isEmpty {
                    trimmedMemos.removeValue(forKey: year)
                } else {
                    trimmedMemos[year] = YearMemo(text: trimmed, updatedAt: memo.updatedAt)
                }
                hasUnsavedChanges = true
            }
            guard trimmedMemos != ownerMemos else { continue }
            setMemos(trimmedMemos, for: owner)
        }
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

            // version を先に読み、1なら自分のメモとして取り込む
            let version = try decoder.decode(DocumentVersion.self, from: data).version
            switch version {
            case 1:
                let legacy = try decoder.decode(LegacyMemoDocument.self, from: data)
                setMemos(legacy.memos, for: .myself)
                // 次の保存で version 2 の形に書き換わる
                hasUnsavedChanges = true
            case 2:
                let document = try decoder.decode(MemoDocument.self, from: data)
                setMemos(document.myself, for: .myself)
                for (identifier, ownerMemos) in document.people {
                    guard let id = UUID(uuidString: identifier) else { continue }
                    setMemos(ownerMemos, for: .person(id))
                }
            default:
                lastError = .unsupportedFormat
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
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document())
            try data.write(to: fileURL, options: .atomic)
            hasUnsavedChanges = false
            lastError = nil
        } catch {
            lastError = .saveFailed
        }
    }

    private func document() -> MemoDocument {
        var people: [String: [Int: YearMemo]] = [:]
        for (owner, ownerMemos) in memos {
            guard case .person(let id) = owner else { continue }
            people[id.uuidString] = ownerMemos
        }
        return MemoDocument(version: 2, myself: memos[.myself] ?? [:], people: people)
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
