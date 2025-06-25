import re
from collections import defaultdict
from datetime import datetime

class PositiveListGenerator:
    def __init__(self):
        # ポジティブな表現のパターン
        self.positive_patterns = {
            '成果・達成': [
                r'完了', r'達成', r'成功', r'できた', r'うまくいった', r'解決', r'進捗', r'リリース', r'対応済み', r'修正済み', r'改善済み'
            ],
            '感謝・賞賛': [
                r'ありがとうございます', r'感謝', r'助かります', r'素晴らしい', r'すごい', r'良い', r'ナイス', r'お疲れ様', r'助かった', r'嬉しい', r'最高'
            ],
            '前向きな姿勢': [
                r'頑張ります', r'やってみます', r'挑戦', r'前向き', r'大丈夫', r'問題ありません', r'OK', r'承知', r'了解', r'よろしくお願いします', r'引き続き', r'進めます'
            ]
        }

    def extract_text_from_markdown(self, markdown_file):
        """マークダウンファイルからテキストを抽出"""
        with open(markdown_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # コードブロック内のテキストを抽出
        text_blocks = re.findall(r'```\n(.*?)\n```', content, re.DOTALL)
        return '\n'.join(text_blocks)

    def extract_positive_comments(self, text):
        """ポジティブな発言を抽出"""
        positive_comments = defaultdict(list)
        
        for category, patterns in self.positive_patterns.items():
            for pattern in patterns:
                matches = re.finditer(pattern, text)
                for match in matches:
                    # マッチした部分の前後の文脈を取得
                    start = max(0, match.start() - 100)
                    end = min(len(text), match.end() + 100)
                    context = text[start:end].strip()
                    # 重複を避ける
                    if not any(existing['context'] == context for existing in positive_comments[category]):
                        positive_comments[category].append({
                            'pattern': pattern,
                            'context': context,
                            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                        })
        return positive_comments

    def generate_list(self, markdown_file, output_file):
        """ポジティブ発言リストを生成"""
        text = self.extract_text_from_markdown(markdown_file)
        positive_comments = self.extract_positive_comments(text)
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('# ポジティブ発言リスト\n\n')
            for category, comments in positive_comments.items():
                if comments:
                    f.write(f'## {category}\n\n')
                    for i, comment in enumerate(comments, 1):
                        f.write(f'{i}. {comment["context"]}\n')
                    f.write('\n')

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Slack履歴からポジティブ発言リストを生成')
    parser.add_argument('input_file', help='入力マークダウンファイルのパス')
    parser.add_argument('--output', '-o', default='positive_list.md', help='出力ファイルのパス')
    args = parser.parse_args()
    generator = PositiveListGenerator()
    generator.generate_list(args.input_file, args.output)
    print(f'ポジティブ発言リストを生成しました: {args.output}')

if __name__ == '__main__':
    main() 