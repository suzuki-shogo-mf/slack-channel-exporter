require 'colorize'
require 'fileutils'

class SlackLogger
  LEVELS = {
    'debug' => 0,
    'info' => 1,
    'warn' => 2,
    'error' => 3
  }.freeze

  def initialize(config)
    @level = LEVELS[config.get('logging.level')] || 1
    @log_file = config.get('logging.file')
    @console = config.get('logging.console')
    
    setup_log_file if @log_file
  end

  def debug(message)
    log('debug', message, :light_black)
  end

  def info(message)
    log('info', message, :white)
  end

  def warn(message)
    log('warn', message, :yellow)
  end

  def error(message)
    log('error', message, :red)
  end

  def success(message)
    log('info', message, :green)
  end

  def progress(message)
    log('info', message, :cyan)
  end

  private

  def log(level, message, color = :white)
    level_num = LEVELS[level]
    return if level_num < @level

    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    formatted_message = "[#{timestamp}] [#{level.upcase}] #{message}"

    # コンソール出力
    if @console
      colored_message = case level
      when 'debug'
        formatted_message.colorize(:light_black)
      when 'info'
        formatted_message.colorize(color)
      when 'warn'
        formatted_message.colorize(:yellow)
      when 'error'
        formatted_message.colorize(:red)
      end
      puts colored_message
    end

    # ファイル出力
    if @log_file
      File.open(@log_file, 'a') do |f|
        f.puts formatted_message
      end
    end
  end

  def setup_log_file
    return unless @log_file
    
    log_dir = File.dirname(@log_file)
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
  end
end 