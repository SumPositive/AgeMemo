// 名簿に登録した人の名前と生年月日を端末内へ保存する

import Foundation
import Observation
import SwiftUI

struct Person: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var birthDate: Date
    /// 厄年の判定に使う。既存データには無いので既定は未指定
    var gender: Gender
    /// 誕生日の人か、結婚記念日などの記念日か。既存データには無いので既定は誕生日
    var kind: PersonKind

    init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        gender: Gender = .unspecified,
        kind: PersonKind = .birthday
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, birthDate, gender, kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        birthDate = try container.decode(Date.self, forKey: .birthDate)
        // 性別・種別を持たない既存の名簿も読めるようにする
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender) ?? .unspecified
        kind = try container.decodeIfPresent(PersonKind.self, forKey: .kind) ?? .birthday
    }

    var birthYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: birthDate)
    }

    /// 生年月日の月と日。名簿シートの表示用
    var birthMonthDay: (month: Int, day: Int) {
        let components = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: birthDate)
        return (components.month ?? 1, components.day ?? 1)
    }
}

private struct PersonDocument: Codable {
    let version: Int
    var people: [Person]
}

@MainActor
@Observable
final class PersonStore {
    private(set) var people: [Person] = []
    private(set) var lastError: PersonStoreError?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    @discardableResult
    func add(name: String, birthDate: Date, gender: Gender = .unspecified, kind: PersonKind = .birthday) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // 並び順は利用者が決めるため、追加は末尾へ置くだけにする
        var replacement = people
        replacement.append(
            Person(
                name: String(trimmed.prefix(AppConfig.maximumPersonNameLength)),
                birthDate: birthDate,
                gender: gender,
                kind: kind
            )
        )
        return commit(replacement)
    }

    @discardableResult
    func update(id: UUID, name: String, birthDate: Date, gender: Gender = .unspecified, kind: PersonKind = .birthday) -> Bool {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var replacement = people
        replacement[index].name = String(trimmed.prefix(AppConfig.maximumPersonNameLength))
        replacement[index].birthDate = birthDate
        replacement[index].gender = gender
        replacement[index].kind = kind
        // 生年を変えても手で決めた並びは保つ
        return commit(replacement)
    }

    @discardableResult
    func delete(id: UUID) -> Bool {
        var replacement = people
        replacement.removeAll { $0.id == id }
        return commit(replacement)
    }

    /// ドラッグで並べ替える
    @discardableResult
    func move(from source: IndexSet, to destination: Int) -> Bool {
        var replacement = people
        replacement.move(fromOffsets: source, toOffset: destination)
        return commit(replacement)
    }

    /// 書き出し用に現在の名簿を渡す。
    /// 復元の巻き戻しが `replaceAll(with: snapshot())` を使うため、
    /// 読み込み側と同じ正規化を通して往復で変わらないようにする
    func snapshot() -> [Person] {
        Self.normalized(people)
    }

    /// 読み込んだ内容を保存できた場合だけ、現在の名簿と置き換える
    func replaceAll(with people: [Person]) throws {
        // 追加や編集と同じ形へそろえる。通さないと、前の版や手を加えた
        // ファイルから上限を超える名前がそのまま入り、あとで編集したときに
        // 黙って切り詰められる
        let normalized = Self.normalized(people)
        do {
            try write(normalized)
            self.people = normalized
            lastError = nil
        } catch {
            lastError = .saveFailed
            throw PersonStoreError.saveFailed
        }
    }

    /// 保存する形へそろえる。名前の前後の空白を落とし、上限の長さに収める。
    ///
    /// `snapshot()` が返す形もこれと同じなので、
    /// `replaceAll(with: snapshot())` は元へ戻す操作として使える
    static func normalized(_ people: [Person]) -> [Person] {
        var seenIDs: Set<UUID> = []
        return people.compactMap { person in
            var person = person
            person.name = String(
                person.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(AppConfig.maximumPersonNameLength)
            )
            // 空名・重複ID・表示範囲外の日付は一覧から正しく操作できないため除く
            guard !person.name.isEmpty,
                  AppConfig.yearRange.contains(person.birthYear),
                  seenIDs.insert(person.id).inserted
            else { return nil }
            return person
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(PersonDocument.self, from: data)
            guard document.version == 1 else {
                lastError = .unsupportedFormat
                return
            }
            let normalized = Self.normalized(document.people)
            people = normalized
            // 旧版や不整合データも次回から同じ形で読めるよう保存し直す
            if normalized != document.people {
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

    /// 保存できた場合だけ画面上の名簿を差し替える
    private func commit(_ replacement: [Person]) -> Bool {
        do {
            try write(replacement)
            people = replacement
            lastError = nil
            return true
        } catch {
            lastError = .saveFailed
            return false
        }
    }

    /// 指定された名簿を端末へ原子的に保存する
    private func write(_ people: [Person]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(PersonDocument(version: 1, people: people))
        try data.write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("AgeMemo", isDirectory: true)
            .appendingPathComponent("people.json", isDirectory: false)
    }
}
