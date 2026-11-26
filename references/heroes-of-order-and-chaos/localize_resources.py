"""Repair the clone's Traditional Chinese tables without touching original assets.

The old item table has 370 Arabic strings whose original Traditional Chinese
translations are in the same-ID Thai table. Copy only those rows. Fill the other
missing Chinese strings from the original simplified table using local OpenCC
data (Apache-2.0); never replace already translated Traditional Chinese rows.
"""
from collections import Counter
from copy import copy
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parent
CJK = re.compile(r'[\u3400-\u9fff]')
ARABIC = re.compile(r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]')
FORMAT = re.compile(r'%(?:\d+\$)?[-+0-9.*]*[sdifuoxXegc]|\{\d+\}')


def dictionary(*names):
    tree = {}
    for name in names:
        for line in (ROOT / 'conversion-dictionaries' / name).read_text(encoding='utf-8-sig').splitlines():
            if not line or line.startswith('#'):
                continue
            source, targets = line.split('\t', 1)
            node = tree
            for char in source:
                node = node.setdefault(char, {})
            node[''] = targets.split(' ')[0]
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


def open_archive(raw):
    data = bytearray(raw)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        entries = archive.infolist()
    for entry in entries:
        pos = entry.header_offset
        assert data[pos:pos + 4] == b'GBMP', entry.filename
        data[pos:pos + 4] = b'PK\x03\x04'
    return zipfile.ZipFile(io.BytesIO(data))


def string_rows(data):
    assert data[:8] == b'FTABLE\0\0'
    _, count, fields, _, fmt, start, row_size, string_start, reserved = struct.unpack_from('<9I', data, 8)
    assert fields == 2 and row_size == 10 and reserved == 0
    assert data[fmt:start] == b'us\0'
    rows = {}
    for index in range(count):
        pos = start + index * row_size
        key, offset, size = struct.unpack_from('<IIH', data, pos)
        assert key not in rows and string_start <= offset <= len(data) and offset + size <= len(data)
        raw = data[offset:offset + size]
        text = raw.decode('utf-8').rstrip('\0')
        tail = raw[len(text.encode('utf-8')):]
        assert not tail.strip(b'\0')
        rows[key] = (text, pos, tail)
    return rows


def main():
    standard = dictionary('STCharacters.txt', 'STPhrases.txt')
    taiwan = dictionary('TWVariants.txt', 'TWPhrases.txt')
    source = ROOT / 'original/assets/tables.bin'
    output_dir = ROOT / 'trial/localized-assets'
    output_dir.mkdir(parents=True, exist_ok=True)
    changes, replacements = [], {}
    with open_archive(source.read_bytes()) as archive:
        for stem in ('String_Item_HOC', 'String_Spell'):
            name = 'tables/' + stem + '_tw.tbl'
            original = archive.read(name)
            rows = string_rows(original)
            cn = string_rows(archive.read('tables/' + stem + '_zh.tbl'))
            en = string_rows(archive.read('tables/' + stem + '_en.tbl'))
            alternate = string_rows(archive.read('tables/' + stem + '_th.tbl')) if stem == 'String_Item_HOC' else {}
            assert rows.keys() == cn.keys() == en.keys()
            patched = bytearray(original)
            changed = {}
            for key, (previous, pos, tail) in rows.items():
                if ARABIC.search(previous):
                    translated = alternate[key][0]
                    origin = stem + '_th.tbl (original Traditional Chinese)'
                    assert CJK.search(translated) and not ARABIC.search(translated), (stem, key)
                elif not CJK.search(previous) and CJK.search(cn[key][0]):
                    translated = replace_longest(replace_longest(cn[key][0], standard), taiwan)
                    origin = stem + '_zh.tbl (OpenCC Traditional conversion)'
                    assert Counter(FORMAT.findall(translated)) == Counter(FORMAT.findall(cn[key][0])), (stem, key)
                else:
                    continue
                assert translated and not ARABIC.search(translated)
                assert Counter(FORMAT.findall(translated)) == Counter(FORMAT.findall(en[key][0])), (stem, key, translated, en[key][0])
                encoded = translated.encode('utf-8') + tail
                assert len(encoded) <= 65535
                struct.pack_into('<IH', patched, pos + 4, len(patched), len(encoded))
                patched.extend(encoded)
                changed[key] = translated
                changes.append({'table': name, 'id': key, 'previous': previous,
                                'english': en[key][0], 'traditional': translated, 'source': origin})
            reparsed = string_rows(patched)
            assert reparsed.keys() == rows.keys()
            for key, (previous, _, _) in rows.items():
                assert reparsed[key][0] == changed.get(key, previous)
            assert not any(ARABIC.search(row[0]) for row in reparsed.values())
            replacements[name] = bytes(patched)

        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as target:
            target.comment = archive.comment
            for entry in archive.infolist():
                target.writestr(copy(entry), replacements.get(entry.filename, archive.read(entry)))
        packed = bytearray(buffer.getvalue())
        with zipfile.ZipFile(io.BytesIO(packed)) as result:
            assert result.testzip() is None
            assert result.namelist() == archive.namelist()
            entries = result.infolist()
            for entry in entries:
                assert result.read(entry) == replacements.get(entry.filename, archive.read(entry.filename))
        for entry in entries:
            pos = entry.header_offset
            assert packed[pos:pos + 4] == b'PK\x03\x04'
            packed[pos:pos + 4] = b'GBMP'
        with open_archive(packed) as result:
            assert result.testzip() is None
            for name, expected in replacements.items():
                assert result.read(name) == expected

    target_path = output_dir / 'tables.bin'
    target_path.write_bytes(packed)
    expected = json.loads((ROOT / 'trial/verified-resource-hashes.json').read_text())
    assert hashlib.sha256(source.read_bytes()).hexdigest() == expected['tables.bin']
    expected['tables.bin'] = hashlib.sha256(packed).hexdigest()
    (ROOT / 'trial/localized-resource-hashes.json').write_text(json.dumps(expected, indent=2), encoding='utf-8')
    (ROOT / 'trial/localization-review.json').write_text(json.dumps(changes, ensure_ascii=False, indent=2), encoding='utf-8')
    counts = dict(Counter(item['table'] for item in changes))
    evidence = {'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'output_sha256': expected['tables.bin'], 'changed_tables': counts,
                'recovered_original_traditional': sum('original Traditional' in c['source'] for c in changes),
                'archive_entries': len(entries), 'unchanged_entries': len(entries) - len(replacements),
                'crc_check': 'PASS', 'format_markers': 'PASS', 'arabic_remaining_in_patched_tables': 0}
    (ROOT / 'trial/localization-verification.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps(evidence, ensure_ascii=False))


if __name__ == '__main__':
    main()
