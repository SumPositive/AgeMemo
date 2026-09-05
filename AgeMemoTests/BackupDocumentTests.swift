// メモと名簿の書き出し・取り込みを検証する

import XCTest
@testable import AgeMemo

@MainActor
final class BackupDocumentTests: XCTestCase {
    private var memoURL: URL!
    private var personURL: URL!

    override func setUp() {
        super.setUp()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        memoURL = directory.appendingPathComponent("memos.json", isDirectory: false)
        personURL = directory.appendingPathComponent("people.json", isDirectory: false)
    }

    override func tearDown() {
        if let directory = memoURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: directory)
        }
        super.tearDown()
    }

    /// 書き出したファイルを読み込むと、メモと名簿が元どおりになる
    func testExportThenImportRestoresBothStores() throws {
        let birthDate = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(from: DateComponents(year: 1938, month: 3, day: 3))
        )
        let memoStore = MemoStore(fileURL: memoURL)
        let personStore = PersonStore(fileURL: personURL)
        personStore.add(name: "母", birthDate: birthDate, gender: .female)
        let personID = try XCTUnwrap(personStore.people.first?.id)
        memoStore.update(year: 1989, text: "平成に改元", owner: .myself)
        memoStore.update(year: 2026, text: "この人のメモ", owner: .person(personID))
        memoStore.flushPendingSave()

        let data = try BackupCoder.encode(
            BackupDocument(memos: memoStore.snapshot(), people: personStore.snapshot())
        )

        // 別の内容が入った状態から取り込んでも、ファイルの内容へ置き換わる
        let otherMemoStore = MemoStore(fileURL: memoURL)
        let otherPersonStore = PersonStore(fileURL: personURL)
        otherMemoStore.update(year: 2000, text: "消えるはずのメモ", owner: .myself)
        otherPersonStore.add(name: "消えるはずの人", birthDate: birthDate)

        let restored = try BackupCoder.decode(data)
        otherMemoStore.replaceAll(with: restored.memos)
        otherPersonStore.replaceAll(with: restored.people)

        XCTAssertEqual(otherMemoStore.text(for: 1989, owner: .myself), "平成に改元")
        XCTAssertEqual(otherMemoStore.text(for: 2026, owner: .person(personID)), "この人のメモ")
        XCTAssertNil(otherMemoStore.text(for: 2000, owner: .myself))
        XCTAssertEqual(otherPersonStore.people.count, 1)
        XCTAssertEqual(otherPersonStore.people.first?.name, "母")

        // 取り込んだ内容はファイルにも残り、次の起動でも読める
        XCTAssertEqual(MemoStore(fileURL: memoURL).text(for: 1989, owner: .myself), "平成に改元")
        XCTAssertEqual(PersonStore(fileURL: personURL).people.first?.name, "母")
    }

    /// 確認画面に見せる件数が、メモと名簿の実数と合う
    func testSummaryCountsMemosAndPeople() throws {
        let personID = UUID()
        let document = BackupDocument(
            memos: MemoBackup(
                myself: [1989: YearMemo(text: "自分", updatedAt: .now)],
                people: [personID.uuidString: [
                    2025: YearMemo(text: "1件目", updatedAt: .now),
                    2026: YearMemo(text: "2件目", updatedAt: .now),
                ]]
            ),
            people: []
        )
        XCTAssertEqual(document.summary.memoCount, 3)
        XCTAssertEqual(document.summary.personCount, 0)
    }

    /// 関係のないJSONを選んでも取り込まない
    func testDecodeRejectsUnrelatedJSON() {
        XCTAssertThrowsError(try BackupCoder.decode(Data(#"{"hello":1}"#.utf8)))
    }

    /// ファイル名は書き出した日時から作る
    func testFileNameUsesExportDate() throws {
        let date = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 2026, month: 9, day: 5, hour: 14, minute: 30)
            )
        )
        XCTAssertEqual(BackupCoder.fileName(for: date), "Nenrin-20260905-1430.json")
    }
}
