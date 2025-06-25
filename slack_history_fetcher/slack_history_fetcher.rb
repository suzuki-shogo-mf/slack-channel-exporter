#!/usr/bin/env ruby

require_relative 'lib/slack_history_fetcher'

# コマンドライン引数を処理してツールを実行
SlackHistoryFetcher.run_from_command_line(ARGV) 