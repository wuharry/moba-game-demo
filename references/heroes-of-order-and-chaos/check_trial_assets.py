"""Compare only the public resource allowlist, never account files."""
from pathlib import Path
import json
import shlex
import subprocess

ROOT = Path(__file__).resolve().parent
ADB = ['E:/06_Apps/Android-SDK/platform-tools/adb.exe', '-s', 'RFCY700C8ZZ']
names = json.loads((ROOT / 'trial/asset-copy-list.json').read_text())
names.remove('d_o_w_n_l_o_a_d_e_d.txt')  # mutable downloader bookkeeping, not game content
results = {}
for suffix in ('M', 'O'):
    directory = '/sdcard/Android/data/com.gameloft.android.ANMP.GloftHOH' + suffix + '/files/'
    command = 'sha256sum ' + ' '.join(shlex.quote(directory + n) for n in names)
    output = subprocess.check_output(ADB + ['shell', command], text=True)
    results[suffix] = {line.split(None, 1)[1].strip().removeprefix(directory): line.split()[0] for line in output.splitlines()}
assert results['M'] == results['O'], 'Copied resources differ from originals'
assert len(results['M']) == len(names)
(ROOT / 'trial/verified-resource-hashes.json').write_text(json.dumps(results['M'], indent=2))
print('PASS', len(names), 'resources match original app SHA-256 hashes.')
