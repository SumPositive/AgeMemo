# App Store スクリーンショットの自動撮影・アップロード（Nenrin / 和暦年齢メモ）

`fastlane snapshot` でシミュレータからスクショを自動撮影し、`deliver` でアップロードします。
撮影は **ja / en-US × iPhone 17 Pro Max / iPad Pro 13-inch (M5)** の 3 カット。

---

## 撮影カット

UITest ターゲット `NenrinUITests` の `testTakeScreenshots` が撮ります。

| | 内容 |
|---|---|
| 01YearList | 主画面（年齢）1963年へ移動 |
| 02Personal | 1963年9月1日生まれの自分一覧で当年を表示 |
| 03YearDetail | 自分一覧の1963年詳細 |

撮影用の状態（生年月日・名簿・文字サイズ・補助表示）は、アプリ側の
`SnapshotSetup`（`#if DEBUG`）が起動引数 `-FASTLANE_SNAPSHOT` を見て用意します。
UI 操作でテンキー入力や設定トグルを叩かせると壊れやすいためです。

---

## コマンド

```bash
cd /Users/sumpositive/GitLocal/AgeMemo

fastlane screenshots            # 撮影のみ（fastlane/screenshots/ へ出力）
fastlane upload_screenshots     # 既存ファイルを ASC へ反映（撮影しない）
fastlane screenshots_and_upload # 撮影 → アップロード
```

実行前に `fastlane/.env` と `.p8` の配置が必要です（どちらもコミット禁止）。

---

## ハマりどころ

### 1. `xcode-select` が CommandLineTools を指していると動かない

```
Could not determine installed iOS SDK version.
```

`xcodebuild` が使えないためです。Xcode を指すよう切り替えます。

```bash
sudo xcode-select -s /Volumes/usb2G/Applications/Xcode26.6.app/Contents/Developer
xcodebuild -showsdks   # iOS SDK が並べば OK
```

### 2. 撮影中にアプリを再起動してはいけない

USB 上の Xcode + シミュレータでは、2回目の `launch()` がクローン起動になり
`RequestDenied` / `launch-failed` で**必ず**失敗します（体調メモでも同じ事象）。

```
RUN_DESTINATION_DEVICE_NAME = "Clone 2 of iPhone 17 Pro Max"
BSErrorCodeDescription = RequestDenied
```

UITest 内での `app.launch()` は 1 回だけにし、状態の切り替えはアプリ内の操作で行います。
`concurrent_simulators(false)` と `number_of_retries(3)` も同じ環境対策です。
`derived_data_path` の固定は使いません（体調メモで失敗を実証済み）。

### 3. アップロードすると画像が重複する（2026-09-01 実例）

**症状**：ASC 側で全削除してから `upload_screenshots` しても、各カットが 2 枚ずつ登録される。

**原因**：`overwrite_screenshots: true` は**実行の冒頭で既存を消すだけ**です。
その後、deliver は「アップロード → 数秒後に ASC 側へ反映されたか照合」を行いますが、
ASC の画像処理が非同期のため、照合時点でまだ API に現れないことがあります。
deliver はこれを失敗と判断し、**同一実行内でもう一度アップロード**します。
このリトライ分は冒頭の削除の対象外なので、二重に登録されます。

実際のログ:

```
[00:30:45〜49] Uploaded ...                      ← 12枚すべて成功
[00:30:56]     ... is missing on App Store Connect.   ← 12枚すべて「無い」と誤判定
[00:30:56]     Failed to upload all screenshots... Tries remaining: 4
[00:31:01〜05] Uploaded ...                      ← 11枚を再アップロード（＝重複）
```

`Previous uploaded. Skipping` が出た 1 枚だけは照合に間に合い、重複しませんでした。

**対処**：設定では防げません。

1. ASC でスクリーンショットを全削除する
2. **数分おいてから** `fastlane upload_screenshots` を実行する
3. 完了後に ASC で枚数を確認する（各言語 6 枚）

回線や ASC の混み具合で再発しうるため、**実行後の目視確認を習慣に**してください。
`deliver` に「全削除してからアップロード」に相当するオプションはありません
（ASC の API 側にその操作がないためで、fastlane の不具合ではありません）。

### 4. 撮影前に確認すること

- Snapfile の `devices([...])` は `xcrun simctl list devices` の名前と完全一致が必要
- 初回や不調時は 1 機種・1 言語に絞ると切り分けが早い
  （`fastlane snapshot --devices "iPhone 17 Pro Max" --languages ja`）
- シミュレータが不安定なときは
  `xcrun simctl shutdown all` + `sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService`
