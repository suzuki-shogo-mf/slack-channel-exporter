require 'minitest/autorun'
require_relative '../lib/slack_history_fetcher'
require 'date'

class SlackHistoryFetcherTest < Minitest::Test
  def test_parse_date
    # 正常なケース
    assert_equal Date.new(2024, 1, 1), SlackHistoryFetcher.parse_date('2024-01-01')
    assert_equal Date.new(2024, 12, 31), SlackHistoryFetcher.parse_date('2024-12-31')
  end

  def test_parse_date_invalid
    # 異常なケース
    assert_raises(RuntimeError) { SlackHistoryFetcher.parse_date('invalid-date') }
    assert_raises(RuntimeError) { SlackHistoryFetcher.parse_date('2024-13-01') }
  end

  def test_convert_timestamp
    # Slackのタイムスタンプを日時に変換
    fetcher = create_fetcher_without_token
    
    # 2024-01-01 00:00:00 UTC のタイムスタンプ
    slack_ts = '1704067200.000100'
    result = fetcher.send(:convert_timestamp, slack_ts)
    
    # システムタイムゾーンで変換される（JSTの場合は+9時間）
    assert_match(/2024-01-01 \d{2}:\d{2}:\d{2}/, result)
  end

  def test_clean_text
    fetcher = create_fetcher_without_token
    
    # 改行コードのエスケープ
    assert_equal 'line1\\nline2', fetcher.send(:clean_text, "line1\nline2")
    assert_equal 'line1\\nline2', fetcher.send(:clean_text, "line1\r\nline2")
  end

  def test_generate_output_filename
    fetcher = create_fetcher_without_token
    
    start_date = Date.new(2024, 1, 1)
    end_date = Date.new(2024, 1, 31)
    filename = fetcher.send(:generate_output_filename, 'C1234567890', start_date, end_date)
    
    assert_match(/slack_history_C1234567890_2024-01-01_2024-01-31_\d{8}_\d{6}\.csv/, filename)
    assert_match(/^\.\/output\//, filename)
  end

  def test_fetch_user_info_cache
    fetcher = create_fetcher_without_token
    
    # キャッシュが空の状態
    assert_nil fetcher.instance_variable_get(:@user_cache)['U123']
    
    # キャッシュに直接設定してテスト
    fetcher.instance_variable_get(:@user_cache)['U123'] = { name: 'Test User', display_name: 'Test' }
    
    # キャッシュから取得されることを確認
    result = fetcher.send(:fetch_user_info, 'U123')
    assert_equal 'Test User', result[:name]
  end

  private

  def create_fetcher_without_token
    # テスト用に環境変数を設定せずにインスタンスを作成する場合の対応
    original_env = ENV['SLACK_BOT_TOKEN']
    ENV['SLACK_BOT_TOKEN'] = 'test-token'
    
    fetcher = SlackHistoryFetcher.allocate
    fetcher.instance_variable_set(:@token, 'test-token')
    fetcher.instance_variable_set(:@user_cache, {})
    
    ENV['SLACK_BOT_TOKEN'] = original_env
    fetcher
  end
end 