import re
from collections import defaultdict
from datetime import datetime

class NegativeListGenerator:
    def __init__(self):
        # ネガティブな表現のパターン
        self.negative_patterns = {
            '技術的な問題': [
                r'エラー', r'バグ', r'不具合', r'失敗', r'修正',
                r'対応', r'できない', r'起動できない', r'反映されない'
            ],
            'プロセス上の問題': [
                r'課題', r'改善', r'時間がかかる', r'遅れ', r'期限',
                r'スケジュール', r'予定', r'計画'
            ],
            'コミュニケーション': [
                r'申し訳', r'すみません', r'ごめん', r'すいません',
                r'確認', r'連絡', r'報告'
            ],
            'リスク・懸念': [
                r'リスク', r'懸念', r'問題', r'影響', r'不安',
                r'心配', r'難しい', r'複雑', r'大変'
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

    def generate_list(self, markdown_file, output_file):
        """ネガティブ発言リストを生成"""
        # テキストの抽出
        text = self.extract_text_from_markdown(markdown_file)
        
        # ネガティブな発言の抽出
        negative_comments = self.extract_negative_comments(text)
        
        # リストの生成
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('# ネガティブ発言リスト\n\n')
            
            for category, comments in negative_comments.items():
                if comments:  # コメントが存在する場合のみ出力
                    f.write(f'## {category}\n\n')
                    for i, comment in enumerate(comments, 1):
                        f.write(f'{i}. {comment["context"]}\n')
                    f.write('\n')

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Slack履歴からネガティブ発言リストを生成')
    parser.add_argument('input_file', help='入力マークダウンファイルのパス')
    parser.add_argument('--output', '-o', default='negative_list.md', help='出力ファイルのパス')
    args = parser.parse_args()
    
    generator = NegativeListGenerator()
    generator.generate_list(args.input_file, args.output)
    print(f'ネガティブ発言リストを生成しました: {args.output}')

if __name__ == '__main__':
    main() 