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

    func add(name: String, birthDate: Date, gender: Gender = .unspecified, kind: PersonKind = .birthday) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 並び順は利用者が決めるため、追加は末尾へ置くだけにする
        people.append(
            Person(
                name: String(trimmed.prefix(AppConfig.maximumPersonNameLength)),
                birthDate: birthDate,
                gender: gender,
                kind: kind
            )
        )
        save()
    }

    func update(id: UUID, name: String, birthDate: Date, gender: Gender = .unspecified, kind: PersonKind = .birthday) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        people[index].name = String(trimmed.prefix(AppConfig.maximumPersonNameLength))
        people[index].birthDate = birthDate
        people[index].gender = gender
        people[index].kind = kind
        // 生年を変えても手で決めた並びは保つ
        save()
    }

    func delete(id: UUID) {
        people.removeAll { $0.id == id }
        save()
    }

    /// ドラッグで並べ替える
    func move(from source: IndexSet, to destination: Int) {
        people.move(fromOffsets: source, toOffset: destination)
        save()
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
            people = document.people
        } catch {
            lastError = .loadFailed
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(PersonDocument(version: 1, people: people))
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = .saveFailed
        }
    }

    private static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("AgeMemo", isDirectory: true)
            .appendingPathComponent("people.json", isDirectory: false)
    }
}
