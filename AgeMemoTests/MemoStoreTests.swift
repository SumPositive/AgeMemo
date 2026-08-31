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
        store.update(year: 2026, text: "テスト")
        store.flushPendingSave()

        let loaded = MemoStore(fileURL: fileURL)
        XCTAssertEqual(loaded.text(for: 2026), "テスト")

        loaded.update(year: 2026, text: "")
        loaded.flushPendingSave()
        XCTAssertNil(MemoStore(fileURL: fileURL).text(for: 2026))
    }

    func testMaximumLength() {
        let store = MemoStore(fileURL: fileURL)
        store.update(year: 2026, text: String(repeating: "あ", count: 401))
        XCTAssertEqual(store.text(for: 2026)?.count, AppConfig.maximumMemoLength)
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
}
