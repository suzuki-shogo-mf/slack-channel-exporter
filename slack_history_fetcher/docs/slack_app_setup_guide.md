# Slack アプリ作成 & API設定 詳細ガイド

## 🚀 ステップ1: Slackアプリの作成

### 1.1 Slack API サイトへアクセス
1. [https://api.slack.com/apps](https://api.slack.com/apps) にアクセス
2. 右上の **「Create New App」** ボタンをクリック

### 1.2 アプリ作成方法を選択
- **「From scratch」** を選択（推奨）
- 「From an app manifest」は今回は使いません

### 1.3 基本情報を入力
```
App Name: Slack History Fetcher
Development Slack Workspace: [あなたのワークスペースを選択]
```

### 1.4 「Create App」をクリック

## 🔐 ステップ2: OAuth権限の設定

### 2.1 OAuth & Permissions画面に移動
左サイドバーの **「OAuth & Permissions」** をクリック

### 2.2 Bot Token Scopesを設定
「Bot Token Scopes」セクションで、以下のスコープを追加：

```
必須スコープ:
✅ channels:history      # パブリックチャンネルの履歴
✅ groups:history        # プライベートチャンネルの履歴  
✅ im:history           # ダイレクトメッセージの履歴
✅ mpim:history         # マルチパーティDMの履歴
✅ users:read           # ユーザー情報の読み取り

オプションスコープ:
✅ reactions:read       # リアクション情報の読み取り
✅ channels:read        # チャンネル情報の読み取り
✅ groups:read          # プライベートチャンネル情報の読み取り
```

### 2.3 アプリをワークスペースにインストール
1. 画面上部の **「Install to Workspace」** ボタンをクリック
2. 権限確認画面で **「Allow」** をクリック

### 2.4 Bot User OAuth Tokenを取得
インストール完了後、**「Bot User OAuth Token」** が表示されます：
```
xoxb-XXXXXXXXXXXX-XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXX
```
⚠️ このトークンは機密情報です。安全に保管してください。

## 🔧 ステップ3: 環境設定

### 3.1 .envファイルの作成
```bash
cp env.example .env
```

### 3.2 トークンを.envに設定
```env
SLACK_BOT_TOKEN=xoxb-XXXXXXXXXXXX-XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXX
```

## 📋 ステップ4: チャンネルIDの取得方法

### 4.1 Slack アプリからチャンネルIDを取得
1. Slackアプリで対象チャンネルを開く
2. チャンネル名をクリック
3. 下部に表示される「Channel ID」をコピー

### 4.2 ブラウザ版Slackから取得
1. ブラウザでSlackを開く
2. 対象チャンネルを開く
3. URLの最後の部分がチャンネルID：
   ```
   https://app.slack.com/client/T1234567890/C1234567890
                                        ↑この部分
   ```

### 4.3 API経由で取得（上級者向け）
```ruby
# チャンネル一覧取得
client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
response = client.conversations_list
response.channels.each do |channel|
  puts "#{channel.name}: #{channel.id}"
end
```

## 🧪 ステップ5: 接続テスト

### 5.1 シンプルなテストスクリプト
```ruby
require 'slack-ruby-client'
require 'dotenv/load'

client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])

begin
  # 認証テスト
  auth = client.auth_test
  puts "✅ 接続成功！"
  puts "ユーザー: #{auth.user}"
  puts "チーム: #{auth.team}"
  
  # チャンネル一覧取得テスト
  channels = client.conversations_list(limit: 5)
  puts "\n📋 アクセス可能なチャンネル:"
  channels.channels.each do |channel|
    puts "  - #{channel.name} (#{channel.id})"
  end
  
rescue Slack::Web::Api::Errors::SlackError => e
  puts "❌ Slack APIエラー: #{e.message}"
rescue StandardError => e
  puts "❌ エラー: #{e.message}"
end
```

## 🔒 ステップ6: プライベートチャンネルへのアクセス

### 6.1 アプリをチャンネルに招待
プライベートチャンネルにアクセスするには：

1. 対象チャンネルを開く
2. `/invite @Slack History Fetcher` とコマンド入力
3. または、チャンネル設定からアプリを追加

### 6.2 権限確認
```ruby
# 特定チャンネルへのアクセステスト
channel_id = 'C1234567890'
begin
  info = client.conversations_info(channel: channel_id)
  puts "✅ チャンネル '#{info.channel.name}' にアクセス可能"
rescue Slack::Web::Api::Errors::ChannelNotFound
  puts "❌ チャンネルが見つかりません（アクセス権限なし）"
end
```

## ⚡ ステップ7: レート制限について

### 7.1 2025年の重要な変更
- **新規アプリ（2025/5/29以降）**: `conversations.history` が1分間1リクエストに制限
- **既存アプリ**: 2025/9/2から同様の制限適用

### 7.2 対策
1. **内部ツール申請**: Slack に内部ツールとして申請
2. **データ分割**: 期間を細かく分けて取得
3. **マーケットプレイス承認**: 公開アプリとして承認取得

## 🚨 トラブルシューティング

### よくあるエラーと対処法

#### 1. `invalid_auth` エラー
```
原因: トークンが無効
対処: 
- .envファイルのトークンを確認
- アプリが正しくインストールされているか確認
```

#### 2. `channel_not_found` エラー
```
原因: チャンネルにアクセス権限がない
対処:
- チャンネルIDが正しいか確認
- プライベートチャンネルの場合、アプリを招待
```

#### 3. `ratelimited` エラー
```
原因: API呼び出し制限に達した
対処:
- sleep時間を増やす（2-3秒）
- 指数バックオフを実装
```

#### 4. `missing_scope` エラー
```
原因: 必要な権限が不足
対処:
- OAuth & Permissionsで必要なスコープを追加
- アプリを再インストール
```

## 🎯 次のステップ

1. ✅ トークン取得完了
2. ✅ 接続テスト完了
3. 🔄 実際のメッセージ取得テスト
4. 🔄 大量データ取得テスト
5. 🔄 本番運用

---

**💡 ヒント**: 本ガイドに従って設定すれば、15分程度でSlack APIが使用開始できます！ 