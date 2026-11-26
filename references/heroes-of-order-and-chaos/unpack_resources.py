from pathlib import Path
import io
import json
import zipfile

ROOT = Path(__file__).resolve().parent
for name in ('script.bin', 'tables.bin', 'menu.bin'):
    path = ROOT / 'original/assets' / name
    data = bytearray(path.read_bytes())
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        inventory = archive.infolist()
    for info in inventory:
        assert data[info.header_offset:info.header_offset + 4] == b'GBMP'
        data[info.header_offset:info.header_offset + 4] = b'PK\x03\x04'
    target = ROOT / 'analysis/unpacked' / name
    target.mkdir(parents=True, exist_ok=True)
    manifest = []
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for info in archive.infolist():
            destination = target / info.filename
            assert destination.resolve().is_relative_to(target.resolve())
            if info.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
                continue
            content = archive.read(info)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
            manifest.append({'path': info.filename, 'bytes': len(content), 'crc32': hex(info.CRC)})
    (ROOT / 'analysis' / (name + '.files.json')).write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(name, 'files:', len(manifest))
    for info in manifest[:35]:
        print(info)
