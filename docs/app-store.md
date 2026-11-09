# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.004 |
| アプリ名 | 段取りラン - 作り置きタイムアタック（ホーム画面は「段取りラン」。2026-11-09 に「段取り帖」から変更） |
| サポート URL | https://github.com/enludus-daily/app-20261106-batch-prep/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261106-batch-prep/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」（暴力・性的表現・ギャンブル・Web 閲覧・生成 AI・ユーザー生成コンテンツ・アルコールの描写なし。料理酒・みりんは材料名だけ）→ 4+ の見込み。本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：単純なタイマーではない。複数の品の工程を資源（手・コンロ・レンジ）で並べる計算（ルート）と、それを走るタイムアタック（スプリット・自己ベスト・ランク）、作った品の食べきりの記録を持つ。
- 既存のアプリとの意味のある違い：段取りを出すアプリ（Racook、ParaChef）は順番を出すだけ。段取りランはその順番を“走る”遊びにし、自己ベスト・ゴースト・ランクで縮める。作った品を食べきるとランが「完食」。
- 長く使える価値（4.2）：毎週変わる今週のお題、コースごとの自己ベスト、完食の連続。手で書いたレシピ 50 品と組み合わせ 8 つ。
- 他社の名前・商標・見た目を使っていないか：使っていない（「つくおき」などの書名・商標を名前やキーワードに入れていない）。レシピは一般的な家庭料理を自分で書いたもの。
- Apple Intelligence を使う場合、使えない端末での動き：使わない。
- 日持ちの表示：「めやす」と明記し、設定に「においや見た目がおかしいときは食べない」の注意を置く（健康の主張はしない）。

## 収益の道筋（本人が選ぶ）

- 決めたもの：買い切りの Pro ¥800（`com.enludus.daily.004.pro`、非消耗型、ファミリー共有。2026-11-09 に ¥480 から変更）。広告なし。
- 理由と勝算の表：README の「課金」（Paprika 4 Premium ¥2,500、MealPrepPro、Mealime、DELISH KITCHEN、レピモと比べ、月の売上の幅を出した）。核（段取りの計算・ラン・冷蔵庫）は無料。Paid Apps Agreement が有効かは本人が確認。

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ。購入は StoreKit で Apple が処理）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
