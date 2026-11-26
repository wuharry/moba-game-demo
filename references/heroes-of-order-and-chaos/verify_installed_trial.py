"""Read-only integrity checks for the installed, localized offline clone.

This verifies package/resources, not gameplay. Device screenshots and explicit
manual test results belong in gameplay-verification.json separately.
"""
from datetime import datetime, timezone
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import zipfile

import native_probe as native

ROOT = Path(__file__).resolve().parent
PKG = 'com.gameloft.android.ANMP.GloftHOHO'
ADB = ['E:/06_Apps/Android-SDK/platform-tools/adb.exe', '-s', 'RFCY700C8ZZ']
TARGET = '/data/user/0/' + PKG + '/files/offline-assets'


def run(args):
    return subprocess.check_output(args, text=True, encoding='utf-8', timeout=60).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--resource-manifest', default='trial/localized-resource-hashes.json')
    parser.add_argument('--apk', default='trial/HOC-Offline-Prototype.apk')
    parser.add_argument('--patches', default='trial/native-patches.json')
    parser.add_argument('--report', default='trial/installed-verification.json')
    args = parser.parse_args()
    apk = ROOT / args.apk
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None, 'APK CRC failure'
        actual_native = archive.read('lib/arm64-v8a/libAndroid.so')
    patches = json.loads((ROOT / args.patches).read_text())
    expected_native = bytearray(native.DATA)
    spans = []
    for patch in patches:
        va = int(patch['address'], 16)
        before, after = bytes.fromhex(patch['before']), bytes.fromhex(patch['after'])
        offset = native.offset(va)
        assert len(before) == len(after)
        assert expected_native[offset:offset + len(before)] == before, patch['symbol']
        expected_native[offset:offset + len(after)] = after
        spans.append((va, va + len(after)))
    spans.sort()
    assert all(a[1] <= b[0] for a, b in zip(spans, spans[1:])), 'Overlapping native edits'
    assert expected_native == actual_native, 'Unrecorded native edits'

    paths = run(ADB + ['shell', 'pm', 'path', PKG]).splitlines()
    assert len(paths) == 1 and paths[0].startswith('package:')
    installed_path = paths[0].removeprefix('package:')
    installed_hash = run(ADB + ['shell', 'sha256sum', installed_path]).split()[0]
    assert installed_hash == digest, 'Installed APK differs from verified build'

    expected = json.loads((ROOT / args.resource_manifest).read_text())
    command = 'sha256sum ' + ' '.join(shlex.quote(TARGET + '/' + name) for name in expected)
    output = run(ADB + ['shell', 'run-as ' + PKG + ' sh -c ' + shlex.quote(command)])
    actual = {}
    for line in output.splitlines():
        checksum, name = line.split(None, 1)
        actual[name.strip().removeprefix(TARGET + '/')] = checksum
    assert actual == expected, 'Installed resources differ from localized manifest'

    permissions = run(['E:/06_Apps/Android-SDK/build-tools/36.0.0/aapt.exe',
                       'dump', 'permissions', str(apk)])
    assert 'android.permission.INTERNET' not in permissions
    report = {
        'checked_at_utc': datetime.now(timezone.utc).isoformat(),
        'package': PKG,
        'apk_sha256': digest,
        'installed_apk_matches': 'PASS',
        'apk_crc': 'PASS',
        'native_recorded_patches_only': 'PASS',
        'native_spans_nonoverlap': 'PASS',
        'native_span_count': len(spans),
        'private_resources': 'PASS',
        'verified_files': len(actual),
        'tables_sha256': actual['tables.bin'],
        'script_sha256': actual['script.bin'],
        'resource_manifest': args.resource_manifest,
        'internet_permission': 'ABSENT',
        'device': run(ADB + ['shell', 'getprop', 'ro.product.model']),
        'android_release': run(ADB + ['shell', 'getprop', 'ro.build.version.release']),
        'scope': 'Integrity checks only; see gameplay-verification.json for device tests.',
    }
    (ROOT / args.report).write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('PASS: installed APK,', len(spans), 'native edits,', len(actual),
          'localized resources; INTERNET permission absent. SHA256:', digest)


if __name__ == '__main__':
    main()
