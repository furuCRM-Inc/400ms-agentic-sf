# ⚡ 400msエージェントの応用ユースケース15選——Salesforceが「反射」で動く世界

> 前回の記事（VIP顧客の$50,000危機を400msで解決）を読んだ方から
> 「他にどんな場面で使えるの？」という質問をたくさんいただいた。
>
> 答えは：**あらゆる「判断→即実行」の場面で使える。**

Jev（System 1 AI）+ WebMCP（直接UI制御）の組み合わせは、
特定の業界・クラウドに限定されない。
「遅すぎる判断がビジネスを燃やしている」場所すべてが対象だ。

15のユースケースを業界別に整理した。

---

## 目次

1. [営業：失注寸前の商談を400msで救う](#1-営業失注寸前の商談を400msで救う)
2. [EC：不正注文を決済前に止める](#2-ec不正注文を決済前に止める)
3. [金融：小口融資を秒速で自動承認](#3-金融小口融資を秒速で自動承認)
4. [製造：部品在庫切れ→発注を自動完結](#4-製造部品在庫切れ発注を自動完結)
5. [フィールドサービス：緊急案件の即時ディスパッチ](#5-フィールドサービス緊急案件の即時ディスパッチ)
6. [マーケティング：カート離脱の瞬間引き留め](#6-マーケティングカート離脱の瞬間引き留め)
7. [コールセンター：感情爆発の自動エスカレーション](#7-コールセンター感情爆発の自動エスカレーション)
8. [HR：内定承認を稟議なしで完結](#8-hr内定承認を稟議なしで完結)
9. [医療：患者トリアージの即時優先度判定](#9-医療患者トリアージの即時優先度判定)
10. [法務：契約リスクの即時フラグと承認依頼](#10-法務契約リスクの即時フラグと承認依頼)
11. [サブスクリプション：解約意図の先読み引き留め](#11-サブスクリプション解約意図の先読み引き留め)
12. [物流：配送遅延の自動補償と通知](#12-物流配送遅延の自動補償と通知)
13. [不動産：内覧申し込みの即時マッチング](#13-不動産内覧申し込みの即時マッチング)
14. [教育：学習離脱の即時介入](#14-教育学習離脱の即時介入)
15. [ITOps：本番障害の自動トリアージと初動対応](#15-itops本番障害の自動トリアージと初動対応)

---

## 共通の仕組みを先に理解する

すべてのユースケースで同じパターンが動いている。

```
イベント発生（チャット/フォーム/センサー/ログ）
    ↓ 50ms
Jev が構造化判断を出力（テキスト生成なし）
    ↓ 50〜350ms
WebMCP が LWC ツールを直接呼び出し
（Salesforce Apex / Flow / External API）
    ↓ 400ms
✅ 完了
```

LWCが自分自身をAIツールとして登録する：

```javascript
// このパターンが全ユースケースで共通
document.modelContext.registerTool({
    name: "ツール名",
    description: "何をするツールか",
    execute: async (args) => ApexController.method(args)
});
```

では業界別に見ていく。

---

## 1. 営業：失注寸前の商談を400msで救う

**状況：** 商談金額¥3,000万の見込み客が、競合他社への乗り換えを示唆するメールを送ってきた。

### 🐌 従来（LLMエージェント）
```
メール受信
    ↓ 5秒  LLMがメール全文を読んで意図を判断
    ↓ 8秒  「どの営業担当に転送すべきか」を推論
    ↓ 12秒 CRM画面を開いて商談ステータスを検索
    ↓ 18秒 担当者にSlack通知を送信
    ↓ 25秒 ✅ 完了（競合に電話されていたかもしれない）
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "intent": "CHURN_RISK",
  "opportunity_stage": "Negotiation",
  "deal_value_jpy": 30000000,
  "action": "ESCALATE_TO_SALES_DIRECTOR",
  "discount_authority": "UP_TO_15_PERCENT",
  "urgency": "CRITICAL",
  "competitor_mentioned": "competitor_X"
}
```

```javascript
// WebMCP ツール群（LWC に登録済み）
"escalate_opportunity"       // 担当営業マネージャーに即エスカレーション
"apply_discount_offer"       // 承認枠内の割引を即座に適用
"schedule_executive_call"    // 役員レベルの架電を自動スケジュール
"log_competitor_intelligence" // 競合情報をCRMに記録
```

```
0ms   乗り換え示唆メール受信
50ms  Jev → ESCALATE_TO_SALES_DIRECTOR + 15%割引権限
200ms WebMCP → escalate_opportunity 実行（マネージャーにSMS）
300ms WebMCP → apply_discount_offer 実行（¥3,000万 → ¥2,550万）
400ms ✅ 完了
      → 顧客に「今すぐ専任担当から折り返します」メール自動送信済み
```

**ビジネスインパクト：** 競合への乗り換え前に先手を打てる確率が劇的に上がる。

---

## 2. EC：不正注文を決済前に止める

**状況：** 1分以内に同一IPから同じ商品を5回購入しようとしている。カード情報が毎回異なる。

### 🐌 従来
```
注文データがリスクチームのダッシュボードに蓄積
    ↓ 数分〜数時間 人間が確認
    ↓ 不正と判断してキャンセル処理
    ↓ すでに3件は決済通過・出荷指示済み
    → 損失発生
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "fraud_pattern": "VELOCITY_ABUSE",
  "risk_score": 0.96,
  "action": "BLOCK_AND_FLAG",
  "evidence": ["same_ip", "multiple_cards", "velocity_breach"],
  "auto_cancel_safe": true,
  "notify_team": "FRAUD_OPERATIONS"
}
```

```javascript
// WebMCP ツール群
"block_order"             // 注文をリアルタイムで停止
"flag_account"            // アカウントに不正フラグ
"notify_fraud_team"       // 不正オペチームにSlack通知
"request_identity_verify" // 本人確認プロセスをトリガー
```

```
0ms   5件目の注文リクエスト
50ms  Jev → BLOCK_AND_FLAG（リスクスコア 0.96）
180ms WebMCP → block_order 実行（全5件キャンセル）
300ms WebMCP → flag_account 実行
400ms ✅ 完了。不正チームに証拠ログ付きで通知済み
```

**ビジネスインパクト：** 決済処理前に遮断するため損失ゼロ。

---

## 3. 金融：小口融資を秒速で自動承認

**状況：** 中小企業オーナーが運転資金¥300万の融資をアプリから申請。

### 🐌 従来
```
申請受付
    ↓ 2〜3営業日 審査担当者がスコアリング
    ↓ 稟議書を作成・回覧
    ↓ 承認または否決の連絡
    → 申請者は他行に行く
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "applicant_crm_score": 742,
  "repayment_history": "EXCELLENT",
  "requested_amount_jpy": 3000000,
  "action": "AUTO_APPROVE",
  "interest_rate": 0.018,
  "repayment_months": 24,
  "approval_authority": "SYSTEM_TIER_1",
  "human_review_required": false
}
```

```javascript
// WebMCP ツール群
"approve_loan"            // 融資承認レコードを生成
"generate_loan_contract"  // 電子契約書を自動作成
"notify_applicant"        // 申請者にSMS・メールで通知
"trigger_disbursement"    // 翌営業日送金をスケジュール
```

```
0ms   融資申請受信
50ms  Jev → AUTO_APPROVE（スコア742、返済履歴EXCELLENT）
200ms WebMCP → approve_loan 実行
300ms WebMCP → generate_loan_contract 実行
400ms ✅ 完了
      「申請いただいた¥3,000万の融資が承認されました」SMS送信済み
```

**ビジネスインパクト：** 審査リードタイムが3日→0.4秒。競合との差別化が最大。

---

## 4. 製造：部品在庫切れ→発注を自動完結

**状況：** 自動車部品工場。センサーが「ボルトA-7の在庫が臨界値以下」を検知。このまま放置すると4時間後にラインが止まる。

### 🐌 従来
```
センサーアラート → ダッシュボードに表示
    ↓ 担当者が気づく（気づかない場合も）
    ↓ サプライヤーに電話・メール
    ↓ 見積もり待ち
    ↓ 発注処理
    → ラインが止まってから気づくケースも
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "part_id": "BOLT-A7",
  "current_stock": 47,
  "critical_threshold": 200,
  "production_halt_in_hours": 4,
  "action": "EMERGENCY_REORDER",
  "preferred_supplier": "supplier_tanaka",
  "quantity": 2000,
  "escalate_to_plant_manager": true
}
```

```javascript
// WebMCP ツール群
"create_purchase_order"      // 発注書を自動生成・送信
"notify_supplier"            // サプライヤーにAPIで発注
"alert_plant_manager"        // 工場長にモバイル通知
"log_inventory_incident"     // インシデント記録
```

```
0ms   在庫センサーがCritical検知
50ms  Jev → EMERGENCY_REORDER（4時間後ライン停止リスク）
150ms WebMCP → create_purchase_order 実行（2,000個発注書自動生成）
250ms WebMCP → notify_supplier 実行（サプライヤーAPIに発注）
350ms WebMCP → alert_plant_manager 実行
400ms ✅ 完了。工場長に「発注済み・入荷予定16時」通知済み
```

**ビジネスインパクト：** ライン停止1時間のコストが数百万円規模の工場で、ゼロダウンタイムを実現。

---

## 5. フィールドサービス：緊急案件の即時ディスパッチ

**状況：** 病院の空調システムが故障。手術室の温度が上昇中。緊急対応が必要。

### 🐌 従来
```
故障報告受付
    ↓ コールセンターが優先度を手入力
    ↓ ディスパッチャーが空き技術者を検索
    ↓ 電話で技術者に連絡・確認
    ↓ ルート案内を送信
    → 対応まで30分〜1時間
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "incident_type": "CRITICAL_HVAC_FAILURE",
  "site": "hospital_shinjuku",
  "affected_area": "surgical_ward",
  "risk_level": "LIFE_CRITICAL",
  "action": "IMMEDIATE_DISPATCH",
  "nearest_certified_technician": "tech_yamamoto",
  "eta_minutes": 12,
  "parts_needed": ["FILTER-HV22", "MOTOR-AC5"]
}
```

```javascript
// WebMCP ツール群
"dispatch_technician"        // 技術者アプリに緊急指示
"reserve_parts"              // 必要部品を倉庫から確保
"notify_facility_manager"    // 施設管理者に状況通知
"create_emergency_workorder" // 緊急作業指示書を自動生成
```

```
0ms   空調故障センサーアラート
50ms  Jev → IMMEDIATE_DISPATCH（LIFE_CRITICAL、ETA 12分）
150ms WebMCP → dispatch_technician 実行（山本技術者のスマホに指示）
250ms WebMCP → reserve_parts 実行（交換部品を倉庫から確保）
350ms WebMCP → notify_facility_manager 実行
400ms ✅ 完了。技術者は向かっている。病院管理者に到着予定通知済み
```

**ビジネスインパクト：** ライフクリティカルな設備障害の対応開始を30分→12分に短縮。

---

## 6. マーケティング：カート離脱の瞬間引き留め

**状況：** ¥150,000のカメラをカートに入れたユーザーが、チェックアウト画面で30秒以上止まっている。離脱しようとしている。

### 🐌 従来
```
離脱を検知
    ↓ 翌日、「カートに商品が残っています」メール
    ↓ （ユーザーはすでに他のECサイトで購入済み）
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "user_segment": "PHOTOGRAPHY_ENTHUSIAST",
  "cart_value_jpy": 150000,
  "hesitation_signal": "CHECKOUT_STALL_30S",
  "purchase_history": "3_CAMERAS_LAST_2YEARS",
  "action": "INSTANT_INCENTIVE",
  "offer": "FREE_SHIPPING_PLUS_LENS_CLEANER",
  "popup_message": "今だけ送料無料＋レンズクリーナーをプレゼント",
  "urgency_timer_minutes": 10
}
```

```javascript
// WebMCP ツール群（EC画面のLWCに登録）
"show_incentive_popup"    // チェックアウト画面にリアルタイムでポップアップ
"apply_offer"             // カートに特典を即座に追加
"start_countdown_timer"   // 「10分限定」タイマーを表示
"track_conversion"        // コンバージョンをMarketingCloudに記録
```

```
0ms   30秒停滞を検知（離脱シグナル）
50ms  Jev → INSTANT_INCENTIVE（送料無料＋レンズクリーナー）
200ms WebMCP → show_incentive_popup 実行（チェックアウト画面に即表示）
300ms WebMCP → apply_offer 実行（カートに特典追加）
400ms ✅ 完了。10分タイマー付きポップアップ表示中
```

**ビジネスインパクト：** メールリターゲティング（翌日）をリアルタイム介入に置き換え。カート離脱率を劇的に改善。

---

## 7. コールセンター：感情爆発の自動エスカレーション

**状況：** 通話中の顧客の声紋分析が「激怒レベル9.2/10」を検知。担当者が対応に行き詰まっている。

### 🐌 従来
```
担当者が「少々お待ちください」と保留
    ↓ スーパーバイザーを探す
    ↓ 状況を口頭で説明
    ↓ スーパーバイザーが通話に参加
    → 保留時間5〜10分。顧客の怒りがさらに増大
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "emotion_score": 9.2,
  "call_duration_minutes": 8,
  "issue_category": "BILLING_DISPUTE",
  "agent_stress_level": "HIGH",
  "action": "SILENT_SUPERVISOR_JOIN",
  "recommended_resolution": "FULL_CREDIT_THIS_MONTH",
  "script_suggestion": "共感→謝罪→即時解決の順番で",
  "authority_granted": "ONE_MONTH_CREDIT"
}
```

```javascript
// WebMCP ツール群（コールセンターLWCに登録）
"join_call_silently"       // スーパーバイザーが保留なしで通話参加
"push_agent_script"        // 担当者画面に対応スクリプトをリアルタイム表示
"pre_authorize_credit"     // 今月分クレジットを事前承認
"log_escalation"           // エスカレーション記録
```

```
0ms   声紋分析が激怒レベル9.2を検知
50ms  Jev → SILENT_SUPERVISOR_JOIN + 1ヶ月クレジット権限付与
150ms WebMCP → join_call_silently 実行（保留なしでSVが参加）
250ms WebMCP → push_agent_script 実行（担当者画面に対応手順表示）
350ms WebMCP → pre_authorize_credit 実行（クレジット事前承認）
400ms ✅ 完了。顧客は保留を一度も経験していない
```

**ビジネスインパクト：** 顧客が「待たされた」と感じる前に解決。エスカレーション後の満足度回復率が大幅向上。

---

## 8. HR：内定承認を稟議なしで完結

**状況：** 採用チームが優秀なエンジニア候補に内定を出したい。しかし週末で人事部長が不在。競合他社も同じ候補者にアプローチ中。

### 🐌 従来
```
内定稟議書を作成
    ↓ 月曜まで人事部長待ち
    ↓ 承認後、候補者に連絡
    → 候補者はすでに競合の内定を受諾していた
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "candidate_score": 94,
  "position": "Senior_SWE",
  "offer_within_budget": true,
  "competing_offers_detected": true,
  "action": "AUTO_APPROVE_WITHIN_BAND",
  "salary_jpy": 9500000,
  "approval_authority": "PRE_AUTHORIZED_BAND",
  "notify_vp_engineering": true,
  "urgency": "WEEKEND_CRITICAL"
}
```

```javascript
// WebMCP ツール群（採用管理LWCに登録）
"issue_offer_letter"       // 電子内定書を即時発行
"notify_candidate"         // 候補者にメール・SMS送信
"update_ats"               // 採用管理システムのステータス更新
"notify_vp"                // VPエンジニアリングに内定通知
```

```
0ms   採用担当者が「今すぐ内定出したい」を入力
50ms  Jev → AUTO_APPROVE（予算内・スコア94・競合あり）
150ms WebMCP → issue_offer_letter 実行（電子内定書生成）
250ms WebMCP → notify_candidate 実行（候補者にメール＋SMS）
400ms ✅ 完了。月曜を待たずに内定発行済み
```

**ビジネスインパクト：** 採用競争でのスピード勝負。優秀な人材の確保率が向上。

---

## 9. 医療：患者トリアージの即時優先度判定

**状況：** 救急外来に4人の患者が同時に到着。受付スタッフが手入力でトリアージを行っている。

### 🐌 従来
```
患者ごとに問診票を記入
    ↓ 看護師が優先度を目視判断
    ↓ 診察室への案内
    → 最大20分かかることも
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）— 4名同時処理
{
  "patients": [
    {"id": "P001", "priority": "IMMEDIATE", "suspected": "cardiac_event", "room": "ER-1"},
    {"id": "P002", "priority": "URGENT",    "suspected": "fracture",      "room": "ER-3"},
    {"id": "P003", "priority": "STANDARD",  "suspected": "laceration",    "room": "WAIT"},
    {"id": "P004", "priority": "STANDARD",  "suspected": "fever",         "room": "WAIT"}
  ],
  "action": "PARALLEL_TRIAGE"
}
```

```javascript
// WebMCP ツール群（ERシステムLWCに登録）
"assign_room"              // 診察室を即時アサイン
"alert_physician"          // 担当医にポケベル・スマホ通知
"prepare_equipment"        // 必要機材の準備指示
"notify_family"            // 付き添い家族に状況通知
```

```
0ms   4名の患者データ入力完了
50ms  Jev → 4名を並列トリアージ（P001: IMMEDIATE）
150ms WebMCP → P001をER-1に即アサイン、心臓専門医に緊急通知
250ms WebMCP → P002をER-3にアサイン
400ms ✅ 完了。全4名の処置開始指示が完了
```

**ビジネスインパクト：** 心疾患患者の処置開始を数分短縮。生存率への直接インパクト。

---

## 10. 法務：契約リスクの即時フラグと承認依頼

**状況：** 外部から届いた取引基本契約書（40ページ）。法務チームのレビューに通常5営業日かかる。

### 🐌 従来
```
契約書受領
    ↓ 法務チームのキュー入り（数日待ち）
    ↓ 弁護士が精読
    ↓ リスク条項のリストアップ
    ↓ 経営陣に報告・承認
    → 商談が止まる
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "document": "NDA_plus_MSA_40pages",
  "risk_flags": [
    {"clause": "12.3", "risk": "HIGH",   "issue": "無制限の損害賠償条項"},
    {"clause": "18.1", "risk": "MEDIUM", "issue": "データ保持期間が無期限"},
    {"clause": "22.4", "risk": "LOW",    "issue": "準拠法が相手国法"}
  ],
  "overall_risk": "MEDIUM_HIGH",
  "action": "ESCALATE_WITH_SUMMARY",
  "auto_redline_safe": true,
  "estimated_review_hours": 2
}
```

```javascript
// WebMCP ツール群（契約管理LWCに登録）
"create_risk_summary"      // リスクサマリーを自動生成（Salesforce上）
"request_legal_review"     // 法務チームにアサイン
"generate_redline"         // 問題条項の修正案を自動生成
"notify_deal_owner"        // 営業担当者に「審査中・2時間後完了予定」を通知
```

```
0ms   契約書アップロード
50ms  Jev → 3つのリスク条項を特定（MEDIUM_HIGH）
200ms WebMCP → create_risk_summary 実行（箇条書きサマリー自動生成）
300ms WebMCP → generate_redline 実行（修正案自動作成）
350ms WebMCP → notify_deal_owner 実行
400ms ✅ 完了。法務チームに「読むべき箇所リスト」付きでアサイン済み
```

**ビジネスインパクト：** 法務チームが全文精読する前に要点を把握。レビュー時間を5日→2時間に短縮。

---

## 11. サブスクリプション：解約意図の先読み引き留め

**状況：** SaaSユーザーが過去30日間ログイン0回。解約ページを開いた。

### ⚡ Jev の判断（50ms）

```json
{
  "user_activity_30d": 0,
  "plan": "ENTERPRISE",
  "mrr_jpy": 480000,
  "action": "PROACTIVE_SAVE",
  "offer": "3MONTHS_50PCT_DISCOUNT",
  "assign_csm": "csm_nakamura",
  "book_onboarding": true
}
```

```
0ms   解約ページ閲覧を検知
50ms  Jev → PROACTIVE_SAVE（MRR ¥48万、50%割引＋CSMアサイン）
200ms WebMCP → show_save_offer 実行（解約ページ上に直接オファー表示）
300ms WebMCP → assign_csm 実行（中村CSMにアラート）
400ms ✅ 解約ページを閉じる前にオファーを表示済み
```

**ビジネスインパクト：** 解約フォームを送信される前に介入。チャーン防止。

---

## 12. 物流：配送遅延の自動補償と通知

**状況：** 翌日配送のはずの荷物が天候不良で2日遅延確定。影響顧客1,200名。

### ⚡ Jev の判断（50ms）

```json
{
  "affected_orders": 1247,
  "delay_reason": "WEATHER",
  "original_delivery": "2026-09-20",
  "new_delivery": "2026-09-22",
  "compensation_tier": {
    "premium_members": "FULL_REFUND_SHIPPING",
    "standard_members": "NEXT_ORDER_500YEN_COUPON"
  },
  "action": "BATCH_NOTIFY_AND_COMPENSATE"
}
```

```
0ms   遅延確定データが入力
50ms  Jev → 1,247件を2セグメントに分類して補償額を決定
200ms WebMCP → 1,247件に一括メール/SMS送信（パーソナライズ済み）
350ms WebMCP → プレミアム会員456名の送料を自動返金
400ms ✅ 完了。クレーム発生前に全件通知・補償済み
```

**ビジネスインパクト：** 問い合わせ件数を劇的に削減。クレーム前の先手対応でNPS向上。

---

## 13. 不動産：内覧申し込みの即時マッチング

**状況：** 人気物件に内覧希望が殺到。スタッフが手動で調整している。

### ⚡ Jev の判断（50ms）

```json
{
  "property_id": "PROP-SHIBUYA-042",
  "inquiry_count_today": 23,
  "agent_availability": ["agent_sato", "agent_suzuki"],
  "action": "AUTO_SCHEDULE",
  "slots_assigned": 8,
  "waitlist_created": true,
  "auto_confirmation": true
}
```

```
0ms   23件目の内覧申し込み
50ms  Jev → 空き枠8件を自動割り当て、残15件をウェイトリストへ
200ms WebMCP → 8名に確認メール・カレンダー招待を自動送信
300ms WebMCP → 担当エージェントのカレンダーに自動ブロック
400ms ✅ 完了。スタッフの手作業ゼロ
```

---

## 14. 教育：学習離脱の即時介入

**状況：** オンライン学習プラットフォーム。受講生が同じ動画を3回巻き戻して視聴している。つまずいている。

### ⚡ Jev の判断（50ms）

```json
{
  "student_id": "STU-4421",
  "chapter": "微積分_第3章",
  "rewind_count": 3,
  "comprehension_signal": "STRUGGLING",
  "action": "ADAPTIVE_INTERVENTION",
  "offer": "SIMPLER_EXPLANATION_VIDEO",
  "assign_tutor": true,
  "tutor_message": "今この単元でつまずいている生徒がいます"
}
```

```
0ms   3回目の巻き戻しを検知
50ms  Jev → ADAPTIVE_INTERVENTION（別動画＋チューター通知）
200ms WebMCP → 補足動画を自動挿入（学習画面に表示）
300ms WebMCP → チューターにSlack通知
400ms ✅ 生徒は離脱せずに学習継続中
```

**ビジネスインパクト：** コース完了率の向上。月次チャーンの削減。

---

## 15. ITOps：本番障害の自動トリアージと初動対応

**状況：** 本番APIのエラーレートが0.1%→8.3%に急上昇。ユーザーへの影響が出始めている。

### 🐌 従来
```
アラート発報
    ↓ オンコールエンジニアがページされて起床
    ↓ ダッシュボードを確認して状況把握
    ↓ Slackでチームに状況共有
    ↓ 対応方針を決定
    → MTTD（平均検知時間）+ MTTR（平均復旧時間）= 長い
```

### ⚡ Jev + WebMCP（400ms）

```json
// Jev の判断（50ms）
{
  "service": "payment_api",
  "error_rate": 0.083,
  "error_pattern": "DB_CONNECTION_POOL_EXHAUSTED",
  "affected_endpoints": ["/checkout", "/refund"],
  "action": "AUTO_MITIGATE",
  "mitigation": "SCALE_CONNECTION_POOL",
  "escalate_to": ["oncall_engineer", "db_team"],
  "incident_severity": "SEV1",
  "rollback_candidate": "deploy_20260919_1423"
}
```

```javascript
// WebMCP ツール群（SRE ダッシュボード LWC に登録）
"scale_resource"           // 接続プールを即時スケールアップ
"create_incident"          // インシデントチケットを自動生成
"page_oncall"              // オンコールエンジニアに詳細付きページ
"notify_status_page"       // ステータスページに障害情報を自動掲載
"prepare_rollback"         // ロールバック手順書を自動生成
```

```
0ms   エラーレート8.3%を検知
50ms  Jev → DB接続プール枯渇と特定、AUTO_MITIGATE
150ms WebMCP → scale_resource 実行（接続プールを3倍に即時拡張）
250ms WebMCP → create_incident + page_oncall 実行（詳細ログ付き）
300ms WebMCP → notify_status_page 実行
400ms ✅ 緩和措置完了。オンコールが起きる前に自動対応済み
```

**ビジネスインパクト：** MTTRを「人が起きてSlackを開くまでの時間」から400msに短縮。SLA違反を防ぐ。

---

## まとめ：「反射」すべき場面の共通パターン

15のユースケースを通じて見えてくる共通点がある。

| 共通の条件 | 説明 |
|---|---|
| **時間的損失が明確** | 1秒の遅れが金銭・顧客・命に直結する |
| **判断の幅が定義できる** | ルール・予算・権限の範囲が事前に決まっている |
| **UIアクションが明確** | ボタン・フォーム・通知など実行すべき操作が具体的 |
| **LLMの「考え」が不要** | エッセイではなく判断結果だけが欲しい |

逆に言えば：

> **「判断結果が欲しいだけ」の場面でLLMを使うのは、
> 手紙を届けるためにトラック運転士を雇うようなものだ。**

Jevはオートバイ便。WebMCPは直通の受け取り口。
LLMは顧客との対話、メール生成、複雑な推論に残しておく。

---

## デモコード（GitHub）

すべてのユースケースの基盤となるパターンを実装済み。

→ **https://github.com/furuCRM-Inc/400ms-agentic-sf**

```bash
sf project deploy start --source-dir force-app --target-org <your-org>
```

Dev02環境で動作確認済み（テスト5/5 pass）。

---

あなたの業務の中で、「判断結果だけが欲しいのにLLMを待っている」場面はどれだけありますか？

`#Salesforce` `#Agentforce` `#LWC` `#WebMCP` `#AIエージェント` `#生成AI` `#DX` `#SRE` `#フィールドサービス` `#金融DX`
