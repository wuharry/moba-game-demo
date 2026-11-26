"""Apply, verify, or restore the local Vainglory language resource patch.

Uses an existing Android SDK / adb. Never installs or uninstalls an app,
clears app data, or reads account files. Only manifest-listed assets are used.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['apply', 'restore', 'verify'])
    parser.add_argument('--adb', help='Path to an existing adb executable')
    parser.add_argument('--serial', help='Device serial if more than one is connected')
    args = parser.parse_args()
    candidates = [args.adb, shutil.which('adb'),
                  'E:/06_Apps/Android-SDK/platform-tools/adb.exe']
    adb = next((str(p) for p in candidates if p and Path(p).is_file()), None)
    if not adb:
        raise RuntimeError('找不到現有的 Android 連線工具。請以 --adb 指定 adb.exe。')

    def call(*parts, device=True):
        command = [adb]
        if device:
            command += ['-s', serial]
        result = subprocess.run(command + list(parts), capture_output=True,
                                text=True, encoding='utf-8', errors='replace', timeout=90)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip()
                               or f'Android tool exited with {result.returncode}')
        return result.stdout

    devices = [line.split()[0] for line in call('devices', device=False).splitlines()
               if len(line.split()) == 2 and line.split()[1] == 'device']
    serial = args.serial
    if serial:
        if serial not in devices:
            raise RuntimeError('指定的手機尚未連線或尚未允許 USB 偵錯。')
    elif len(devices) == 1:
        serial = devices[0]
    else:
        raise RuntimeError('請連接一台已允許 USB 偵錯的手機；多台時請指定 --serial。')

    manifest = json.loads((ROOT / 'patch-manifest.json').read_text(encoding='utf-8'))
    package = manifest['package']
    if package != 'com.superevilmegacorp.game' or manifest['version_code'] != 147219:
        raise RuntimeError('補丁版本資料不符合預期。')
    package_info = call('shell', 'dumpsys', 'package', package)
    version = re.search(r'\bversionCode=(\d+)\b', package_info)
    if not version or int(version.group(1)) != manifest['version_code']:
        raise RuntimeError('這份補丁只適用已安裝的 Vainglory 4.13.4 (147219)。')

    files = manifest['files']
    if len({item['path'] for item in files}) != len(files):
        raise RuntimeError('補丁內有重複路徑。')
    for item in files:
        name = item['path']
        if not re.fullmatch(r'[A-F0-9]{2}/[A-F0-9]{32}', name) or name[:2] != name[3:5]:
            raise RuntimeError('補丁內有不符合預期的資源路徑。')
        for folder, key in [('patch', 'patched_sha256'), ('restore', 'original_sha256')]:
            content = (ROOT / folder / 'Data' / name).read_bytes()
            if hashlib.sha256(content).hexdigest() != item[key]:
                raise RuntimeError('電腦上的補丁或還原檔不完整，尚未修改手機。')

    remote = '/sdcard/Android/data/' + package + '/files/Data/'

    def phone_hashes():
        output = call('shell', 'sha256sum', *(remote + item['path'] for item in files))
        hashes = {}
        for line in output.splitlines():
            digest, name = line.split(maxsplit=1)
            if name.startswith(remote):
                hashes[name[len(remote):]] = digest
        if len(hashes) != len(files):
            raise RuntimeError('手機的遊戲資源不完整。請先用原版遊戲下載完整資料。')
        return hashes

    before = phone_hashes()
    for item in files:
        if before[item['path']] not in (item['original_sha256'], item['patched_sha256']):
            raise RuntimeError('手機有其他版本的資源，已停止，沒有覆寫：' + item['path'])

    if args.action == 'verify':
        patched = sum(before[x['path']] == x['patched_sha256'] for x in files)
        print(f'檢查完成：{patched}/{len(files)} 個資源已套用繁體補丁。')
        if patched != len(files):
            raise RuntimeError('目前未完整套用補丁。')
        print('請在遊戲中保留 English，才能同時使用繁體文字及英文人物語音。')
        return

    folder, key = (('patch', 'patched_sha256') if args.action == 'apply'
                   else ('restore', 'original_sha256'))
    changed = [item for item in files if before[item['path']] != item[key]]
    if not changed:
        print('手機已是指定狀態，不需要重寫或重開遊戲。')
        return
    call('shell', 'am', 'force-stop', package)
    attempted = []
    try:
        for item in changed:
            attempted.append(item)
            call('push', str(ROOT / folder / 'Data' / item['path']), remote + item['path'])
        after = phone_hashes()
        if any(after[item['path']] != item[key] for item in files):
            raise RuntimeError('手機資源寫入後驗證失敗。')
    except Exception:
        failures = []
        for item in attempted:
            old_folder = ('restore' if before[item['path']] == item['original_sha256'] else 'patch')
            try:
                call('push', str(ROOT / old_folder / 'Data' / item['path']), remote + item['path'])
            except Exception:
                failures.append(item['path'])
        if failures:
            print('部分檔案尚未還原，請保持連線並重新執行 restore：' + ', '.join(failures), file=sys.stderr)
        raise
    print('已套用繁體補丁。' if args.action == 'apply' else '已還原原版文字與字型。')
    call('shell', 'monkey', '-p', package, '-c', 'android.intent.category.LAUNCHER', '1')
    print('遊戲已重新開啟。保留 English 可使用繁體文字及英文人物語音。'
          if args.action == 'apply' else '遊戲已重新開啟；語言設定仍保留原選擇。')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('未完成：' + str(error), file=sys.stderr)
        sys.exit(1)
