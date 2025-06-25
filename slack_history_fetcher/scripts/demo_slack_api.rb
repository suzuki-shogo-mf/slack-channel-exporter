#!/usr/bin/env ruby

require_relative '../lib/advanced_slack_client'
require 'dotenv/load'

class SlackAPIDemo
  def initialize
    @token = ENV['SLACK_BOT_TOKEN']
    @client = AdvancedSlackClient.new(@token, verbose: true)
    
    puts "🚀 Slack API 実践デモンストレーション"
    puts "=" * 50
  end

  def run_full_demo
    return unless check_connection
    
    puts "\n🎯 デモ開始！"
    
    # 1. チャンネル一覧取得
    channels = demo_channel_list
    return if channels.empty?
    
    # 2. 最初のチャンネルでメッセージ取得デモ
    demo_channel = channels.first
    demo_message_history(demo_channel)
    
    # 3. ユーザー情報取得デモ
    demo_user_info
    
    # 4. 統計情報表示
    show_statistics
    
    puts "\n✅ デモ完了！"
  end

  def interactive_demo
    return unless check_connection
    
    puts "\n🎮 インタラクティブデモモード"
    puts "利用可能なコマンド:"
    puts "  1: チャンネル一覧表示"
    puts "  2: 特定チャンネルのメッセージ取得"
    puts "  3: ユーザー情報検索"
    puts "  4: 統計情報表示"
    puts "  q: 終了"
    
    loop do
      print "\n> コマンドを入力してください: "
      input = gets.chomp.downcase
      
      case input
      when '1'
        demo_channel_list
      when '2'
        interactive_message_demo
      when '3'
        interactive_user_demo
      when '4'
        show_statistics
      when 'q', 'quit', 'exit'
        puts "👋 デモを終了します"
        break
      else
        puts "❌ 無効なコマンドです"
      end
    end
  end

  private

  def check_connection
    puts "🔌 Slack API 接続テスト..."
    
    begin
      auth = @client.test_connection
      puts "✅ 接続成功！"
      puts "   ワークスペース: #{auth.team}"
      puts "   ユーザー: #{auth.user}"
      return true
    rescue StandardError => e
      puts "❌ 接続失敗: #{e.message}"
      puts "💡 .envファイルのSLACK_BOT_TOKENを確認してください"
      return false
    end
  end

  def demo_channel_list
    puts "\n📋 チャンネル一覧取得デモ..."
    
    begin
      channels = @client.get_channels(
        exclude_archived: true,
        limit: 10
      )
      
      puts "✅ #{channels.length}個のチャンネルを取得"
      
      channels.each_with_index do |channel, index|
        type_icon = channel[:is_private] ? '🔒' : '🌐'
        puts "   #{index + 1}. #{type_icon} ##{channel[:name]} (#{channel[:id]})"
      end
      
      return channels
      
    rescue StandardError => e
      puts "❌ チャンネル一覧取得エラー: #{e.message}"
      return []
    end
  end

  def demo_message_history(channel)
    puts "\n💬 メッセージ履歴取得デモ"
    puts "対象チャンネル: ##{channel[:name]}"
    
    begin
      # 最新5件のメッセージを取得
      messages = @client.get_messages(
        channel[:id],
        limit: 5
      )
      
      puts "✅ #{messages.length}件のメッセージを取得"
      
      messages.reverse.each_with_index do |message, index|
        next unless message.text && !message.text.empty?
        
        timestamp = Time.at(message.ts.to_f).strftime('%Y-%m-%d %H:%M:%S')
        text_preview = message.text.slice(0, 50)
        text_preview += "..." if message.text.length > 50
        
        puts "   #{index + 1}. [#{timestamp}] #{text_preview}"
        
        # ユーザー情報も取得してみる
        if message.user
          user_info = @client.get_user_info(message.user)
          user_name = user_info ? user_info[:real_name] || user_info[:name] : 'Unknown'
          puts "      👤 送信者: #{user_name}"
        end
        
        puts "      📊 reactions: #{message.reactions&.length || 0}" if message.reactions
      end
      
    rescue StandardError => e
      puts "❌ メッセージ取得エラー: #{e.message}"
    end
  end

  def demo_user_info
    puts "\n👤 ユーザー情報取得デモ"
    
    # 認証情報から自分のユーザーIDを取得
    begin
      auth = @client.test_connection
      my_user_id = auth.user_id
      
      user_info = @client.get_user_info(my_user_id)
      
      if user_info
        puts "✅ ユーザー情報取得成功:"
        puts "   名前: #{user_info[:real_name] || user_info[:name]}"
        puts "   表示名: #{user_info[:display_name]}" if user_info[:display_name]
        puts "   メール: #{user_info[:email]}" if user_info[:email]
        puts "   Bot: #{user_info[:is_bot] ? 'Yes' : 'No'}"
      end
      
    rescue StandardError => e
      puts "❌ ユーザー情報取得エラー: #{e.message}"
    end
  end

  def interactive_message_demo
    channels = @client.get_channels(exclude_archived: true, limit: 20)
    
    puts "\n📋 チャンネル選択:"
    channels.each_with_index do |channel, index|
      type_icon = channel[:is_private] ? '🔒' : '🌐'
      puts "   #{index + 1}. #{type_icon} ##{channel[:name]}"
    end
    
    print "\n> チャンネル番号を入力してください (1-#{channels.length}): "
    choice = gets.chomp.to_i
    
    if choice >= 1 && choice <= channels.length
      selected_channel = channels[choice - 1]
      demo_message_history(selected_channel)
    else
      puts "❌ 無効な選択です"
    end
  end

  def interactive_user_demo
    print "\n> ユーザーIDを入力してください (例: U1234567890): "
    user_id = gets.chomp
    
    if user_id.match?(/^U[A-Z0-9]+$/)
      user_info = @client.get_user_info(user_id)
      
      if user_info
        puts "✅ ユーザー情報:"
        puts "   ID: #{user_info[:id]}"
        puts "   名前: #{user_info[:real_name] || user_info[:name]}"
        puts "   表示名: #{user_info[:display_name]}" if user_info[:display_name]
        puts "   削除済み: #{user_info[:deleted] ? 'Yes' : 'No'}"
      else
        puts "❌ ユーザーが見つかりません"
      end
    else
      puts "❌ 無効なユーザーIDフォーマットです"
    end
  end

  def show_statistics
    puts "\n📊 API統計情報"
    stats = @client.stats
    
    puts "API呼び出し数: #{stats[:api_calls]}"
    puts "キャッシュヒット数: #{stats[:cache_hits]}"
    puts "リトライ回数: #{stats[:retries]}"
    puts "エラー回数: #{stats[:errors]}"
    
    puts "\nキャッシュサイズ:"
    puts "  ユーザー: #{stats[:cache_size][:users]}"
    puts "  チャンネル: #{stats[:cache_size][:channels]}"
    
    if stats[:api_efficiency].is_a?(Hash)
      puts "\n効率性:"
      puts "  キャッシュヒット率: #{stats[:api_efficiency][:cache_hit_rate]}"
      puts "  エラー率: #{stats[:api_efficiency][:error_rate]}"
      puts "  リトライ率: #{stats[:api_efficiency][:retry_rate]}"
    end
  end
end

# メイン実行
if __FILE__ == $0
  demo = SlackAPIDemo.new
  
  if ARGV.include?('--interactive') || ARGV.include?('-i')
    demo.interactive_demo
  else
    demo.run_full_demo
  end
end 