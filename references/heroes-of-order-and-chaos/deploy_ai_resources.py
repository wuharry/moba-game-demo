"""Apply only the clone's verified AI script archive, with original rollback copy."""
import hashlib
import json
from pathlib import Path
import shlex
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
ADB = ['E:/06_Apps/Android-SDK/platform-tools/adb.exe', '-s', 'RFCY700C8ZZ']
PKG = 'com.gameloft.android.ANMP.GloftHOHO'
DEST = 'files/offline-assets/script.bin'


def run(args):
    return subprocess.check_output(ADB + args, text=True, encoding='utf-8', timeout=60).strip()


def private(command):
    return run(['shell', 'run-as ' + PKG + ' sh -c ' + shlex.quote(command)])


def main():
    expected = json.loads((ROOT / 'trial/ai-resource-hashes.json').read_text())['script.bin']
    path = ROOT / 'trial/ai-assets/script.bin'
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected
    before = private('sha256sum ' + DEST).split()[0]
    known = json.loads((ROOT / 'trial/localized-resource-hashes.json').read_text())['script.bin']
    previous = ROOT / 'trial/ai-deployment.json'
    allowed = {known, expected}
    if previous.exists():
        allowed.add(json.loads(previous.read_text())['script_sha256'])
    assert before in allowed, 'Unexpected existing script archive; preserving it.'
    backup = ROOT / 'trial/pre-ai'
    backup.mkdir(exist_ok=True)
    for name in ('installed-verification.json', 'localized-resource-hashes.json'):
        target = backup / name
        if not target.exists():
            shutil.copy2(ROOT / 'trial' / name, target)
    target = backup / 'script.bin'
    if not target.exists():
        shutil.copy2(ROOT / 'original/assets/script.bin', target)
    temporary = '/data/local/tmp/hoc-ai-script-' + expected[:12] + '.bin'
    run(['shell', 'am', 'force-stop', PKG])
    run(['push', str(path), temporary])
    private('cp ' + temporary + ' ' + DEST + '.new')
    assert private('sha256sum ' + DEST + '.new').split()[0] == expected
    private('mv ' + DEST + '.new ' + DEST)
    assert private('sha256sum ' + DEST).split()[0] == expected
    report = {'package': PKG, 'before_script_sha256': before,
              'script_sha256': expected, 'installed_match': True,
              'rollback_archive': str(target), 'apk_changed': False}
    previous.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    print(run(['shell', 'am', 'start', '-W', '-n',
        PKG + '/com.gameloft.android.ANMP.GloftHOHM.MainActivity']))


if __name__ == '__main__':
    main()
