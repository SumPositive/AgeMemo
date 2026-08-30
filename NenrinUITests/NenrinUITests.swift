//
//  NenrinUITests.swift
//  NenrinUITests
//
//  fastlane snapshot 用の UI テスト
//  3カットを撮影する:
//    01 主画面（年齢）補助表示なし
//    02 主画面（自分）補助表示あり
//    03 年詳細画面
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

        // 01: 主画面（年齢）補助表示なし
        // 起動時点で年齢一覧が選択済み。再タップすると年齢入力シートが開くため触らない
        snapshot("01YearList")

        // 02: 主画面（自分）補助表示あり
        selectTab(app, id: "tab.personal", index: 1)
        snapshot("02Personal")

        // 03: 年詳細。生年（1964）は賀寿・厄年・干支・カレンダーが揃う
        openYearDetail(app, year: 1964)
        snapshot("03YearDetail")
    }

    // MARK: - 補助

    /// iPad は余白が目立つので撮影時だけ文字サイズを上げる
    @MainActor
    private func extraLaunchArguments() -> [String] {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return [] }
        return ["-SNAPSHOT_FONT_SCALE", "xlarge"]
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

    /// 指定年の行を開く。画面外なら見えるまでスクロールする。
    /// SwiftUI の行がどの要素種別で公開されるかは環境で変わるため、
    /// otherElements / buttons / cells を順に探し、最後は画面中央のタップに落とす
    @MainActor
    private func openYearDetail(_ app: XCUIApplication, year: Int) {
        let identifier = "row.\(year)"
        let candidates = [app.otherElements[identifier], app.buttons[identifier], app.cells[identifier]]

        for _ in 0..<15 {
            if let hit = candidates.first(where: { $0.exists && $0.isHittable }) {
                hit.tap()
                sleep(2)
                return
            }
            app.swipeDown()
        }

        // 識別子で見つからなければ、一覧の中央あたりを直接叩いて詳細を開く
        let list = app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app
        list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)
    }
}
