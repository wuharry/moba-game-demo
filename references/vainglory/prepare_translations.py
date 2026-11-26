"""Fill absent hero/UI translations from this version's existing CN resources.

Conversion uses locally saved OpenCC dictionaries (Apache-2.0), then a reviewed
override file. No network service receives game data. The output is reviewable.
"""
from pathlib import Path
import base64
from collections import Counter
import json
import re

ROOT = Path(__file__).resolve().parent
PATTERN = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";', re.M)
MARKERS = re.compile(r'\[[^\[\]]+\]|%(?:\d+\$)?[-+0-9.]*[sdif]')


def read_rows(name):
    raw = base64.b64decode((ROOT / (name + '.strings.original')).read_bytes())
    return dict(PATTERN.findall(raw.decode('utf-8-sig')))


def dictionary(*names):
    tree = {}
    for name in names:
        for line in (ROOT / 'conversion-dictionaries' / name).read_text(encoding='utf-8-sig').splitlines():
            if not line or line.startswith('#'):
                continue
            source, targets = line.split('\t', 1)
            target = targets.split(' ')[0]
            node = tree
            for char in source:
                node = node.setdefault(char, {})
            node[''] = target
    return tree


def replace_longest(text, tree):
    output, pos = [], 0
    while pos < len(text):
        node, end, match = tree, pos, None
        while end < len(text) and text[end] in node:
            node = node[text[end]]
            end += 1
            if '' in node:
                match = (end, node[''])
        if match:
            pos, translated = match
            output.append(translated)
        else:
            output.append(text[pos])
            pos += 1
    return ''.join(output)


def main():
    en, tw, cn = (read_rows(x) for x in ['english', 'localization_zh_TW', 'localization_zh_CN'])
    standard = dictionary('STCharacters.txt', 'STPhrases.txt')
    taiwan = dictionary('TWVariants.txt', 'TWPhrases.txt')
    overrides = json.loads((ROOT / 'translation-overrides.json').read_text(encoding='utf-8'))
    replacements = {
        '普通攻擊': '基本攻擊', '物理強度': '武器力量', '法術強度': '水晶力量',
        '物理傷害': '武器傷害', '魔法傷害': '水晶傷害', '法術傷害': '水晶傷害',
        '大招': '究極技能', '摔跤': '摔角',
        '將是他': '會使他', '對面訪': '對前方', '想目標': '向目標',
        '自動回覆': '自動恢復', '重新整理': '重置', '遠端': '遠距',
        '大亂斗': '大亂鬥', '和絃': '和弦', 'TIP #': '訣竅 #',
        '星樂斯': '星樂絲', '福徹斯': '佛特', '格溫': '歌雯',
        '凱思卓': '克絲翠', '基妮': '柯奈', '瑪格納斯': '瑪努斯',
        '費恩': '芬恩', '西弗爾': '銀釘', '托尼': '多尼',
    }
    prefixes = ('CHAR_INFO_', 'HERO_ABILITY_', 'RECOMMENDED_BUILD_',
                'TALENT_NAME_', 'TALENT_DESC_', 'CHAR_THEME_NAME_')
    reviewed = []
    for key, english in en.items():
        if key.startswith('STORE_ITEM_TEMPLATE_'):
            continue  # Internal authoring examples, not player-facing item text.
        previous, chinese = tw[key], cn.get(key, '')
        blank = bool(english) and not previous
        untranslated = (key.startswith(prefixes) and not re.search('[\u3400-\u9fff]', previous)
                        and re.search('[\u3400-\u9fff]', chinese))
        if not (blank or untranslated):
            continue
        translated = replace_longest(replace_longest(chinese, standard), taiwan)
        for source, target in replacements.items():
            translated = translated.replace(source, target)
        if 'barrier' in english.lower():
            translated = translated.replace('護盾', '屏障')
        translated = overrides.get(key, translated)
        if key.endswith('_NAME'):
            translated = translated.strip()
        assert translated, ('Unfilled translation', key)
        assert Counter(MARKERS.findall(translated)) == Counter(MARKERS.findall(english)), ('Changed markers', key)
        assert not re.search(r'(?<!\\)"', translated), ('Unescaped quote', key)
        reviewed.append({'key': key, 'previous': previous, 'english': english,
                         'simplified': chinese, 'traditional': translated})
    additions = {item['key']: item['traditional'] for item in reviewed}
    (ROOT / 'translation-additions.json').write_text(json.dumps(additions, ensure_ascii=False, indent=2), encoding='utf-8')
    (ROOT / 'translation-review.json').write_text(json.dumps(reviewed, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Prepared', len(additions), 'translations; every English replacement marker was preserved.')


if __name__ == '__main__':
    main()
