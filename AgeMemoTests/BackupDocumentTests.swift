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
        try otherMemoStore.replaceAll(with: restored.memos)
        try otherPersonStore.replaceAll(with: restored.people)

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

    /// 現在と異なるバックアップ形式は新旧を問わず拒否する
    func testValidatorRejectsUnsupportedVersions() {
        for version in [0, BackupDocument.currentVersion + 1] {
            let document = BackupDocument(
                memos: MemoBackup(myself: [:], people: [:]),
                people: [],
                version: version
            )
            XCTAssertThrowsError(try BackupValidator.validate(document)) { error in
                XCTAssertEqual(error as? BackupError, .unsupportedVersion)
            }
        }
    }

    /// 空名・重複ID・名簿にない人のメモは読み込み前に拒否する
    func testValidatorRejectsInvalidRosterRelationships() throws {
        let date = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1963, month: 9, day: 1))
        )
        let duplicateID = UUID()
        let invalidDocuments = [
            BackupDocument(
                memos: MemoBackup(myself: [:], people: [:]),
                people: [Person(name: "   ", birthDate: date)]
            ),
            BackupDocument(
                memos: MemoBackup(myself: [:], people: [:]),
                people: [
                    Person(id: duplicateID, name: "一人目", birthDate: date),
                    Person(id: duplicateID, name: "二人目", birthDate: date),
                ]
            ),
            BackupDocument(
                memos: MemoBackup(
                    myself: [:],
                    people: [UUID().uuidString: [2026: YearMemo(text: "孤立", updatedAt: .now)]]
                ),
                people: []
            ),
            BackupDocument(
                memos: MemoBackup(
                    myself: [AppConfig.yearRange.lowerBound - 1: YearMemo(text: "範囲外", updatedAt: .now)],
                    people: [:]
                ),
                people: []
            ),
        ]

        for document in invalidDocuments {
            XCTAssertThrowsError(try BackupValidator.validate(document)) { error in
                XCTAssertEqual(error as? BackupError, .decodeFailed)
            }
        }
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

    /// メモの保存に失敗した場合は、画面上の内容も置き換えない
    func testMemoReplacementFailureKeepsCurrentData() throws {
        let store = MemoStore(fileURL: memoURL)
        store.update(year: 2026, text: "現在のメモ", owner: .myself)
        store.flushPendingSave()
        try FileManager.default.removeItem(at: memoURL)
        try FileManager.default.createDirectory(at: memoURL, withIntermediateDirectories: true)

        let replacement = MemoBackup(
            myself: [2027: YearMemo(text: "読み込み対象", updatedAt: .now)],
            people: [:]
        )
        XCTAssertThrowsError(try store.replaceAll(with: replacement))
        XCTAssertEqual(store.text(for: 2026, owner: .myself), "現在のメモ")
        XCTAssertNil(store.text(for: 2027, owner: .myself))
    }

    /// 名簿の保存に失敗した場合は、画面上の内容も置き換えない
    func testPersonReplacementFailureKeepsCurrentData() throws {
        let birthDate = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1963, month: 9, day: 1))
        )
        let store = PersonStore(fileURL: personURL)
        store.add(name: "現在の人", birthDate: birthDate)
        try FileManager.default.removeItem(at: personURL)
        try FileManager.default.createDirectory(at: personURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try store.replaceAll(with: [Person(name: "読み込み対象", birthDate: birthDate)])
        )
        XCTAssertEqual(store.people.first?.name, "現在の人")
    }

    /// 名簿の復元に失敗した場合は、先に置き換えたメモも元へ戻す
    func testRestoreRollsBackMemoWhenPersonSaveFails() throws {
        let birthDate = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1963, month: 9, day: 1))
        )
        let memoStore = MemoStore(fileURL: memoURL)
        let personStore = PersonStore(fileURL: personURL)
        memoStore.update(year: 2026, text: "以前のメモ", owner: .myself)
        memoStore.flushPendingSave()
        personStore.add(name: "以前の人", birthDate: birthDate)
        try FileManager.default.removeItem(at: personURL)
        try FileManager.default.createDirectory(at: personURL, withIntermediateDirectories: true)

        let document = BackupDocument(
            memos: MemoBackup(
                myself: [2027: YearMemo(text: "新しいメモ", updatedAt: .now)],
                people: [:]
            ),
            people: [Person(name: "新しい人", birthDate: birthDate)]
        )
        XCTAssertThrowsError(
            try BackupRestorer.apply(document, memoStore: memoStore, personStore: personStore)
        )
        XCTAssertEqual(memoStore.text(for: 2026, owner: .myself), "以前のメモ")
        XCTAssertNil(memoStore.text(for: 2027, owner: .myself))
        XCTAssertEqual(personStore.people.first?.name, "以前の人")
    }

    /// メモ削除に失敗した場合は先に削除した名簿を元へ戻す
    func testPersonDeletionRollsBackPersonWhenMemoSaveFails() throws {
        let birthDate = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1963, month: 9, day: 1))
        )
        let memoStore = MemoStore(fileURL: memoURL)
        let personStore = PersonStore(fileURL: personURL)
        XCTAssertTrue(personStore.add(name: "残す人", birthDate: birthDate))
        let personID = try XCTUnwrap(personStore.people.first?.id)
        memoStore.update(year: 2026, text: "残すメモ", owner: .person(personID))
        memoStore.flushPendingSave()
        try FileManager.default.removeItem(at: memoURL)
        try FileManager.default.createDirectory(at: memoURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try PersonDeletionCoordinator.delete(
                id: personID,
                memoStore: memoStore,
                personStore: personStore
            )
        ) { error in
            XCTAssertEqual(error as? PersonDeletionError, .deleteFailed)
        }
        XCTAssertEqual(personStore.people.first?.id, personID)
        XCTAssertEqual(memoStore.text(for: 2026, owner: .person(personID)), "残すメモ")
        XCTAssertEqual(PersonStore(fileURL: personURL).people.first?.id, personID)
    }

    /// 名簿を削除すると、その人だけのメモも同時に保存先から消える
    func testPersonDeletionRemovesPersonAndOwnedMemos() throws {
        let birthDate = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1963, month: 9, day: 1))
        )
        let memoStore = MemoStore(fileURL: memoURL)
        let personStore = PersonStore(fileURL: personURL)
        XCTAssertTrue(personStore.add(name: "削除する人", birthDate: birthDate))
        let personID = try XCTUnwrap(personStore.people.first?.id)
        memoStore.update(year: 2026, text: "削除するメモ", owner: .person(personID))
        memoStore.update(year: 2026, text: "残すメモ", owner: .myself)
        memoStore.flushPendingSave()

        try PersonDeletionCoordinator.delete(
            id: personID,
            memoStore: memoStore,
            personStore: personStore
        )

        XCTAssertTrue(PersonStore(fileURL: personURL).people.isEmpty)
        let loadedMemos = MemoStore(fileURL: memoURL)
        XCTAssertNil(loadedMemos.text(for: 2026, owner: .person(personID)))
        XCTAssertEqual(loadedMemos.text(for: 2026, owner: .myself), "残すメモ")
    }

    /// ファイル操作では利用者のキャンセルだけを通常の失敗と区別する
    func testFileCancellationDetection() {
        let cancellation = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        let failure = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        XCTAssertTrue(BackupFileOperation.isCancellation(cancellation))
        XCTAssertFalse(BackupFileOperation.isCancellation(failure))
    }
}
