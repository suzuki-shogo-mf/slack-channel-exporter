require 'slack-ruby-client'
require 'dotenv/load'
require 'csv'
require 'optparse'
require 'date'

class SlackHistoryFetcher
  def initialize
    @token = load_token
    @client = Slack::Web::Client.new(token: @token)
    @user_cache = {}
  end

  def run(options)
    puts "Slackチャンネル履歴取得を開始します..."
    
    # 引数の検証
    validate_options(options)
    
    # メッセージ取得
    messages = fetch_messages(
      options[:channel_id],
      options[:start_date],
      options[:end_date]
    )
    
    # スレッド返信取得
    if options[:include_threads]
      puts "スレッド返信を取得中..."
      messages = fetch_thread_replies(options[:channel_id], messages)
    end
    
    puts "#{messages.length}件のメッセージを取得しました"
    
    # マークダウン出力
    output_file = generate_output_filename(options[:channel_id], options[:start_date], options[:end_date])
    export_to_markdown(messages, output_file)
    
    puts "マークダウンファイルに出力しました: #{output_file}"
  end

  def self.run_from_command_line(args)
    options = parse_arguments(args)
    fetcher = new
    fetcher.run(options)
  rescue StandardError => e
    puts "エラーが発生しました: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit(1)
  end

  private

  def load_token
    token = ENV['SLACK_BOT_TOKEN']
    if token.nil? || token.empty?
      raise "SLACK_BOT_TOKENが設定されていません。.envファイルを確認してください。"
    end
    token
  end

  def self.parse_arguments(args)
    options = {}
    
    parser = OptionParser.new do |opts|
      opts.banner = "使用方法: ruby slack_history_fetcher.rb [オプション]"
      
      opts.on('-c', '--channel CHANNEL_ID', '必須: チャンネルID') do |v|
        options[:channel_id] = v
      end
      
      opts.on('-s', '--start DATE', '開始日 (YYYY-MM-DD)') do |v|
        options[:start_date] = parse_date(v)
      end
      
      opts.on('-e', '--end DATE', '終了日 (YYYY-MM-DD)') do |v|
        options[:end_date] = parse_date(v)
      end
      
      opts.on('-o', '--output FILE', '出力ファイル名') do |v|
        options[:output_file] = v
      end
      
      opts.on('-t', '--threads', 'スレッド返信も取得する') do |v|
        options[:include_threads] = true
      end
      
      opts.on('-r', '--reactions', 'リアクション情報も取得する') do |v|
        options[:include_reactions] = true
      end
      
      opts.on('-h', '--help', 'このヘルプを表示') do
        puts opts
        exit
      end
    end
    
    parser.parse!(args)
    options
  end

  def self.parse_date(date_string)
    Date.parse(date_string)
  rescue ArgumentError
    raise "無効な日付形式です: #{date_string}。YYYY-MM-DD形式で入力してください。"
  end

  def validate_options(options)
    if options[:channel_id].nil? || options[:channel_id].empty?
      raise "チャンネルIDが指定されていません。-c オプションを使用してください。"
    end
    
    # デフォルト値の設定
    options[:start_date] ||= Date.today - 30 # 30日前から
    options[:end_date] ||= Date.today
    
    if options[:start_date] > options[:end_date]
      raise "開始日が終了日より後になっています。"
    end
  end

  def fetch_messages(channel_id, start_date, end_date)
    puts "メッセージを取得中..."
    messages = []
    cursor = nil
    page_count = 0
    
    loop do
      page_count += 1
      puts "ページ #{page_count} を取得中..."
      
      response = safe_api_call do
        @client.conversations_history(
          channel: channel_id,
          oldest: start_date.to_time.to_i,
          latest: end_date.to_time.to_i + 86400 - 1, # 終了日の23:59:59まで
          cursor: cursor,
          limit: 100
        )
      end
      
      messages.concat(response.messages)
      cursor = response.response_metadata&.next_cursor
      break unless cursor
      
      # レートリミット対応
      sleep(1)
    end
    
    # 時系列順にソート（古い順）
    messages.sort_by { |m| m.ts.to_f }
  end

  def export_to_markdown(messages, output_file)
    # 出力ディレクトリの作成
    output_dir = File.dirname(output_file)
    Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
    
    File.open(output_file, 'w', encoding: 'UTF-8') do |file|
      # ヘッダー
      file.puts "# Slackチャンネル履歴"
      file.puts
      file.puts "## メッセージ一覧"
      file.puts
      
      messages.each do |message|
        next if message.subtype == 'bot_message' # ボットメッセージは除外
        
        user_id = message.user || 'unknown'
        user_info = fetch_user_info(user_id) if user_id != 'unknown'
        user_name = user_info ? user_info[:name] : user_id
        
        # メッセージヘッダー
        file.puts "### #{convert_timestamp(message.ts)} - #{user_name}"
        file.puts
        
        # メッセージ本文
        file.puts "```"
        file.puts clean_text(message.text || '')
        file.puts "```"
        file.puts
        
        # リアクション情報
        if message.reactions && message.reactions.any?
          file.puts "**リアクション:**"
          message.reactions.each do |reaction|
            file.puts "- :#{reaction.name}: (#{reaction.count})"
          end
          file.puts
        end
        
        # スレッド情報
        if message.thread_ts
          file.puts "**スレッド返信**"
          file.puts
        end
        
        file.puts "---"
        file.puts
      end
    end
  end

  def convert_timestamp(slack_ts)
    Time.at(slack_ts.to_f).strftime('%Y-%m-%d %H:%M:%S')
  end

  def clean_text(text)
    # 改行コードをエスケープ
    text.gsub(/\r?\n/, '\\n')
  end

  def format_reactions(reactions)
    return '' unless reactions && reactions.any?
    
    reaction_strings = reactions.map do |reaction|
      "#{reaction.name}:#{reaction.count}"
    end
    
    reaction_strings.join(';')
  end

  def generate_output_filename(channel_id, start_date, end_date)
    output_dir = ENV['DEFAULT_OUTPUT_DIR'] || './output'
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    "#{output_dir}/slack_history_#{channel_id}_#{start_date}_#{end_date}_#{timestamp}.md"
  end

  def fetch_thread_replies(channel_id, messages)
    all_messages = messages.dup
    thread_parents = messages.select { |m| m.reply_count && m.reply_count > 0 }
    
    puts "#{thread_parents.length}個のスレッドの返信を取得中..."
    
    thread_parents.each_with_index do |parent, index|
      puts "スレッド #{index + 1}/#{thread_parents.length} を処理中..."
      
      begin
        response = safe_api_call do
          @client.conversations_replies(
            channel: channel_id,
            ts: parent.ts
          )
        end
        
        # 最初のメッセージ（親）は除外して返信のみ追加
        replies = response.messages[1..-1] || []
        all_messages.concat(replies)
        
        sleep(1) # レートリミット対応
      rescue Slack::Web::Api::Errors::SlackError => e
        puts "スレッド返信取得エラー (#{parent.ts}): #{e.message}"
        # エラーが発生しても処理を続行
      end
    end
    
    # 時系列順にソート
    all_messages.sort_by { |m| m.ts.to_f }
  end

  def fetch_user_info(user_id)
    return @user_cache[user_id] if @user_cache[user_id]
    
    begin
      response = safe_api_call do
        @client.users_info(user: user_id)
      end
      
      user_info = {
        name: response.user.real_name || response.user.name,
        display_name: response.user.profile.display_name || response.user.name
      }
      
      @user_cache[user_id] = user_info
      puts "ユーザー情報を取得: #{user_info[:name]}" if ENV['DEBUG']
      
      sleep(1) # レートリミット対応
      user_info
    rescue Slack::Web::Api::Errors::SlackError => e
      puts "ユーザー情報取得エラー (#{user_id}): #{e.message}"
      # エラーの場合はuser_idをそのまま使用し、キャッシュしない
      nil
    end
  end

  def safe_api_call(retries = 0)
    yield
  rescue Slack::Web::Api::Errors::TooManyRequestsError => e
    if retries < 3
      wait_time = (2 ** retries) * 30 # 指数バックオフ
      puts "レートリミット到達。#{wait_time}秒待機します..."
      sleep(wait_time)
      safe_api_call(retries + 1) { yield }
    else
      raise e
    end
  rescue Slack::Web::Api::Errors::SlackError => e
    puts "Slack APIエラー: #{e.message}"
    raise e
  rescue StandardError => e
    puts "予期しないエラー: #{e.message}"
    raise e
  end
end 