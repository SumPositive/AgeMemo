// メモの文字数制限・削除・JSON保存を検証する

import XCTest
@testable import AgeMemo

@MainActor
final class MemoStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("memos.json", isDirectory: false)
    }

    override func tearDown() {
        if let directory = fileURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: directory)
        }
        super.tearDown()
    }

    func testRoundTripAndDelete() {
        let store = MemoStore(fileURL: fileURL)
        store.update(year: 2026, text: "テスト", owner: .myself)
        store.flushPendingSave()

        let loaded = MemoStore(fileURL: fileURL)
        XCTAssertEqual(loaded.text(for: 2026, owner: .myself), "テスト")

        loaded.update(year: 2026, text: "", owner: .myself)
        loaded.flushPendingSave()
        XCTAssertNil(MemoStore(fileURL: fileURL).text(for: 2026, owner: .myself))
    }

    func testMaximumLength() {
        let store = MemoStore(fileURL: fileURL)
        store.update(year: 2026, text: String(repeating: "あ", count: AppConfig.maximumMemoLength + 1), owner: .myself)
        XCTAssertEqual(store.text(for: 2026, owner: .myself)?.count, AppConfig.maximumMemoLength)
    }

    /// 同じ年でも持ち主が違えば別のメモとして保存される
    func testMemosAreSeparatePerOwner() {
        let first = UUID()
        let second = UUID()
        let store = MemoStore(fileURL: fileURL)
        store.update(year: 2026, text: "自分のメモ", owner: .myself)
        store.update(year: 2026, text: "1人目のメモ", owner: .person(first))
        store.update(year: 2026, text: "2人目のメモ", owner: .person(second))
        store.flushPendingSave()

        let loaded = MemoStore(fileURL: fileURL)
        XCTAssertEqual(loaded.text(for: 2026, owner: .myself), "自分のメモ")
        XCTAssertEqual(loaded.text(for: 2026, owner: .person(first)), "1人目のメモ")
        XCTAssertEqual(loaded.text(for: 2026, owner: .person(second)), "2人目のメモ")
    }

    /// 名簿から人を消しても、他の持ち主のメモは残る
    func testRemoveAllForOwner() {
        let personID = UUID()
        let store = MemoStore(fileURL: fileURL)
        store.update(year: 2026, text: "自分のメモ", owner: .myself)
        store.update(year: 2026, text: "この人のメモ", owner: .person(personID))
        XCTAssertTrue(store.hasMemos(for: .person(personID)))

        store.removeAll(for: .person(personID))
        store.flushPendingSave()
        XCTAssertFalse(store.hasMemos(for: .person(personID)))

        let loaded = MemoStore(fileURL: fileURL)
        XCTAssertNil(loaded.text(for: 2026, owner: .person(personID)))
        XCTAssertEqual(loaded.text(for: 2026, owner: .myself), "自分のメモ")
    }

    /// 1.0.0形式（持ち主の区別がない）のメモは自分のメモとして読み込む
    func testLegacyDocumentMigratesToMyself() throws {
        let legacy = """
        {
          "version": 1,
          "memos": { "1989": { "text": "平成に改元", "updatedAt": "2026-09-05T00:00:00Z" } }
        }
        """
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(legacy.utf8).write(to: fileURL, options: .atomic)

        let store = MemoStore(fileURL: fileURL)
        XCTAssertEqual(store.text(for: 1989, owner: .myself), "平成に改元")

        // 書き戻すと version 2 の形になり、次回以降もそのまま読める
        store.flushPendingSave()
        let reloaded = MemoStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.text(for: 1989, owner: .myself), "平成に改元")
        XCTAssertNil(reloaded.lastError)
    }
}

@MainActor
final class PersonStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("people.json", isDirectory: false)
    }

    override func tearDown() {
        if let directory = fileURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: directory)
        }
        super.tearDown()
    }

    func testRoundTripUpdateAndDeleteByID() throws {
        let calendar = Calendar(identifier: .gregorian)
        let firstDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 1963, month: 9, day: 1)))
        let updatedDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 1964, month: 10, day: 2)))
        let store = PersonStore(fileURL: fileURL)

        store.add(name: "本人", birthDate: firstDate, gender: .male)
        let personID = try XCTUnwrap(store.people.first?.id)
        store.update(id: personID, name: "更新後", birthDate: updatedDate, gender: .female)

        // 再読込後も同じIDへ編集内容が保存されることを確認する
        let loaded = PersonStore(fileURL: fileURL)
        XCTAssertEqual(loaded.people.first?.id, personID)
        XCTAssertEqual(loaded.people.first?.name, "更新後")
        XCTAssertEqual(loaded.people.first?.birthDate, updatedDate)
        XCTAssertEqual(loaded.people.first?.gender, .female)

        loaded.delete(id: personID)
        XCTAssertTrue(PersonStore(fileURL: fileURL).people.isEmpty)
    }

    /// 記念日の種別が保存後の再読込でも維持される
    func testAnniversaryKindRoundTrip() throws {
        let date = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1995, month: 3, day: 2))
        )
        let store = PersonStore(fileURL: fileURL)
        store.add(name: "創立記念日", birthDate: date, kind: .anniversary)

        let loaded = PersonStore(fileURL: fileURL)
        XCTAssertEqual(loaded.people.first?.kind, .anniversary)
        XCTAssertEqual(loaded.people.first?.birthDate, date)
    }

    /// 1.0.0形式のkindがない名簿は誕生日として読み込む
    func testLegacyDocumentWithoutKindDefaultsToBirthday() throws {
        let date = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1963, month: 9, day: 1))
        )
        let store = PersonStore(fileURL: fileURL)
        store.add(name: "本人", birthDate: date, gender: .male)

        let savedData = try Data(contentsOf: fileURL)
        var document = try XCTUnwrap(
            JSONSerialization.jsonObject(with: savedData) as? [String: Any]
        )
        var people = try XCTUnwrap(document["people"] as? [[String: Any]])
        people[0].removeValue(forKey: "kind")
        document["people"] = people
        try JSONSerialization.data(withJSONObject: document).write(to: fileURL, options: .atomic)

        let loaded = PersonStore(fileURL: fileURL)
        XCTAssertEqual(loaded.people.first?.kind, .birthday)
        XCTAssertEqual(loaded.people.first?.gender, .male)
    }
}
