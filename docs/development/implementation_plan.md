# Slackチャンネル履歴取得ツール 実装計画書

## 1\. 実装概要

### 1.1 開発方針

- **段階的実装**: Must → Should → Could の順で機能を実装  
- **アジャイル開発**: 各フェーズで動作確認を行い、段階的にリリース  
- **品質重視**: 各フェーズでテストとレビューを実施

### 1.2 開発期間

- **全体期間**: 約10営業日  
- **フェーズ1（Must要件）**: 6営業日  
- **フェーズ2（Should要件）**: 2営業日  
- **フェーズ3（Could要件）**: 2営業日

## 2\. フェーズ別実装計画

### 2.1 フェーズ1: 基本機能実装（Must要件）

#### 2.1.1 開発環境セットアップ（0.5日）

**タスク:**

- [ ] プロジェクトディレクトリ作成  
- [ ] Gemfile作成と依存関係定義  
- [ ] .gitignore設定  
- [ ] .env.example作成

**成果物:**

```
slack_history_fetcher/
├── Gemfile
├── .env.example
├── .gitignore
└── README.md
```

**技術詳細:**

```
# Gemfile
source 'https://rubygems.org'

ruby '3.0.0'

gem 'slack-ruby-client', '~> 2.0'
gem 'dotenv', '~> 2.8'
gem 'csv'
```

#### 2.1.2 基本クラス構造実装（1日）

**タスク:**

- [ ] SlackHistoryFetcher クラスの骨格作成  
- [ ] コマンドライン引数解析機能  
- [ ] 環境変数読み込み機能  
- [ ] 基本的なエラーハンドリング

**実装内容:**

```
class SlackHistoryFetcher
  def initialize
    @token = load_token
    @client = Slack::Web::Client.new(token: @token)
  end

  def run(options)
    # メイン処理
  end

  private

  def load_token
    # 環境変数からトークン読み込み
  end

  def parse_arguments(args)
    # コマンドライン引数解析
  end
end
```

#### 2.1.3 Slack API連携機能（1.5日）

**タスク:**

- [ ] conversations.history API呼び出し  
- [ ] ページネーション対応  
- [ ] API認証テスト  
- [ ] レートリミット基本対応

**実装ポイント:**

- API呼び出し間に1秒の待機時間  
- cursor を使用したページネーション  
- エラーレスポンスの適切な処理

```
def fetch_messages(channel_id, start_date, end_date)
  messages = []
  cursor = nil
  
  loop do
    response = @client.conversations_history(
      channel: channel_id,
      oldest: start_date.to_time.to_i,
      latest: end_date.to_time.to_i,
      cursor: cursor,
      limit: 100
    )
    
    messages.concat(response.messages)
    cursor = response.response_metadata&.next_cursor
    break unless cursor
    
    sleep(1) # レートリミット対応
  end
  
  messages
end
```

#### 2.1.4 CSV出力機能（1日）

**タスク:**

- [ ] CSV形式でのデータ出力  
- [ ] UTF-8エンコーディング対応  
- [ ] ファイル命名規則実装  
- [ ] 基本的なデータ変換

**実装内容:**

```
def export_to_csv(messages, output_file)
  CSV.open(output_file, 'w', encoding: 'UTF-8') do |csv|
    csv << ['message_ts', 'datetime', 'user_id', 'text', 'thread_ts']
    
    messages.each do |message|
      csv << [
        message.ts,
        convert_timestamp(message.ts),
        message.user,
        message.text,
        message.thread_ts || ''
      ]
    end
  end
end
```

#### 2.1.5 統合テストとデバッグ（1日）

**タスク:**

- [ ] 実際のSlackチャンネルでテスト  
- [ ] エラーケーステスト  
- [ ] 性能テスト（小規模データ）  
- [ ] バグ修正

#### 2.1.6 ドキュメント整備（1日）

**タスク:**

- [ ] README.md作成  
- [ ] セットアップガイド作成  
- [ ] 使用例の記載  
- [ ] トラブルシューティングガイド

### 2.2 フェーズ2: 機能拡張（Should要件）

#### 2.2.1 ユーザー情報取得機能（1日）

**タスク:**

- [ ] users.info API連携  
- [ ] ユーザー情報キャッシュ機能  
- [ ] CSV出力にuser\_name追加

**実装ポイント:**

