//
//  NenrinUITests.swift
//  NenrinUITests
//
//  fastlane snapshot 用の UI テスト
//  3カットを撮影する:
//    01 主画面（年齢）2026年へ移動
//    02 主画面（自分）当年を表示
//    03 自分一覧の1963年詳細
//
//  【重要】アプリの起動は1回だけにする
//  自分一覧の補助表示は撮影モードでタブを選んだ時にアプリ側で有効にする
//
//  生年月日・名簿・メモは アプリ側の SnapshotSetup が -FASTLANE_SNAPSHOT を見て用意する。
//  テンキー入力を UI 操作で行うと壊れやすいため。
//

import XCTest

final class NenrinUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTakeScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += extraLaunchArguments()
        app.launch()

        waitForList(app)

        // 01: 主画面（年齢）2026年を移動先として表示
        waitForYear(app, year: 2026)
        snapshot("01YearList")

        // 02: 1963年9月1日生まれの自分一覧で当年を表示
        selectTab(app, id: "tab.personal", index: 1, expectedMode: "personal")
        snapshot("02Personal")

        // 03: 自分一覧の1963年詳細を開く
        open1963Detail(app)
        snapshot("03YearDetail")
    }

    // MARK: - 補助

    /// 全端末の撮影文字サイズを設定の「大」に揃える
    @MainActor
    private func extraLaunchArguments() -> [String] {
        ["-SNAPSHOT_FONT_SCALE", "large"]
    }

    /// 一覧が描画されるまで待つ
    @MainActor
    private func waitForList(_ app: XCUIApplication) {
        _ = app.buttons["tab.age"].waitForExistence(timeout: 30)
        sleep(2)   // 当年へのスクロールと一覧レイアウトの確定を待つ
    }

    /// 指定年の行が画面へ現れてから撮影する
    @MainActor
    private func waitForYear(_ app: XCUIApplication, year: Int) {
        let row = app.descendants(matching: .any)["row.\(year)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(year)年の行が表示されない")
        XCTAssertTrue(row.isHittable, "\(year)年の行が画面内にない")
    }

    /// タブを多段フォールバックで叩き、選択状態への切り替わりまで確認する
    @MainActor
    private func selectTab(_ app: XCUIApplication, id: String, index: Int, expectedMode: String) {
        let byId = app.buttons[id]
        if byId.exists && byId.isHittable {
            byId.tap()
        } else {
            let tabButton = app.tabBars.firstMatch.buttons.element(boundBy: index)
            if tabButton.exists && tabButton.isHittable {
                tabButton.tap()
            } else if byId.exists {
                // iPadでhittableにならない場合も識別子を持つ要素の中央を直接タップする
                byId.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                XCTFail("タブ\(id)が見つからない")
                return
            }
        }

        let selected = NSPredicate(format: "isSelected == true")
        let expectation = XCTNSPredicateExpectation(predicate: selected, object: byId)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed, "タブ\(id)へ切り替わらない")

        // タブの選択表示だけでなく一覧の計算基準まで切り替わったことを確認する
        let modeMarker = app.buttons["snapshot.open1963Detail"]
        XCTAssertTrue(modeMarker.waitForExistence(timeout: 10), "一覧基準の検証値が見つからない")
        let modeChanged = NSPredicate(format: "value == %@", expectedMode)
        let modeExpectation = XCTNSPredicateExpectation(predicate: modeChanged, object: modeMarker)
        XCTAssertEqual(
            XCTWaiter.wait(for: [modeExpectation], timeout: 10),
            .completed,
            "一覧基準が\(expectedMode)へ切り替わらない"
        )
    }

    /// スワイプ位置に依存せず撮影専用操作から1963年詳細を開く
    @MainActor
    private func open1963Detail(_ app: XCUIApplication) {
        let button = app.buttons["snapshot.open1963Detail"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "1963年詳細の撮影用操作が見つからない")
        XCTAssertTrue(button.isHittable, "1963年詳細の撮影用操作をタップできない")
        button.tap()
        let yearHeading = app.staticTexts["detail.year.1963"]
        XCTAssertTrue(yearHeading.waitForExistence(timeout: 10), "1963年詳細シートが開かない")
        sleep(2)
    }
}
