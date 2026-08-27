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
