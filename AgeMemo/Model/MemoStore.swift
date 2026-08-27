// 年ごとのメモをJSONへ自動保存する

import Foundation
import Observation

struct YearMemo: Codable, Equatable, Sendable {
    var text: String
    var updatedAt: Date
}

private struct MemoDocument: Codable {
    let version: Int
    var memos: [Int: YearMemo]
}

@MainActor
@Observable
final class MemoStore {
    private(set) var memos: [Int: YearMemo] = [:]
    private(set) var lastErrorMessage: String?

    private let fileURL: URL
    private var pendingSaveTask: Task<Void, Never>?
    private var hasUnsavedChanges = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    func text(for year: Int) -> String? {
        memos[year]?.text
    }

    func update(year: Int, text: String) {
        let limitedText = String(text.prefix(AppConfig.maximumMemoLength))
        if limitedText.isEmpty {
            memos.removeValue(forKey: year)
        } else {
            memos[year] = YearMemo(text: limitedText, updatedAt: .now)
        }
        hasUnsavedChanges = true
        scheduleSave()
    }

    func flushPendingSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        saveIfNeeded()
    }

    /// 各メモの前後の空白と改行を取り除き、空になったものは削除する
    private func trimAll() {
        for (year, memo) in memos {
            let trimmed = memo.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed != memo.text else { continue }
            if trimmed.isEmpty {
                memos.removeValue(forKey: year)
            } else {
                memos[year] = YearMemo(text: trimmed, updatedAt: memo.updatedAt)
            }
            hasUnsavedChanges = true
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
            let document = try decoder.decode(MemoDocument.self, from: data)
            guard document.version == 1 else {
                lastErrorMessage = "未対応のメモ形式です"
                return
            }
            memos = document.memos
        } catch {
            lastErrorMessage = "メモを読み込めませんでした"
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
            let data = try encoder.encode(MemoDocument(version: 1, memos: memos))
            try data.write(to: fileURL, options: .atomic)
            hasUnsavedChanges = false
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "メモを保存できませんでした"
        }
    }

    private static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("AgeMemo", isDirectory: true)
            .appendingPathComponent("memos.json", isDirectory: false)
    }
}
