require 'slack-ruby-client'
require 'json'

class AdvancedSlackClient
  # 2025年の新しいレート制限に対応
  RATE_LIMITS = {
    'conversations.history' => { calls_per_minute: 1, tier: 'new_app_restricted' },
    'conversations.replies' => { calls_per_minute: 1, tier: 'new_app_restricted' },
    'users.info' => { calls_per_minute: 50, tier: 'tier_3' },
    'conversations.list' => { calls_per_minute: 20, tier: 'tier_2' },
    'conversations.info' => { calls_per_minute: 20, tier: 'tier_2' }
  }.freeze

  def initialize(token, config = {})
    @client = Slack::Web::Client.new(token: token)
    @config = config
    @api_calls = {}
    @user_cache = {}
    @channel_cache = {}
    
    # 統計情報
    @stats = {
      api_calls: 0,
      cache_hits: 0,
      retries: 0,
      errors: 0
    }
  end

  # 認証テスト（高速）
  def test_connection
    @client.auth_test
  rescue Slack::Web::Api::Errors::SlackError => e
    handle_slack_error(e, 'auth_test')
    raise
  end

  # チャンネル一覧取得（キャッシュ付き）
  def get_channels(options = {})
    cache_key = "channels_#{options.hash}"
    return @channel_cache[cache_key] if @channel_cache[cache_key]

    result = rate_limited_call('conversations.list') do
      @client.conversations_list(options)
    end

    channels = result.channels.map do |channel|
      {
        id: channel.id,
        name: channel.name,
        is_private: channel.is_private,
        is_archived: channel.is_archived,
        num_members: channel.num_members
      }
    end

    @channel_cache[cache_key] = channels
    channels
  end

  # チャンネル情報取得（キャッシュ付き）
  def get_channel_info(channel_id)
    return @channel_cache[channel_id] if @channel_cache[channel_id]

    result = rate_limited_call('conversations.info') do
      @client.conversations_info(channel: channel_id)
    end

    channel_info = {
      id: result.channel.id,
      name: result.channel.name,
      is_private: result.channel.is_private,
      topic: result.channel.topic&.value,
      purpose: result.channel.purpose&.value,
      created: Time.at(result.channel.created.to_i),
      num_members: result.channel.num_members
    }

    @channel_cache[channel_id] = channel_info
    channel_info
  end

  # メッセージ履歴取得（高度なページネーション対応）
  def get_messages(channel_id, options = {})
    messages = []
    cursor = options[:cursor]
    page_count = 0
    max_pages = options[:max_pages] || Float::INFINITY

    loop do
      page_count += 1
      break if page_count > max_pages

      puts "📄 ページ #{page_count} 取得中..." if @config[:verbose]

      result = rate_limited_call('conversations.history') do
        @client.conversations_history(
          channel: channel_id,
          oldest: options[:oldest],
          latest: options[:latest],
          cursor: cursor,
          limit: options[:limit] || 100,
          inclusive: options[:inclusive]
        )
      end

      page_messages = result.messages || []
      messages.concat(page_messages)

      cursor = result.response_metadata&.next_cursor
      break unless cursor

      # プログレス表示
      if @config[:verbose] && page_count % 10 == 0
        puts "💾 現在 #{messages.length} メッセージ取得済み..."
      end
    end

    messages
  end

  # スレッド返信取得
  def get_thread_replies(channel_id, thread_ts)
    rate_limited_call('conversations.replies') do
      result = @client.conversations_replies(
        channel: channel_id,
        ts: thread_ts
      )
      # 最初のメッセージ（親）を除外
      result.messages[1..-1] || []
    end
  end

  # ユーザー情報取得（高効率キャッシュ付き）
  def get_user_info(user_id)
    return @user_cache[user_id] if @user_cache[user_id]
    return nil if user_id.nil? || user_id.empty?

    begin
      result = rate_limited_call('users.info') do
        @client.users_info(user: user_id)
      end

      user_info = {
        id: result.user.id,
        name: result.user.name,
        real_name: result.user.real_name,
        display_name: result.user.profile&.display_name,
        email: result.user.profile&.email,
        is_bot: result.user.is_bot,
        deleted: result.user.deleted
      }

      @user_cache[user_id] = user_info
      @stats[:cache_hits] += 1 if @user_cache.size > 1
      user_info

    rescue Slack::Web::Api::Errors::UserNotFound
      # 削除されたユーザーの場合
      @user_cache[user_id] = { id: user_id, name: 'Unknown User', deleted: true }
      @user_cache[user_id]
    end
  end

  # 一括ユーザー情報取得（効率化）
  def get_users_info(user_ids)
    uncached_ids = user_ids - @user_cache.keys
    
    uncached_ids.each do |user_id|
      get_user_info(user_id)
      # バースト制御
      sleep(0.1) if uncached_ids.size > 10
    end

    user_ids.map { |id| @user_cache[id] }.compact
  end

  # 統計情報
  def stats
    @stats.merge({
      cache_size: {
        users: @user_cache.size,
        channels: @channel_cache.size
      },
      api_efficiency: calculate_efficiency
    })
  end

  private

  # レート制限対応のAPI呼び出し
  def rate_limited_call(method_name, retries = 0)
    track_api_call(method_name)
    
    # 事前チェック：レート制限に達していないか
    if should_wait_for_rate_limit?(method_name)
      wait_time = calculate_wait_time(method_name)
      puts "⏰ レート制限のため #{wait_time}秒待機中..." if @config[:verbose]
      sleep(wait_time)
    end

    result = yield
    @stats[:api_calls] += 1
    result

  rescue Slack::Web::Api::Errors::TooManyRequestsError => e
    @stats[:retries] += 1
    
    if retries < 3
      wait_time = calculate_exponential_backoff(retries)
      puts "🔄 レート制限到達。#{wait_time}秒後にリトライ... (#{retries + 1}/3)"
      sleep(wait_time)
      rate_limited_call(method_name, retries + 1) { yield }
    else
      @stats[:errors] += 1
      raise e
    end

  rescue Slack::Web::Api::Errors::SlackError => e
    @stats[:errors] += 1
    handle_slack_error(e, method_name)
    raise e
  end

  def track_api_call(method_name)
    now = Time.now
    @api_calls[method_name] ||= []
    @api_calls[method_name] << now
    
    # 古い記録を削除（1分以上前）
    @api_calls[method_name].reject! { |time| now - time > 60 }
  end

  def should_wait_for_rate_limit?(method_name)
    return false unless RATE_LIMITS[method_name]
    
    recent_calls = @api_calls[method_name] || []
    limit = RATE_LIMITS[method_name][:calls_per_minute]
    
    recent_calls.size >= limit
  end

  def calculate_wait_time(method_name)
    recent_calls = @api_calls[method_name] || []
    return 1 if recent_calls.empty?
    
    oldest_call = recent_calls.min
    time_since_oldest = Time.now - oldest_call
    
    # 1分間隔を保つ
    [61 - time_since_oldest, 1].max
  end

  def calculate_exponential_backoff(retry_count)
    base_delay = 30
    [base_delay * (2 ** retry_count), 300].min # 最大5分
  end

  def handle_slack_error(error, method_name)
    case error
    when Slack::Web::Api::Errors::InvalidAuth
      puts "❌ 認証エラー: トークンが無効です"
    when Slack::Web::Api::Errors::ChannelNotFound
      puts "❌ チャンネルが見つかりません（権限不足の可能性）"
    when Slack::Web::Api::Errors::MissingScope
      puts "❌ 権限不足: #{error.message}"
    when Slack::Web::Api::Errors::AccountInactive
      puts "❌ アカウントが無効です"
    else
      puts "❌ Slack APIエラー [#{method_name}]: #{error.message}"
    end
  end

  def calculate_efficiency
    total_requests = @stats[:api_calls]
    return 0 if total_requests == 0
    
    cache_hit_rate = (@stats[:cache_hits].to_f / total_requests * 100).round(2)
    error_rate = (@stats[:errors].to_f / total_requests * 100).round(2)
    
    {
      cache_hit_rate: "#{cache_hit_rate}%",
      error_rate: "#{error_rate}%",
      retry_rate: "#{(@stats[:retries].to_f / total_requests * 100).round(2)}%"
    }
  end
end 