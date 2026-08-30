//
//  NenrinUITests.swift
//  NenrinUITests
//
//  fastlane snapshot 用の UI テスト
//  3カットを撮影する:
//    01 主画面（年齢）1963年へ移動
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

        // 01: 主画面（年齢）1963年を移動先として表示
        snapshot("01YearList")

        // 02: 1963年9月1日生まれの自分一覧で当年を表示
        selectTab(app, id: "tab.personal", index: 1)
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

    /// タブを多段フォールバックで叩く（iPad では id 直接が hittable にならないことがある）
    @MainActor
    private func selectTab(_ app: XCUIApplication, id: String, index: Int) {
        let byId = app.buttons[id]
        if byId.exists && byId.isHittable {
            byId.tap(); sleep(1); return
        }
        let tabBtn = app.tabBars.firstMatch.buttons.element(boundBy: index)
        if tabBtn.exists && tabBtn.isHittable {
            tabBtn.tap(); sleep(1); return
        }
        let anyBtn = app.buttons.element(boundBy: index)
        if anyBtn.exists && anyBtn.isHittable {
            anyBtn.tap(); sleep(1)
        }
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
