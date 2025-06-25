# Slack Channel Exporter

Slackチャンネルのメッセージ履歴をCSV形式でエクスポートし、分析機能も提供するツールです。

## セットアップ

1. 依存関係のインストール
```bash
bundle install
```

2. 環境変数の設定
```bash
cp env.example .env
# .envファイルを編集してSLACK_BOT_TOKENを設定
```

3. Slack Appの作成とトークン取得
   - [Slack API](https://api.slack.com/apps)でアプリを作成
   - 必要なスコープを設定（下記参照）
   - Bot User OAuth Tokenを取得して.envに設定

## 使用方法

### 基本的な使用例

```bash
# チャンネル履歴を取得（過去30日間）
ruby slack_history_fetcher.rb -c C1234567890

# 期間を指定して取得
ruby slack_history_fetcher.rb -c C1234567890 -s 2024-01-01 -e 2024-01-31

# スレッド返信も含めて取得
ruby slack_history_fetcher.rb -c C1234567890 -t

# リアクション情報も含めて取得
ruby slack_history_fetcher.rb -c C1234567890 -r

# 全ての機能を使用
ruby slack_history_fetcher.rb -c C1234567890 -s 2024-01-01 -e 2024-01-31 -t -r

# ヘルプを表示
ruby slack_history_fetcher.rb --help
```

### 🧪 Slack API テスト・デモ

```bash
# 接続テスト（推奨：最初に実行）
ruby scripts/test_slack_connection.rb

# 特定チャンネルのテスト
ruby scripts/test_slack_connection.rb C1234567890

# インタラクティブAPIデモ
ruby scripts/demo_slack_api.rb --interactive

# 自動デモ実行
ruby scripts/demo_slack_api.rb
```

### オプション

- `-c, --channel CHANNEL_ID`: 必須。チャンネルID
- `-s, --start DATE`: 開始日（YYYY-MM-DD形式）。デフォルト：30日前
- `-e, --end DATE`: 終了日（YYYY-MM-DD形式）。デフォルト：今日
- `-o, --output FILE`: 出力ファイル名（未実装）
- `-t, --threads`: スレッド返信も取得する
- `-r, --reactions`: リアクション情報も取得する
- `-h, --help`: ヘルプを表示

## 機能

### フェーズ1（基本機能）
- [x] チャンネル履歴の取得
- [x] CSV形式での出力
- [x] 期間指定での取得
- [x] コマンドライン引数処理
- [x] レートリミット対応
- [x] エラーハンドリング

### フェーズ2（拡張機能）
- [x] ユーザー情報の取得
- [x] スレッド返信の取得

### フェーズ3（高度機能）
- [x] リアクション情報の取得
- [x] 性能最適化（レートリミット対応、エラーハンドリング）

## 必要なSlack権限

- `channels:history`: パブリックチャンネルの履歴
- `groups:history`: プライベートチャンネルの履歴
- `im:history`: ダイレクトメッセージの履歴
- `mpim:history`: マルチパーティDMの履歴
- `users:read`: ユーザー情報の読み取り
- `reactions:read`: リアクション情報の読み取り（オプション）

## 出力形式

CSVファイルには以下の列が含まれます：

- `message_ts`: Slackのタイムスタンプ
- `datetime`: 日時（YYYY-MM-DD HH:MM:SS形式）
- `user_id`: ユーザーID
- `user_name`: ユーザー名（実名またはユーザー名）
- `text`: メッセージ本文
- `thread_ts`: スレッドのタイムスタンプ（スレッド返信の場合）
- `message_type`: メッセージタイプ
- `reactions`: リアクション情報（emoji:count;emoji:count形式）

## 注意事項

- 2025年5月29日以降に作成されたSlackアプリは、`conversations.history`と`conversations.replies`のレート制限が厳しくなります（1分間に1リクエスト）
- 大量のデータを取得する場合は時間がかかる場合があります
- プライベートチャンネルにアクセスするには、アプリをそのチャンネルに招待する必要があります 