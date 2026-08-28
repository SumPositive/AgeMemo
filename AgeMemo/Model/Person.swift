// 名簿に登録した人の名前と生年月日を端末内へ保存する

import Foundation
import Observation
import SwiftUI

struct Person: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var birthDate: Date

    init(id: UUID = UUID(), name: String, birthDate: Date) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
    }

    var birthYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: birthDate)
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
    private(set) var lastErrorMessage: String?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    func add(name: String, birthDate: Date) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 並び順は利用者が決めるため、追加は末尾へ置くだけにする
        people.append(Person(name: String(trimmed.prefix(AppConfig.maximumPersonNameLength)), birthDate: birthDate))
        save()
    }

    func update(id: UUID, name: String, birthDate: Date) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        people[index].name = String(trimmed.prefix(AppConfig.maximumPersonNameLength))
        people[index].birthDate = birthDate
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
                lastErrorMessage = "未対応の名簿データ形式です"
                return
            }
            people = document.people
        } catch {
            lastErrorMessage = "名簿を読み込めませんでした"
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
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "名簿を保存できませんでした"
        }
    }

    private static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("AgeMemo", isDirectory: true)
            .appendingPathComponent("people.json", isDirectory: false)
    }
}