```
def fetch_user_info(user_id)
  @user_cache ||= {}
  return @user_cache[user_id] if @user_cache[user_id]
  
  response = @client.users_info(user: user_id)
  user_info = {
    name: response.user.real_name || response.user.name,
    display_name: response.user.profile.display_name
  }
  @user_cache[user_id] = user_info
  
  sleep(1) # レートリミット対応
  user_info
end
```

#### 2.2.2 スレッド返信取得機能（1日）

**タスク:**

- [ ] conversations.replies API連携  
- [ ] スレッド構造の保持  
- [ ] CSV出力でのスレッド表現

**実装内容:**

```
def fetch_thread_replies(channel_id, thread_ts)
  response = @client.conversations_replies(
    channel: channel_id,
    ts: thread_ts
  )
  
  sleep(1)
  response.messages[1..-1] # 最初のメッセージは親なので除外
end
```

### 2.3 フェーズ3: 高度機能（Could要件）

#### 2.3.1 リアクション情報取得（1日）

**タスク:**

- [ ] メッセージのリアクション取得  
- [ ] リアクション集計処理  
- [ ] CSV出力にreactions列追加

#### 2.3.2 性能最適化とエラーハンドリング改善（1日）

**タスク:**

- [ ] 指数バックオフ実装  
- [ ] メモリ使用量最適化  
- [ ] 大量データ処理テスト  
- [ ] 詳細なログ出力

## 3\. Slack API 詳細情報

### 3.1 API制限情報（2024年最新）

#### 3.1.1 重要な変更点

**⚠️ Marketplace外アプリの制限強化（2025年5月29日から）**

- 新規作成アプリ: `conversations.history`と`conversations.replies`が1分間に1リクエストに制限  
- limitパラメータの最大値・デフォルト値が15に減少  
- 既存アプリ: 2025年9月2日から同様の制限が適用

#### 3.1.2 現在のレート制限

| API階層 | 制限 | 対象API |
| :---- | :---- | :---- |
| Tier 1 | 1+ per minute | 基本的なアクセス |
| Tier 2 | 20+ per minute | 一般的なメソッド |
| Tier 3 | 50+ per minute | `conversations.history`（Marketplace承認アプリ） |
| Tier 4 | 100+ per minute | 高頻度メソッド |
| Special Tier | 個別制限 | `chat.postMessage`など |

#### 3.1.3 対策

```
def handle_rate_limit(retries = 0)
  yield
rescue Slack::Web::Api::Errors::TooManyRequestsError => e
  if retries < 3
    wait_time = (2 ** retries) * 30 # 指数バックオフ
    puts "レートリミット到達。#{wait_time}秒待機します..."
    sleep(wait_time)
    handle_rate_limit(retries + 1) { yield }
  else
    raise e
  end
end

# 内部ツール向けの配慮
def internal_app_consideration
  # 2025年5月29日より前に作成された内部アプリは従来制限を維持
  # 新規作成の場合は制限を考慮した設計にする
end
```

### 3.2 必要なAPIエンドポイント詳細

#### 3.2.1 conversations.history

**用途**: チャンネルのメッセージ履歴取得 **制限**: Marketplace外の新規アプリは1分間1リクエスト **パラメータ**:

```
{
  channel: "C1234567890",    # 必須: チャンネルID
  cursor: "dXNlcjpVMDYx...", # オプション: ページネーション
  inclusive: true,           # オプション: タイムスタンプ境界含む
  latest: "1234567890.123456", # オプション: 終了タイムスタンプ
  limit: 100,                # オプション: 最大999（新規アプリは15）
  oldest: "1234567890.123456" # オプション: 開始タイムスタンプ
}
```

#### 3.2.2 conversations.replies

**用途**: スレッド返信の取得 **制限**: Marketplace外の新規アプリは1分間1リクエスト **パラメータ**:

```
{
  channel: "C1234567890",    # 必須: チャンネルID
  ts: "1234567890.123456",   # 必須: スレッドのタイムスタンプ
  cursor: "dXNlcjpVMDYx...", # オプション: ページネーション
  limit: 100                 # オプション: 最大999（新規アプリは15）
}
```

#### 3.2.3 users.info

**用途**: ユーザー情報の取得 **制限**: Tier 3（50+ reqs/min） **パラメータ**:

```
{
  user: "U1234567890"       # 必須: ユーザーID
}
```

### 3.3 必要なOAuthスコープ

