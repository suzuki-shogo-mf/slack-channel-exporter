import re
from wordcloud import WordCloud
import matplotlib.pyplot as plt
import japanize_matplotlib
import argparse
import MeCab

def extract_text_from_markdown(markdown_file):
    """マークダウンファイルからテキストを抽出"""
    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # コードブロック内のテキストを抽出
    text_blocks = re.findall(r'```\n(.*?)\n```', content, re.DOTALL)
    return '\n'.join(text_blocks)

def preprocess_text(text):
    """テキストの前処理"""
    # メンション、URL、絵文字などを削除
    text = re.sub(r'<@[A-Z0-9]+>', '', text)  # メンション
    text = re.sub(r'https?://\S+', '', text)  # URL
    text = re.sub(r':[a-z_]+:', '', text)     # 絵文字
    
    # MeCabで形態素解析（設定ファイルと辞書のパスを明示的に指定）
    mecab = MeCab.Tagger('-d /opt/homebrew/lib/mecab/dic/ipadic -r /opt/homebrew/etc/mecabrc')
    node = mecab.parseToNode(text)
    
    # 名詞のみを抽出
    words = []
    while node:
        if node.feature.split(',')[0] == '名詞':
            words.append(node.surface)
        node = node.next
    
    return ' '.join(words)

def generate_wordcloud(text, output_file):
    """ワードクラウドを生成"""
    # フォントパスの設定（Macの場合）
    font_path = '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc'
    
    # ワードクラウドの生成
    wordcloud = WordCloud(
        font_path=font_path,
        width=1200,
        height=800,
        background_color='white',
        max_words=200,
        min_font_size=10,
        max_font_size=100,
        random_state=42,
        collocations=False  # 重複を許可
    )
    
    # テキストからワードクラウドを生成
    wordcloud.generate(text)
    
    # プロットの設定
    plt.figure(figsize=(15, 10))
    plt.imshow(wordcloud, interpolation='bilinear')
    plt.axis('off')
    
    # 保存
    plt.savefig(output_file, bbox_inches='tight', dpi=300)
    plt.close()

def main():
    parser = argparse.ArgumentParser(description='Slack履歴からワードクラウドを生成')
    parser.add_argument('input_file', help='入力マークダウンファイルのパス')
    parser.add_argument('--output', '-o', default='wordcloud.png', help='出力ファイルのパス')
    args = parser.parse_args()
    
    # テキストの抽出と前処理
    text = extract_text_from_markdown(args.input_file)
    processed_text = preprocess_text(text)
    
    # ワードクラウドの生成
    generate_wordcloud(processed_text, args.output)
    print(f'ワードクラウドを生成しました: {args.output}')

if __name__ == '__main__':
    main() 