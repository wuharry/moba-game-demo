"""Copy public game assets into the separate prototype app, never account data."""
from pathlib import Path
import json
import re
import shlex
import subprocess

ROOT = Path(__file__).resolve().parent
ADB = ['E:/06_Apps/Android-SDK/platform-tools/adb.exe', '-s', 'RFCY700C8ZZ']
OLD = '/sdcard/Android/data/com.gameloft.android.ANMP.GloftHOHM/files'
NEW = '/sdcard/Android/data/com.gameloft.android.ANMP.GloftHOHO/files'
PACKAGE = 'com.gameloft.android.ANMP.GloftHOHO'
assert OLD != NEW and NEW.endswith(PACKAGE + '/files')


def shell(command):
    return subprocess.check_output(ADB + ['shell', command], text=True).strip()


assert shell('pm path ' + PACKAGE).startswith('package:'), 'Install the separate prototype first'
names = shell('ls -1 ' + shlex.quote(OLD)).splitlines()
allowed = {'res.bin', 'res_t.bin', 'rift.bin', 'vault.bin', '3v3_desert.bin', 'sounds.bin',
           'model_phy.bin', 'hoc.bin', 'hoc.txt', 'script.bin', 'tables.bin', 'menu.bin',
           'game_Android.conf', 'color_corrector.conf', 'd_o_w_n_l_o_a_d_e_d.txt'}
selected = sorted(n for n in names if n in allowed or re.fullmatch(r'hero_[a-z0-9_]+\.bin', n))
assert len(selected) > 60
shell('mkdir -p ' + shlex.quote(NEW) + ' ' + shlex.quote(NEW + '/ui'))
for name in selected:
    shell('cp -n ' + shlex.quote(OLD + '/' + name) + ' ' + shlex.quote(NEW + '/' + name))
font_names = shell('ls -1 ' + shlex.quote(OLD + '/ui')).splitlines()
for name in font_names:
    assert re.fullmatch(r'[A-Za-z0-9.\-_]+\.(ttf|otf)', name), name
    shell('cp -n ' + shlex.quote(OLD + '/ui/' + name) + ' ' + shlex.quote(NEW + '/ui/' + name))
(ROOT / 'trial/asset-copy-list.json').write_text(json.dumps(selected + ['ui/' + n for n in font_names], indent=2))
for permission in ('android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE'):
    subprocess.run(ADB + ['shell', 'pm', 'grant', PACKAGE, permission], check=True)
print('Copied', len(selected), 'game resources and', len(font_names), 'fonts; no account data.')
