"""Place the clone's verified public assets under its own application UID."""
from pathlib import Path
import json
import shlex
import subprocess

ROOT = Path(__file__).resolve().parent
PKG = 'com.gameloft.android.ANMP.GloftHOHO'
ADB = ['E:/06_Apps/Android-SDK/platform-tools/adb.exe', '-s', 'RFCY700C8ZZ']
SOURCE = '/sdcard/Android/data/' + PKG + '/files'
TARGET = '/data/user/0/' + PKG + '/files/offline-assets'
assert TARGET.startswith('/data/user/0/' + PKG + '/files/')
names = json.loads((ROOT / 'trial/asset-copy-list.json').read_text())
subprocess.run(ADB + ['shell', 'am', 'force-stop', PKG], check=True)


def as_app(command):
    return subprocess.check_output(ADB + ['shell', 'run-as ' + PKG + ' sh -c ' + shlex.quote(command)], text=True).strip()


as_app('mkdir -p ' + shlex.quote(TARGET + '/ui'))
for name in names:
    assert '..' not in name and not name.startswith('/')
    as_app('cp -n ' + shlex.quote(SOURCE + '/' + name) + ' ' + shlex.quote(TARGET + '/' + name))
expected = json.loads((ROOT / 'trial/verified-resource-hashes.json').read_text())
hashes = as_app('sha256sum ' + ' '.join(shlex.quote(TARGET + '/' + n) for n in expected))
actual = {line.split(None, 1)[1].strip().removeprefix(TARGET + '/'): line.split()[0] for line in hashes.splitlines()}
assert actual == expected, 'Private resource copy changed content'
pattern = '/storage/emulated/0/Android/data/' + PKG + '/files'
assert pattern in as_app('grep SDFolder shared_prefs/MainActivityPrefs.xml')
replacement = 's#' + pattern.replace('.', r'\.') + '#' + TARGET + '#g'
as_app('sed -i ' + shlex.quote(replacement) + ' shared_prefs/MainActivityPrefs.xml')
assert TARGET in as_app('grep SDFolder shared_prefs/MainActivityPrefs.xml')
print('PASS: private resource copy matches', len(actual), 'hashes; clone asset path updated.')
