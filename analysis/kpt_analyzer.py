import re
import MeCab
from collections import defaultdict
import japanize_matplotlib
import matplotlib.pyplot as plt
from datetime import datetime
import argparse

class KPTAnalyzer:
    def __init__(self):
        # MeCabの初期化
        self.mecab = MeCab.Tagger('-d /opt/homebrew/lib/mecab/dic/ipadic -r /opt/homebrew/etc/mecabrc')
        
        # キーワードパターンの定義
        self.patterns = {
            'keep': [
                r'良い', r'便利', r'助かった', r'成功', r'改善された',
                r'効率的', r'快適', r'使いやすい', r'分かりやすい'
            ],
            'problem': [
                r'課題', r'問題', r'改善', r'難しい', r'不便',
                r'時間がかかる', r'複雑', r'分かりにくい', r'エラー'
            ],
            'try': [
                r'提案', r'検討', r'試してみる', r'導入', r'実装',
                r'改善案', r'新しい', r'変更', r'最適化'
            ]
        }
        
        # 感情分析用の辞書
        self.sentiment_dict = {
            'ポジティブ': ['良い', '便利', '助かった', '成功', '改善'],
            'ネガティブ': ['悪い', '不便', '問題', '失敗', '課題']
        }

    def extract_text_from_markdown(self, markdown_file):
        """マークダウンファイルからテキストを抽出"""
        with open(markdown_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # コードブロック内のテキストを抽出
        text_blocks = re.findall(r'```\n(.*?)\n```', content, re.DOTALL)
        return '\n'.join(text_blocks)

    def analyze_sentiment(self, text):
        """感情分析を実行"""
        sentiment_scores = defaultdict(int)
        
        for sentiment, words in self.sentiment_dict.items():
            for word in words:
                sentiment_scores[sentiment] += len(re.findall(word, text))
        
        return sentiment_scores

    def extract_keywords(self, text):
        """キーワードを抽出"""
        node = self.mecab.parseToNode(text)
        keywords = defaultdict(int)
        
        while node:
            if node.feature.split(',')[0] == '名詞':
                keywords[node.surface] += 1
            node = node.next
        
        return dict(sorted(keywords.items(), key=lambda x: x[1], reverse=True)[:20])

    def classify_kpt(self, text):
        """KPTに分類"""
        kpt_results = defaultdict(list)
        
        for category, patterns in self.patterns.items():
            for pattern in patterns:
                matches = re.finditer(pattern, text)
                for match in matches:
                    # マッチした部分の前後の文脈を取得
                    start = max(0, match.start() - 50)
                    end = min(len(text), match.end() + 50)
                    context = text[start:end]
                    kpt_results[category].append(context)
        
        return kpt_results

    def generate_report(self, markdown_file, output_file):
        """分析レポートを生成"""
        # テキストの抽出
        text = self.extract_text_from_markdown(markdown_file)
        
        # 感情分析
        sentiment_scores = self.analyze_sentiment(text)
        
        # キーワード抽出
        keywords = self.extract_keywords(text)
        
        # KPT分類
        kpt_results = self.classify_kpt(text)
        
        # レポートの生成
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('# Slack履歴分析レポート\n\n')
            
            # 感情分析結果
            f.write('## 感情分析\n')
            for sentiment, score in sentiment_scores.items():
                f.write(f'- {sentiment}: {score}\n')
            f.write('\n')
            
            # キーワード
            f.write('## 主要キーワード\n')
            for word, count in keywords.items():
                f.write(f'- {word}: {count}回\n')
            f.write('\n')
            
            # KPT分析
            f.write('## KPT分析\n')
            for category in ['keep', 'problem', 'try']:
                f.write(f'### {category.upper()}\n')
                for context in kpt_results[category]:
                    f.write(f'- {context}\n')
                f.write('\n')

def main():
    parser = argparse.ArgumentParser(description='Slack履歴からKPT分析を実行')
    parser.add_argument('input_file', help='入力マークダウンファイルのパス')
    parser.add_argument('--output', '-o', default='kpt_report.md', help='出力ファイルのパス')
    args = parser.parse_args()
    
    analyzer = KPTAnalyzer()
    analyzer.generate_report(args.input_file, args.output)
    print(f'KPT分析レポートを生成しました: {args.output}')

if __name__ == '__main__':
    main() 