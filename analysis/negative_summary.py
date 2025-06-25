import re
from collections import defaultdict
from datetime import datetime

class NegativeSummaryGenerator:
    def __init__(self):
        # ネガティブな表現のパターン
        self.negative_patterns = {
            '技術的な問題': [
                r'エラー', r'バグ', r'不具合', r'失敗', r'修正',
                r'対応', r'できない', r'起動できない', r'反映されない',
                r'動作しない', r'クラッシュ', r'タイムアウト'
            ],
            'プロセス上の問題': [
                r'課題', r'改善', r'時間がかかる', r'遅れ', r'期限',
                r'スケジュール', r'予定', r'計画', r'遅延', r'延期',
                r'キャンセル', r'中止'
            ],
            'コミュニケーション': [
                r'申し訳', r'すみません', r'ごめん', r'すいません',
                r'確認', r'連絡', r'報告', r'誤解', r'認識違い',
                r'伝わっていない', r'不明確'
            ],
            'リスク・懸念': [
                r'リスク', r'懸念', r'問題', r'影響', r'不安',
                r'心配', r'難しい', r'複雑', r'大変', r'危険',
                r'注意', r'警告'
            ]
        }

    def extract_text_from_markdown(self, markdown_file):
        """マークダウンファイルからテキストを抽出"""
        with open(markdown_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # コードブロック内のテキストを抽出
        text_blocks = re.findall(r'```\n(.*?)\n```', content, re.DOTALL)
        return '\n'.join(text_blocks)

    def extract_negative_comments(self, text):
        """ネガティブな発言を抽出"""
        negative_comments = defaultdict(list)
        
        for category, patterns in self.negative_patterns.items():
            for pattern in patterns:
                matches = re.finditer(pattern, text)
                for match in matches:
                    # マッチした部分の前後の文脈を取得
                    start = max(0, match.start() - 100)
                    end = min(len(text), match.end() + 100)
                    context = text[start:end].strip()
                    
                    # 重複を避けるため、既存のコメントと比較
                    if not any(existing['context'] == context for existing in negative_comments[category]):
                        negative_comments[category].append({
                            'pattern': pattern,
                            'context': context,
                            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                        })
        
        return negative_comments

    def generate_summary(self, markdown_file, output_file):
        """ネガティブ発言の要約を生成"""
        # テキストの抽出
        text = self.extract_text_from_markdown(markdown_file)
        
        # ネガティブな発言の抽出
        negative_comments = self.extract_negative_comments(text)
        
        # 要約の生成
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('# ネガティブ発言の要約\n\n')
            
            # 全体の概要
            total_comments = sum(len(comments) for comments in negative_comments.values())
            f.write(f'## 全体の概要\n')
            f.write(f'総ネガティブ発言数: {total_comments}件\n\n')
            
            # カテゴリ別の要約
            for category, comments in negative_comments.items():
                if comments:  # コメントが存在する場合のみ出力
                    f.write(f'## {category}\n')
                    f.write(f'発言数: {len(comments)}件\n\n')
                    
                    # 主要な発言の抽出（各カテゴリ最大5件）
                    f.write('### 主要な発言\n')
                    for i, comment in enumerate(comments[:5], 1):
                        f.write(f'{i}. {comment["context"]}\n')
                    f.write('\n')
                    
                    # パターンの出現頻度
                    pattern_counts = defaultdict(int)
                    for comment in comments:
                        pattern_counts[comment['pattern']] += 1
                    
                    f.write('### 頻出パターン\n')
                    for pattern, count in sorted(pattern_counts.items(), key=lambda x: x[1], reverse=True)[:3]:
                        f.write(f'- {pattern}: {count}回\n')
                    f.write('\n')

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Slack履歴からネガティブ発言を要約')
    parser.add_argument('input_file', help='入力マークダウンファイルのパス')
    parser.add_argument('--output', '-o', default='negative_summary.md', help='出力ファイルのパス')
    args = parser.parse_args()
    
    generator = NegativeSummaryGenerator()
    generator.generate_summary(args.input_file, args.output)
    print(f'ネガティブ発言の要約を生成しました: {args.output}')

if __name__ == '__main__':
    main() 