import re
import MeCab
from collections import defaultdict
import japanize_matplotlib
import matplotlib.pyplot as plt
from datetime import datetime
import argparse

class NegativeAnalyzer:
    def __init__(self):
        # MeCabの初期化
        self.mecab = MeCab.Tagger('-d /opt/homebrew/lib/mecab/dic/ipadic -r /opt/homebrew/etc/mecabrc')
        
        # ネガティブな表現のパターン
        self.negative_patterns = [
            r'問題', r'課題', r'難しい', r'不便', r'時間がかかる',
            r'複雑', r'分かりにくい', r'エラー', r'失敗', r'遅れ',
            r'懸念', r'リスク', r'改善', r'修正', r'対応',
            r'申し訳', r'すみません', r'ごめん', r'すいません',
            r'できない', r'難しい', r'困る', r'大変', r'厳しい'
        ]

    def extract_text_from_markdown(self, markdown_file):
        """マークダウンファイルからテキストを抽出"""
        with open(markdown_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # コードブロック内のテキストを抽出
        text_blocks = re.findall(r'```\n(.*?)\n```', content, re.DOTALL)
        return '\n'.join(text_blocks)

    def extract_negative_comments(self, text):
        """ネガティブな発言を抽出"""
        negative_comments = []
        
        for pattern in self.negative_patterns:
            matches = re.finditer(pattern, text)
            for match in matches:
                # マッチした部分の前後の文脈を取得
                start = max(0, match.start() - 100)
                end = min(len(text), match.end() + 100)
                context = text[start:end]
                negative_comments.append({
                    'pattern': pattern,
                    'context': context,
                    'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
        
        return negative_comments

    def analyze_negative_trends(self, negative_comments):
        """ネガティブな発言の傾向を分析"""
        pattern_counts = defaultdict(int)
        for comment in negative_comments:
            pattern_counts[comment['pattern']] += 1
        
        return dict(sorted(pattern_counts.items(), key=lambda x: x[1], reverse=True))

    def generate_report(self, markdown_file, output_file):
        """分析レポートを生成"""
        # テキストの抽出
        text = self.extract_text_from_markdown(markdown_file)
        
        # ネガティブな発言の抽出
        negative_comments = self.extract_negative_comments(text)
        
        # 傾向分析
        negative_trends = self.analyze_negative_trends(negative_comments)
        
        # レポートの生成
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('# ネガティブ発言分析レポート\n\n')
            
            # 傾向分析結果
            f.write('## ネガティブ表現の傾向\n')
            for pattern, count in negative_trends.items():
                f.write(f'- {pattern}: {count}回\n')
            f.write('\n')
            
            # 詳細な発言内容
            f.write('## ネガティブ発言の詳細\n')
            for comment in negative_comments:
                f.write(f'### {comment["pattern"]} ({comment["timestamp"]})\n')
                f.write(f'{comment["context"]}\n\n')

def main():
    parser = argparse.ArgumentParser(description='Slack履歴からネガティブ発言を分析')
    parser.add_argument('input_file', help='入力マークダウンファイルのパス')
    parser.add_argument('--output', '-o', default='negative_report.md', help='出力ファイルのパス')
    args = parser.parse_args()
    
    analyzer = NegativeAnalyzer()
    analyzer.generate_report(args.input_file, args.output)
    print(f'ネガティブ発言分析レポートを生成しました: {args.output}')

if __name__ == '__main__':
    main() 