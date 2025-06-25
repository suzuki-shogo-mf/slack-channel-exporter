require 'yaml'
require 'date'

class ConfigManager
  DEFAULT_CONFIG = {
    'default_start_date' => '30_days_ago',
    'default_end_date' => 'today',
    'include_threads' => false,
    'include_reactions' => false,
    'include_user_info' => true,
    'output' => {
      'directory' => './output',
      'filename_format' => '{channel_name}_{start_date}_{end_date}_{timestamp}',
      'timezone' => 'Asia/Tokyo'
    },
    'performance' => {
      'api_delay' => 1,
      'max_retries' => 3,
      'batch_size' => 100
    },
    'logging' => {
      'level' => 'info',
      'file' => './logs/slack_fetcher.log',
      'console' => true
    }
  }.freeze

  def initialize(config_file = nil)
    @config = load_config(config_file)
  end

  def load_config(config_file)
    if config_file && File.exist?(config_file)
      file_config = YAML.safe_load(File.read(config_file))
      merge_config(DEFAULT_CONFIG, file_config)
    else
      DEFAULT_CONFIG.dup
    end
  rescue StandardError => e
    puts "設定ファイル読み込みエラー: #{e.message}"
    puts "デフォルト設定を使用します"
    DEFAULT_CONFIG.dup
  end

  def get(key)
    keys = key.split('.')
    keys.reduce(@config) { |config, k| config&.dig(k) }
  end

  def channels
    @config['channels'] || []
  end

  def parse_date(date_string)
    case date_string
    when 'today'
      Date.today
    when /(\d+)_days_ago/
      days = $1.to_i
      Date.today - days
    when /^\d{4}-\d{2}-\d{2}$/
      Date.parse(date_string)
    else
      raise "無効な日付形式: #{date_string}"
    end
  end

  def resolve_dates_for_channel(channel_config)
    start_date = channel_config['start_date'] || @config['default_start_date']
    end_date = channel_config['end_date'] || @config['default_end_date']
    
    {
      start_date: parse_date(start_date),
      end_date: parse_date(end_date)
    }
  end

  def channel_settings(channel_config)
    {
      include_threads: channel_config['include_threads'] || @config['include_threads'],
      include_reactions: channel_config['include_reactions'] || @config['include_reactions'],
      include_user_info: channel_config['include_user_info'] || @config['include_user_info']
    }
  end

  def output_filename(channel_name, start_date, end_date)
    template = @config.dig('output', 'filename_format')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    filename = template
      .gsub('{channel_name}', channel_name)
      .gsub('{start_date}', start_date.to_s)
      .gsub('{end_date}', end_date.to_s)
      .gsub('{timestamp}', timestamp)
    
    File.join(@config.dig('output', 'directory'), "#{filename}.csv")
  end

  private

  def merge_config(default, custom)
    merged = default.dup
    custom.each do |key, value|
      if merged[key].is_a?(Hash) && value.is_a?(Hash)
        merged[key] = merge_config(merged[key], value)
      else
        merged[key] = value
      end
    end
    merged
  end
end 