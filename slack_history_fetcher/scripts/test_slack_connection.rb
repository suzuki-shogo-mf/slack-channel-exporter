#!/usr/bin/env ruby

require_relative '../lib/slack_history_fetcher'
require 'slack-ruby-client'
require 'dotenv/load'

class SlackConnectionTester
  def initialize
    @token = ENV['SLACK_BOT_TOKEN']
    puts "🧪 Slack API 接続テストを開始します...\n"
  end

  def run_tests
    return false unless check_environment
    
    client = create_client
    return false unless client
    
    return false unless test_authentication(client)
    return false unless test_channel_list(client)
    
    puts "\n✅ 全てのテストが成功しました！"
    puts "🚀 メッセージ履歴取得ツールを使用開始できます。"
    true
  rescue StandardError => e
    puts "\n❌ 予期しないエラーが発生しました: #{e.message}"
    puts "詳細: #{e.backtrace.first(3).join("\n")}" if ENV['DEBUG']
    false
  end

  private

  def check_environment
    puts "1️⃣ 環境設定チェック..."
    
    if @token.nil? || @token.empty?
      puts "❌ SLACK_BOT_TOKENが設定されていません"
      puts "💡 解決方法:"
      puts "   1. .envファイルを作成: cp env.example .env"
      puts "   2. .envファイルにトークンを追加: SLACK_BOT_TOKEN=xoxb-..."
      return false
    end
    
    unless @token.start_with?('xoxb-')
      puts "❌ 無効なトークン形式です（Bot User OAuth Tokenが必要）"
      puts "💡 トークンは 'xoxb-' で始まる必要があります"
      return false
    end
    
    puts "✅ 環境設定OK (トークン: #{@token[0..10]}...)"
    true
  end

  def create_client
    puts "\n2️⃣ Slack クライアント作成..."
    
    client = Slack::Web::Client.new(token: @token)
    puts "✅ クライアント作成成功"
    client
  rescue StandardError => e
    puts "❌ クライアント作成失敗: #{e.message}"
    false
  end

  def test_authentication(client)
    puts "\n3️⃣ 認証テスト..."
    
    auth = client.auth_test
    puts "✅ 認証成功！"
    puts "   ユーザー: #{auth.user}"
    puts "   チーム: #{auth.team}"
    puts "   URL: #{auth.url}"
    true
  rescue Slack::Web::Api::Errors::InvalidAuth
    puts "❌ 認証失敗: トークンが無効です"
    puts "💡 新しいトークンを取得してください"
    false
  rescue StandardError => e
    puts "❌ 認証エラー: #{e.message}"
    false
  end

  def test_channel_list(client)
    puts "\n4️⃣ チャンネル一覧取得テスト..."
    
    response = client.conversations_list(
      limit: 10,
      exclude_archived: true,
      types: 'public_channel,private_channel'
    )
    
    channels = response.channels
    puts "✅ チャンネル一覧取得成功 (#{channels.length}件)"
    
    if channels.empty?
      puts "⚠️  アクセス可能なチャンネルがありません"
      puts "💡 プライベートチャンネルの場合、アプリを招待してください"
    else
      puts "\n📋 アクセス可能なチャンネル:"
      channels.first(5).each do |channel|
        channel_type = channel.is_private ? '🔒' : '🌐'
        puts "   #{channel_type} #{channel.name} (#{channel.id})"
      end
      
      if channels.length > 5
        puts "   ... 他 #{channels.length - 5} チャンネル"
      end
    end
    
    true
  rescue Slack::Web::Api::Errors::MissingScope => e
    puts "❌ 権限不足: #{e.message}"
    puts "💡 必要なスコープ: channels:read, groups:read"
    false
  rescue StandardError => e
    puts "❌ チャンネル一覧取得エラー: #{e.message}"
    false
  end
end

# 特定チャンネルのテスト機能
def test_specific_channel(channel_id)
  puts "\n🎯 特定チャンネルのテスト (#{channel_id})..."
  
  client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
  
  # チャンネル情報取得
  begin
    info = client.conversations_info(channel: channel_id)
    channel = info.channel
    puts "✅ チャンネル情報取得成功:"
    puts "   名前: #{channel.name}"
    puts "   種類: #{channel.is_private ? 'プライベート' : 'パブリック'}"
    puts "   メンバー数: #{channel.num_members}" if channel.num_members
  rescue Slack::Web::Api::Errors::ChannelNotFound
    puts "❌ チャンネルが見つかりません（アクセス権限なし）"
    return false
  end
  
  # 履歴取得テスト
  begin
    history = client.conversations_history(
      channel: channel_id,
      limit: 1
    )
    puts "✅ 履歴取得成功 (メッセージ数: #{history.messages.length})"
    
    if history.messages.any?
      message = history.messages.first
      puts "   最新メッセージ: #{message.text&.slice(0, 50)}..."
    end
    
  rescue Slack::Web::Api::Errors::MissingScope
    puts "❌ 履歴取得権限なし (必要スコープ: channels:history)"
    return false
  rescue StandardError => e
    puts "❌ 履歴取得エラー: #{e.message}"
    return false
  end
  
  true
end

# メイン実行
if __FILE__ == $0
  puts "=" * 60
  puts "🔧 Slack API 接続診断ツール"
  puts "=" * 60
  
  tester = SlackConnectionTester.new
  success = tester.run_tests
  
  # コマンドライン引数でチャンネルIDが指定された場合
  if ARGV.length > 0 && success
    ARGV.each do |channel_id|
      test_specific_channel(channel_id)
    end
  end
  
  puts "\n" + "=" * 60
  
  if success
    puts "🎉 診断完了！ツールを使用開始してください。"
    puts "📖 使用方法: ruby slack_history_fetcher.rb --help"
  else
    puts "💥 問題が見つかりました。上記の解決方法を試してください。"
    exit(1)
  end
end 