#### 3.3.1 Bot Token スコープ

```
# 必須スコープ
required_scopes = [
  "channels:history",   # パブリックチャンネルの履歴読み取り
  "groups:history",     # プライベートチャンネルの履歴読み取り
  "im:history",         # ダイレクトメッセージの履歴読み取り
  "mpim:history",       # マルチパーティDMの履歴読み取り
  "users:read",         # ユーザー情報の読み取り
]

# オプション（Could要件）
optional_scopes = [
  "reactions:read"      # リアクション情報の読み取り
]
```

### 3.4 Slack App作成手順

#### 3.4.1 アプリ作成

1. **Slack APIページへアクセス**: [https://api.slack.com/apps](https://api.slack.com/apps)  
2. **Create New App**をクリック  
3. **From scratch**を選択  
4. アプリ名を入力（例：Slack History Fetcher）  
5. 開発ワークスペースを選択  
6. **Create App**をクリック

#### 3.4.2 OAuth設定

```
# OAuth & Permissionsページで設定
bot_scopes = %w[
  channels:history
  groups:history
  im:history
  mpim:history
  users:read
  reactions:read
]

# スコープ追加後
# 1. Install to Workspaceをクリック
# 2. 権限を確認してAllowをクリック
# 3. Bot User OAuth Tokenを取得
```

#### 3.4.3 Bot Token取得

```
# OAuth & Permissionsページから
bot_token = "xoxb-XXXXXXXXXXXX-XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXX"

# 環境変数として設定
ENV['SLACK_BOT_TOKEN'] = bot_token
```

### 3.5 APIレスポンス例

#### 3.5.1 conversations.history レスポンス

```
{
  "ok": true,
  "messages": [
    {
      "type": "message",
      "user": "U123ABC456",
      "text": "プロジェクト開始します！",
      "ts": "1512085950.000216",
      "reactions": [
        {
          "name": "thumbsup",
          "users": ["U111", "U222"],
          "count": 2
        }
      ]
    }
  ],
  "has_more": true,
  "response_metadata": {
    "next_cursor": "bmV4dF90czoxNTEyMDg1ODYx"
  }
}
```

#### 3.5.2 users.info レスポンス

```
{
  "ok": true,
  "user": {
    "id": "U123ABC456",
    "name": "yamada.taro",
    "real_name": "山田 太郎",
    "profile": {
      "display_name": "山田",
      "real_name": "山田 太郎",
      "email": "yamada@example.com"
    }
  }
}
```

## 4\. 技術的検討事項

### 4.1 メモリ使用量対策

**課題:**

- 大量メッセージ処理時のメモリ消費

**対策:**

- ストリーミング処理でCSV出力  
- バッチ処理での分割実行

### 4.2 エラーハンドリング強化

```
def safe_api_call
  retries = 0
  begin
    yield
  rescue Slack::Web::Api::Errors::SlackError => e
    puts "Slack APIエラー: #{e.message}"
    exit(1)
  rescue StandardError => e
    if retries < 3
      retries += 1
      puts "エラーが発生しました。再試行します... (#{retries}/3)"
      sleep(5)
      retry
    else
      puts "復旧不可能なエラー: #{e.message}"
      exit(1)
    end
  end
end
```

## 5\. テスト計画

### 5.1 単体テスト項目

**対象モジュール:**

- [ ] コマンドライン引数解析  
- [ ] 日付バリデーション  
- [ ] タイムスタンプ変換  
- [ ] CSV出力フォーマット  
- [ ] エラーハンドリング

**テストコード例:**

```
require 'minitest/autorun'

class SlackHistoryFetcherTest < Minitest::Test
  def test_parse_date
    fetcher = SlackHistoryFetcher.new
    assert_equal Date.new(2024, 1, 1), fetcher.parse_date('2024-01-01')
  end

  def test_convert_timestamp
    fetcher = SlackHistoryFetcher.new
    result = fetcher.convert_timestamp('1704067200.000100')
    assert_equal '2024-01-01 09:00:00', result
  end
end
```

### 5.2 結合テスト項目

- [ ] 実際のSlackチャンネルとの連携  
- [ ] 大量データ処理テスト（1000件以上のメッセージ）  
- [ ] 長期間データ取得テスト（1ヶ月以上）  
- [ ] エラー回復テスト

## 6\. リスク管理

### 6.1 技術リスク

| リスク | 影響度 | 対策 |
| :---- | :---- | :---- |
| Slack API仕様変更 | 高 | 公式ドキュメント定期確認、バージョン固定 |
| レートリミット超過 | 中 | 指数バックオフ、処理分割 |
| 大量データメモリ不足 | 中 | ストリーミング処理、バッチ分割 |
| 認証エラー | 高 | 詳細なエラーメッセージ、事前検証 |

### 6.2 スケジュールリスク

| リスク | 対策 |
| :---- | :---- |
| API理解に時間がかかる | 事前調査時間を十分確保 |
| テストデータ準備遅延 | 早期にテスト環境準備 |
| 性能問題発見 | フェーズ1で基本性能確認 |

## 7\. 開発環境・ツール

### 7.1 必要な環境

- **Ruby**: 3.0.0以上  
- **Bundler**: 最新版  
- **Git**: バージョン管理  
- **Slack Workspace**: テスト用

### 7.2 開発ツール

- **RuboCop**: コード品質管理  
- **Minitest**: テストフレームワーク  
- **Dotenv**: 環境変数管理

### 7.3 セットアップコマンド

```
# プロジェクト初期化
mkdir slack_history_fetcher
cd slack_history_fetcher
bundle init

# 依存関係インストール
bundle install

# 環境変数設定
cp .env.example .env
# .envファイルを編集してSLACK_BOT_TOKENを設定
```

## 8\. 品質保証

### 8.1 コード品質基準

- **RuboCop準拠**: 90%以上のスコア  
- **テストカバレッジ**: 80%以上  
- **ドキュメント整備**: README \+ インラインコメント

### 8.2 レビュー基準

- [ ] 機能要件の実装確認  
- [ ] エラーハンドリングの適切性  
- [ ] 性能要件の達成  
- [ ] セキュリティ要件の確認  
- [ ] ドキュメントの整備状況

## 9\. デプロイメント・リリース

### 9.1 リリース手順

1. **フェーズ1完了時**: 基本機能のみでベータリリース  
2. **フェーズ2完了時**: 機能拡張版リリース  
3. **フェーズ3完了時**: 正式版リリース

### 9.2 配布方法

- **Git Repository**: ソースコード公開  
- **実行可能ファイル**: 単体実行用スクリプト作成  
- **ドキュメント**: 使用方法とトラブルシューティング

## 10\. 保守・運用計画

### 10.1 保守項目

- **Slack API仕様変更対応**: 四半期ごとに確認  
- **依存ライブラリ更新**: 月次で脆弱性確認  
- **バグ修正**: 報告から1週間以内に対応

### 10.2 改善計画

- **ユーザーフィードバック収集**: 使用状況とニーズ把握  
- **機能追加検討**: 四半期ごとに評価  
- **性能改善**: 大量データ処理の最適化

## 11\. 開発スケジュール

### 11.1 詳細スケジュール

| フェーズ | 期間 | 開始日 | 完了予定日 | 主要マイルストーン |
| :---- | :---- | :---- | :---- | :---- |
| 環境セットアップ | 0.5日 | Day 1 | Day 1 | 開発環境構築完了 |
| 基本クラス実装 | 1日 | Day 1.5 | Day 2.5 | 基本構造完成 |
| API連携機能 | 1.5日 | Day 2.5 | Day 4 | Slack API連携完了 |
| CSV出力機能 | 1日 | Day 4 | Day 5 | 基本CSV出力完了 |
| 統合テスト | 1日 | Day 5 | Day 6 | フェーズ1機能確認 |
| ドキュメント整備 | 1日 | Day 6 | Day 7 | README等完成 |
| ユーザー情報取得 | 1日 | Day 7 | Day 8 | Should機能実装 |
| スレッド返信取得 | 1日 | Day 8 | Day 9 | Should機能完成 |
| リアクション取得 | 1日 | Day 9 | Day 10 | Could機能実装 |
| 最終テスト・最適化 | 1日 | Day 10 | Day 10 | 全機能完成 |

### 11.2 マイルストーン

- **Day 7**: フェーズ1完了（基本機能リリース可能）  
- **Day 9**: フェーズ2完了（機能拡張版リリース可能）  
- **Day 10**: フェーズ3完了（正式版リリース）

この実装計画に基づいて、段階的かつ確実にSlackチャンネル履歴取得ツールを開発していきます。  
