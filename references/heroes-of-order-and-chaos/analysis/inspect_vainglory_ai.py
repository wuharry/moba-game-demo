"""Read-only inspection of the user's previously backed-up Vainglory assets."""
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parent
SOURCE = Path('C:/Users/whw88/Downloads/Vainglory-zhTW-EnglishVoice-20261119/main.147219.original.obb')
matches = []
count = 0
sample = []
with zipfile.ZipFile(SOURCE) as archive:
    for info in archive.infolist():
        if info.is_dir() or info.file_size > 2000000:
            continue
        with archive.open(info) as stream:
            head = stream.read(4)
            if head != b'CFF0':
                continue
            data = head + stream.read()
        count += 1
        strings = re.findall(rb'[ -~]{5,}', data)
        related = [s.decode() for s in strings if any(t in s.lower() for t in (
            b'bot', b'difficulty', b'behavior', b'retreat', b'aggro', b'targetpriority'))]
        if len(sample) < 2:
            sample.append({'path': info.filename, 'header': data[:48].hex(),
                           'strings': [s.decode() for s in strings[:15]]})
        if related:
            matches.append({'path': info.filename, 'bytes': len(data), 'strings': related})
report = {'source': str(SOURCE), 'config_files_scanned': count, 'matches': matches, 'samples': sample}
(ROOT / 'vainglory-ai-reference.json').write_text(json.dumps(report, indent=2))
print('Config files:', count, 'matching files:', len(matches))
print(json.dumps(sample, indent=2))
for match in matches[:10]:
    print(match['path'], match['strings'][:30])
