from pathlib import Path
import hashlib
import json
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parent
apk = ROOT / 'original/HeroesOfOrderAndChaos-3.6.5a-36523.apk'
out = ROOT / 'analysis'
with zipfile.ZipFile(apk) as archive:
    inventory = [{'path': x.filename, 'bytes': x.file_size} for x in archive.infolist()]
    (out / 'apk-inventory.json').write_text(json.dumps(inventory, indent=2), encoding='utf-8')
    print('APK SHA256:', hashlib.sha256(apk.read_bytes()).hexdigest())
    for item in inventory:
        name = item['path']
        if name.startswith('lib/arm64-v8a/') or name.endswith('.dex'):
            destination = out / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            data = archive.read(name)
            destination.write_bytes(data)
            print('Native/DEX:', name, len(data))
        elif name.startswith('assets/'):
            print('Asset:', name, item['bytes'])
for path in sorted((ROOT / 'original/assets').iterdir()):
    data = path.read_bytes()
    print('External:', path.name, len(data), 'magic:', data[:32].hex(), 'ZIP:', zipfile.is_zipfile(path))
    if path.suffix in ('.txt', '.conf'):
        print(data.decode('utf-8', errors='replace'))


def elf_sections(data):
    assert data[:6] == b'\x7fELF\x02\x01'
    start = struct.unpack_from('<Q', data, 40)[0]
    width, count, names_index = struct.unpack_from('<HHH', data, 58)
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, start + width * i) for i in range(count)]
    name_table = sections[names_index]
    names = data[name_table[4]:name_table[4] + name_table[5]]
    return [(names[s[0]:].split(b'\0', 1)[0].decode(), s) for s in sections]


terms = re.compile(r'offline|standalone|singleplayer|single_player|localgame|training|tutorial|fakeaccount|serverselect|selectserver|login|signin|unlock|botgame', re.I)
for path in (out / 'lib/arm64-v8a').glob('*.so'):
    data = path.read_bytes()
    sections = elf_sections(data)
    symbols = []
    for name, section in sections:
        if name not in ('.dynsym', '.symtab'):
            continue
        string_section = sections[section[6]][1]
        strings = data[string_section[4]:string_section[4] + string_section[5]]
        for offset in range(section[4], section[4] + section[5], section[9]):
            name_offset, info, other, index, value, size = struct.unpack_from('<IBBHQQ', data, offset)
            name = strings[name_offset:strings.find(b'\0', name_offset)].decode(errors='replace')
            if name:
                symbols.append({'name': name, 'address': hex(value), 'size': size, 'section': index})
    (out / (path.name + '.symbols.json')).write_text(json.dumps(symbols, indent=2), encoding='utf-8')
    matching = [item for item in symbols if terms.search(item['name'])]
    print('ELF:', path.name, 'symbols:', len(symbols), 'matching:', len(matching))
    (out / (path.name + '.offline-symbols.json')).write_text(json.dumps(matching, indent=2), encoding='utf-8')
    strings = [{'offset': hex(m.start()), 'text': m.group().decode('ascii')}
               for m in re.finditer(rb'[\x20-\x7e]{6,}', data)
               if terms.search(m.group().decode('ascii')) and len(m.group()) < 400]
    (out / (path.name + '.offline-strings.json')).write_text(json.dumps(strings, indent=2), encoding='utf-8')
    for item in matching[:60]:
        print(item)
