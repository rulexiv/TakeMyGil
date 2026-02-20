# TakeMyGil

![TakeMyGil](https://preview.redd.it/man-i-am-hyped-v0-g7nvqbcomv4b1.jpg?width=640&crop=smart&auto=webp&s=d4cfc30f101e7cb92325ac189c37a9f1f0956655)

FFXIVMinion 用の「送金/受取補助」アドオンです。  
Version: `2.1.0`

## これは何をするアドオン？
- プレイヤー間トレードでのギル送金を自動化します
- 1回あたり `1,000,000 gil` ずつ安全に分割して送ります
- 送金中の証跡用にスクリーンショットを自動撮影します
- 受け取り側としての自動承認（RECV）も使えます

## 3分クイックスタート（初めての人向け）
1. `TakeMyGil` フォルダを `LuaMods` に置く  
   `C:\MINIONAPP\Bots\FFXIVMinion64\LuaMods\`
2. Minion で `Reload Lua` を実行
3. 右下のミニ `SEND` ボタンを押して画面を開く
4. 相手をターゲットして送金額を入力
5. `SHUT UP AND TAKE MY GIL` を押して開始

## 基本操作

### SEND（送金）
1. 送金相手をターゲットします
2. 金額を入力します（`+1M` / `+10M` / `+100M` / `ALL` も可）
3. `SHUT UP AND TAKE MY GIL` を押すと送金開始
4. 進捗バーと `Start / Current / Sent` で状況確認
5. 同じボタンを押すと停止（手動停止）

### RECV（受取）
1. 右下のミニ `RECV` で ON/OFF
2. ON中はトレード確認系ダイアログを自動処理
3. 画面上部に `RECV ON. SEND LOCKED.` と表示中は SEND は開始不可

## スクリーンショット仕様（送金証跡）
- 送金開始前: 1回目トレード直前に1枚
- 送金完了後: 全トレード完了時に1枚
- 中間撮影: 想定トレード回数が11回以上のとき、10回ごとに1枚
- 手動停止時: 完了前の停止なら1枚

## スクショ結合バッチ（任意）
このバッチは **TakeMyGil 本体（Minion機能）とは別の補助ツール** です。  
「撮ったスクショを証跡として1枚にまとめたい」場合だけ使ってください。

### 何ができる？
- スクショ保存フォルダ内の画像を自動で選んで1枚に縦結合
- 結合後の画像を `merge` フォルダへ保存
- 元画像を `archive` フォルダへ移動して、保存フォルダ直下を整理

### 事前準備
1. `merge_screenshots.bat`
2. `merge_screenshots.ps1`

この2ファイルを、**FFXIVのスクショが保存されるフォルダ**に置きます。  
例: `%USERPROFILE%\Documents\My Games\FINAL FANTASY XIV - A Realm Reborn\screenshots`

### 使い方
1. TakeMyGilで送金し、スクショを撮影する
2. スクショ保存フォルダを開く
3. `merge_screenshots.bat` をダブルクリックして実行
4. 完了後、以下を確認
   - `merge\merged_yyyyMMdd_HHmmss.jpg`（結合済み画像）
   - `archive\`（元スクショ）

### バッチの動作ルール
- 対象ファイル: 実行フォルダ直下の `.png/.jpg/.jpeg/.bmp`
- 選定枚数: 最大4枚
- 選び方: 先頭1枚 + 末尾1枚 + 等間隔の中間2枚
- `merge` / `archive` フォルダが無ければ自動作成
