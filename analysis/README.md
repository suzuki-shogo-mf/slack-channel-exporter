# Slack Message Analysis Tools

このディレクトリには、Slackメッセージの分析を行うPythonスクリプトが含まれています。

## 📊 分析ツール一覧

### KPT分析
- **`kpt_analyzer.py`**: Keep/Problem/Try分析を実行
- KPTフレームワークに基づいてメッセージを分類・分析

### ネガティブ分析
- **`negative_analyzer.py`**: ネガティブな感情を持つメッセージを特定
- **`negative_list_generator.py`**: ネガティブメッセージの一覧生成
- **`negative_summary.py`**: ネガティブ分析の要約レポート作成

### ポジティブ分析
- **`positive_list_generator.py`**: ポジティブメッセージの一覧生成

### 可視化
- **`wordcloud_generator.py`**: メッセージからワードクラウドを生成

## 🚀 使用方法

### 1. 依存関係のインストール

```bash
cd analysis
pip install -r requirements.txt
```

### 2. CSVファイルの準備

まず、親ディレクトリの`slack_history_fetcher`でSlackメッセージをCSV形式でエクスポートしてください：

```bash
cd ../slack_history_fetcher
ruby slack_history_fetcher.rb -c CHANNEL_ID -s 2024-01-01 -e 2024-12-31
```

### 3. 分析の実行

エクスポートされたCSVファイルを使用して分析を実行：

```bash
# KPT分析
python kpt_analyzer.py path/to/slack_messages.csv

# ネガティブ分析
python negative_analyzer.py path/to/slack_messages.csv

# ワードクラウド生成
python wordcloud_generator.py path/to/slack_messages.csv
```

## �� 出力ファイル

分析結果は以下の形式で出力されます：

- **KPT分析**: `kpt_report.md`, `kpt_wordcloud.png`
- **ネガティブ分析**: `negative_report.md`, `negative_list.md`
- **ポジティブ分析**: `positive_list.md`
- **ワードクラウド**: `wordcloud.png`

## ⚠️ 注意事項

- 出力ファイルは`.gitignore`で除外されているため、リポジトリにコミットされません
- 日本語テキストの分析が前提となっています
- 大量のデータを処理する場合は時間がかかる場合があります

## 🔧 カスタマイズ

各スクリプトは独立して動作し、必要に応じて設定を変更できます。詳細は各スクリプトのコメントを参照してください。
