"""One-time upgrade from the previously verified resource patch to v2."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent
ADB = 'E:/06_Apps/Android-SDK/platform-tools/adb.exe'
PACKAGE = 'com.superevilmegacorp.game'
REMOTE = '/sdcard/Android/data/' + PACKAGE + '/files/Data/'


def adb(*args):
    result = subprocess.run([ADB, '-s', 'RFCY700C8ZZ', *args], capture_output=True,
                            text=True, encoding='utf-8', errors='replace', timeout=90)
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    archive_name = sys.argv[1] if len(sys.argv) == 2 else 'trial-v1-resource-backup.zip'
    assert archive_name in ('trial-v1-resource-backup.zip', 'trial-v2-resource-backup.zip')
    current = json.loads((ROOT / 'patch-manifest.json').read_text(encoding='utf-8'))
    assert current['version_code'] == 147219 and current['package'] == PACKAGE
    assert current['completed_translations'] == 312
    version = re.search(r'\bversionCode=(\d+)\b', adb('shell', 'dumpsys', 'package', PACKAGE))
    assert version and version.group(1) == '147219'
    files = {item['path']: item for item in current['files']}
    assert len(files) == 39
    prior = {}
    with zipfile.ZipFile(ROOT / archive_name) as archive:
        previous = json.loads(archive.read('patch-manifest.json'))
        assert {item['path'] for item in previous['files']} == set(files)
        for item in previous['files']:
            path = item['path']
            assert re.fullmatch(r'[A-F0-9]{2}/[A-F0-9]{32}', path)
            data = archive.read('patch/Data/' + path)
            assert sha(data) == item['patched_sha256']
            prior[path] = data
    for path, item in files.items():
        assert sha((ROOT / 'patch/Data' / path).read_bytes()) == item['patched_sha256']
        assert sha((ROOT / 'restore/Data' / path).read_bytes()) == item['original_sha256']

    def hashes():
        lines = adb('shell', 'sha256sum', *(REMOTE + path for path in files)).splitlines()
        result = {name.removeprefix(REMOTE): digest for digest, name in
                  (line.split(maxsplit=1) for line in lines)}
        assert set(result) == set(files)
        return result

    before = hashes()
    backup = ROOT / (Path(archive_name).stem + '-verified-device-resources')
    for path, item in files.items():
        assert before[path] in (sha(prior[path]), item['original_sha256'], item['patched_sha256']), path
        if before[path] == sha(prior[path]):
            data = prior[path]
        elif before[path] == item['original_sha256']:
            data = (ROOT / 'restore/Data' / path).read_bytes()
        else:
            data = (ROOT / 'patch/Data' / path).read_bytes()
        destination = backup / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    changed = [path for path, item in files.items() if before[path] != item['patched_sha256']]
    print('Verified existing files:', len(files), '; files to update:', len(changed), flush=True)
    if changed:
        adb('shell', 'am', 'force-stop', PACKAGE)
        attempted = []
        try:
            for path in changed:
                attempted.append(path)
                adb('push', str(ROOT / 'patch/Data' / path), REMOTE + path)
            after = hashes()
            assert all(after[path] == item['patched_sha256'] for path, item in files.items())
        except Exception:
            failures = []
            for path in attempted:
                try:
                    adb('push', str(backup / path), REMOTE + path)
                except Exception:
                    failures.append(path)
            print('Rollback write failures:', failures, flush=True)
            if not failures:
                assert hashes() == before, 'Rollback verification failed'
            raise
        adb('shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
    receipt = {'time': datetime.datetime.now().astimezone().isoformat(),
               'verified_resources': 39, 'updated_resources': len(changed),
               'completed_translations': 312}
    (ROOT / ('upgrade-from-' + Path(archive_name).stem + '-receipt.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print('Current patch applied and all 39 resource hashes verified; game launched.', flush=True)


if __name__ == '__main__':
    main()
