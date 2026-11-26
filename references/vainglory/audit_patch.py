"""Audit parsed text, dynamic values, resource hashes and actual CJK glyphs."""
from pathlib import Path
from collections import Counter
from functools import lru_cache
import base64
import hashlib
import json
import re
import struct
from PIL import ImageFont

ROOT = Path(__file__).resolve().parent
pattern = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";', re.M)


def rows(data):
    decoded = base64.b64decode(data, validate=True).decode('utf-8-sig')
    assert not pattern.sub('', decoded).strip()
    result = pattern.findall(decoded)
    assert len(result) == len(dict(result)) == 7329
    return dict(result)


manifest = json.loads((ROOT / 'patch-manifest.json').read_text(encoding='utf-8'))
assert len(manifest['files']) == 39
for item in manifest['files']:
    for folder, key in [('patch', 'patched_sha256'), ('restore', 'original_sha256')]:
        assert hashlib.sha256((ROOT / folder / 'Data' / item['path']).read_bytes()).hexdigest() == item[key]
text_file = '7E/7ED4F1146624D2D991A07272993B26C4'
translated = rows((ROOT / 'patch/Data' / text_file).read_bytes())
english = rows((ROOT / 'restore/Data' / text_file).read_bytes())
assert translated.keys() == english.keys()
blanks = [key for key, value in english.items() if value and not translated[key]]
assert len(blanks) == 4 and all(key.startswith('STORE_ITEM_TEMPLATE_') for key in blanks)
additions = json.loads((ROOT / 'translation-additions.json').read_text(encoding='utf-8'))
markers = re.compile(r'\[[^\[\]]+\]|%(?:\d+\$)?[-+0-9.]*[sdif]')
for key, value in additions.items():
    assert translated[key] == value
    assert Counter(markers.findall(value)) == Counter(markers.findall(english[key])), key
assert '[Chargetime]秒' not in translated['HERO_ABILITY_AMAEL_A_DESC']
assert '[EMPOWER_DURATION]秒' not in translated['HERO_ABILITY_LEO_C_DESC']
characters = sorted({char for value in translated.values() for char in value
                     if ('\u3000' <= char <= '\u9fff' or '\uff00' <= char <= '\uffef')
                     and not char.isspace()})


@lru_cache(None)
def missing_characters(reference):
    font = ImageFont.truetype(str(ROOT / 'font-inspect' / reference), 32)
    missing = font.getmask('\U0010ffff')
    signature = (missing.size, bytes(missing))
    return {char for char in characters if (lambda m: (m.size, bytes(m)))(font.getmask(char)) == signature}


failures = []
fonts = 0
for item in manifest['files'][1:]:
    data = (ROOT / 'patch/Data' / item['path']).read_bytes()
    count = struct.unpack_from('<I', data)[0]
    assert count in (6, 7) and len(data) == 52 + 111 * count and data[18] == 2
    records = []
    for index in range(count):
        start = 52 + 111 * index
        reference = data[start + 14:start + 46].decode('ascii')
        ranges = [struct.unpack_from('<HH', data, start + 47 + 4 * i) for i in range(16)]
        records.append((reference, ranges))
    for char in characters:
        reference = next((ref for ref, ranges in records
                          if any(first <= ord(char) <= last for first, last in ranges if last)), None)
        if reference is None or char in missing_characters(reference):
            failures.append({'path': item['path'], 'char': char, 'font': reference})
    fonts += 1
assert not failures, failures[:20]
report = {'revision': manifest['patch_revision'], 'resource_hashes_verified': 78,
          'translation_entries': 7329, 'completed_entries_with_preserved_markers': len(additions),
          'player_facing_missing_translations': 0, 'excluded_internal_templates': blanks,
          'font_resources_checked': fonts, 'unique_cjk_characters_checked': len(characters),
          'missing_glyph_routes': failures}
(ROOT / 'final-resource-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
