# 和暦年齢メモ Nenrin

iOS 向けの和暦・年齢の早見表アプリです。SwiftUI で開発しています。

**App Store** — [和暦年齢メモ / Nenrin](https://apps.apple.com/jp/app/id6805710017)

**取扱説明 / User Guide**
[日本語](https://docs.azukid.com/jp/sumpo/Nenrin/nenrin.html) / [English](https://docs.azukid.com/en/sumpo/Nenrin/nenrin.html)

**設計書** — [DESIGN.md](DESIGN.md)

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)

---

## 概要

1600年（慶長5年）から2100年（令和82年）までの各年について、**西暦・和暦・干支・年齢**を1行にまとめた早見表アプリです。

「昭和47年生まれは今何歳か」「48歳の人は何年生まれか」「令和8年は西暦何年か」を、どの向きからでも同じ一覧で引けます。年ごとにメモを残せるため、家族の記録や出来事の覚え書きにも使えます。

設定により、干支・九星・入学卒業・長寿祝い・厄年を一覧に追加できます。

## 理念

**日本文化をそのまま提示する。**

このアプリが扱う和暦・干支・六曜・厄年は、日本文化そのものです。英訳すれば情報が失われます。「令和8年」を "Reiwa 8" と書き換えても、利用者が免許証や戸籍で実際に目にするのは「令和8年」の方です。

したがって**表示されるデータは日本語のまま**とし、外国人利用者には*翻訳*ではなく**日本語のまま読めるようになるための解説**を提供します（→ [多言語対応の方針](#多言語対応の方針)）。

**引く方向を選ばせない。**

年齢早見表は「年→年齢」と「年齢→年」の両方向で引かれます。どちらか一方に最適化せず、同じ一覧を両方向から引けるようにしています。下部タブは*絞り込み*ではなく*基準の切り替え*であり、一覧の行集合は常に全件（501年）です。

## 方針

### 設計

- Divigo（DialSplit）の構成を基本形とし、Packlin から「初心者/達人モード」「文字サイズ」「AdMob バナー」の考え方を引用しています
- SwiftData は使わず、メモと名簿は **JSON 1ファイル**に保存します
- 元号テーブルは自前で持たず、**OS の和暦カレンダー**（`Calendar(identifier: .japanese)`）に委ねます
- 干支・九星・六曜は表を持たず**計算で求めます**
- 主画面は常に全件（1600〜2100）を表示し、どの操作も行集合を変えません

### 実装の進め方

このアプリは**要件を文章で書き、詳細設計を生成させ、それをレビューして修正してから実装する**手順で作りました。設計を先に固めて人間がレビューするという工程は、ノーコードでもそのまま有効です。

**[DESIGN.md](DESIGN.md) を設計の正とします。** 実装を変えたら設計書も更新してください。設計書の冒頭には、当初案からの変更点を一覧にした改訂記録があります。

### 多言語対応の方針

**日本文化に属する表示は日本語のまま残し、操作の案内だけを en 対応します。**

判断基準は「**それは日本文化のデータか、アプリの操作案内か**」の一点です。

| 訳さない（ja 固定） | 訳す（ja / en） |
|---|---|
| 元号名（令和・昭和） | ボタン・タブ（設定→Settings、移動→Jump） |
| 干支の漢字とかな（丙午・ひのえうま） | ヘルプ文、エラー、確認ダイアログ |
| 賀寿（還暦・米寿）、厄年（前厄・大厄） | 設定項目の見出し（文字サイズ→Text Size） |
| 六曜（大安・仏滅）、九星（一白水星） | 空状態の案内、入力エラー |
| 年齢の数え方（満年齢・数え年） | |
| 単位（年・歳・月・日） | |

en では文化的な語に**かな＋ローマ字の読み**を併記します（`九星 一白水星（いっぱくすいせい / ippaku suisei）`）。

詳細は [DESIGN.md §13](DESIGN.md) を参照してください。

## 注意

### プロジェクト管理

- プロジェクト設定は Xcode と `AgeMemo.xcodeproj` で管理します
- XcodeGen の導入・実行は禁止します
- `AgeMemo.xcodeproj/project.pbxproj` をプロジェクト構成の唯一の正とします
- `AgeMemo/` 以下は **File System Synchronized Group** です。ファイルを追加しても project.pbxproj への登録は不要です

### ローカライズの落とし穴

**補間の書式指定子は「`String()` で包んだか」で決まります。** API（`Text` / `String(localized:)`）の違いではありません。

| 書き方 | カタログのキー |
|---|---|
| `\(intValue)` | `%lld` |
| `\(String(intValue))` | `%@` |

本アプリは桁区切りを出さないために `String()` で包む箇所が多く、両方が混在します。**キーが1文字でも違うとその訳は使われず、画面には日本語が出続けます。** 推測で書かず、`LocalizedStringKey("…")` を `print` して実際のキーを確認してください。

ビルド後にカタログを開き、`extractionState` が付いていないキー（＝どこからも参照されない死にキー）が無いか確認します。

### 一覧の列レイアウト

**行ごとに列位置と文字サイズを変えない。** これを崩すと一覧として目で追えなくなります。

- 基本3列（西暦・和暦・年齢）は**設定した文字サイズのまま**。狭くても縮めない
- 補助列（干支／九星、学齢／賀寿／厄年）は**常に縦積み・固定幅**。
  該当しない年でも幅を確保する
- `fixedSize` で中身に幅を決めさせると行ごとにずれるので使わない
- 列間と左右端はすべて可変 `Spacer`。余りを均等に配る

固定幅の基準は列に入りうる最長の語です（干支＋九星＝一白水星の4文字、
補助列＝**大還暦**の3文字）。学齢は「小1」、厄年は「前厄」で2文字ですが、
同じ列に賀寿が入るため3文字ぶん要ります。

### App Store 配信物（fastlane）

メタデータとスクリーンショットは `fastlane` で管理します。詳細は [DESIGN.md §12](DESIGN.md)。

```bash
fastlane preview_metadata   # 差分を確認して停止
fastlane upload_metadata    # 反映（審査提出はしない）
fastlane screenshots        # 3カット × 2言語 × 2機種
```

- 実行前に `.env`（API キー）と `.p8` の配置が必要です。**どちらもコミット禁止**
- **撮影中にアプリを再起動しないこと。** USB 上の Xcode ではクローン起動が
  拒否され、必ず失敗します。撮影用の状態は `SnapshotSetup` が起動引数で用意します
- `xcode-select` が CommandLineTools を指していると `xcodebuild` が動きません
- **アップロード後は ASC で枚数を目視確認してください。** 画像が二重登録されることがあります
  （原因と対処は [fastlane/README_screenshots.md](fastlane/README_screenshots.md)）

### 広告

- バナーは画面**上部**に配置します（Divigo はフッターですが本アプリは上部）
- **バナーの上下に十分な余白を取ります。** 誤タップによる配信停止を避けるための運用ルールです
- 非パーソナライズ広告固定（`npa=1`）。ATT ダイアログは出しません
- DEBUG はテストユニット、RELEASE は `NenrinBannerUnitID` を読みます

### シートとキーボード

生年月日入力シートは、名前欄のキーボードが出るとシート自体が動きます。これは `UISheetPresentationController` がキーボードに合わせてコンテナをリサイズする **UIKit 側の仕様**で、`presentationDetents` や `ignoresSafeArea(.keyboard)` では止められません。仕様として受け入れています。

### 数え年との対応

賀寿と厄年は本来**数え年**で数えます。表示中の年齢が満年齢のときは、数え年へ直してから判定してください。設定の「年齢の数え方」を変えると判定位置もずれます。

## 構成

```text
AgeMemo/
├── App/           — AppMain、AppSettings、Config
├── Core/          — JapaneseEra、Zodiac、AgeCalculator、
│                    Longevity、UnluckyYear、SchoolAge、NineStar、Rokuyo、MoonPhase
├── Model/         — YearRow、MemoStore、Person、Gender、StoreError
├── Components/    — AZPicker、NumericKeypad、BirthDateInput、BeginnerHelpBanner ほか
├── Features/
│   ├── Year/      — 主画面（一覧、行、詳細、カレンダー、下部タブ）
│   ├── Jump/      — 年齢／移動／名簿の各シート
│   ├── Settings/  — 設定画面
│   └── Ads/       — AdMobBanner
└── Resources/     — Assets、Info.plist、Localizable.xcstrings、InfoPlist.xcstrings
```

**主な依存関係**
- [Google Mobile Ads](https://github.com/googleads/swift-package-manager-google-mobile-ads) — AdMob バナー

## 必要環境

- iOS 17.0+
- Xcode 26+
- Swift 5（言語モード）

## リリース履歴

| バージョン | 公開日 | 内容 |
|---|---|---|
| 1.0.0 | 2026-09-03 | 初版 |

## ライセンス

本リポジトリのソースコードは参照目的で公開しています。
著作権は SumPositive に帰属します。
無断での複製、改変、再配布、商用利用を禁止します。
