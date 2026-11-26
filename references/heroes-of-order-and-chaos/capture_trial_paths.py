"""Capture the fresh prototype's resource paths while it starts."""
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent
ADB = ['E:/06_Apps/Android-SDK/platform-tools/adb.exe', '-s', 'RFCY700C8ZZ']
PKG = 'com.gameloft.android.ANMP.GloftHOHO'
subprocess.run(ADB + ['shell', 'am', 'force-stop', PKG], check=True)
subprocess.run(ADB + ['shell', 'am', 'start', '-n', PKG + '/com.gameloft.android.ANMP.GloftHOHM.MainActivity'], check=True, capture_output=True)
lines = []
for _ in range(14):
    time.sleep(0.45)
    pid = subprocess.run(ADB + ['shell', 'pidof', PKG], capture_output=True, text=True).stdout.strip()
    if not pid.isdigit():
        continue
    command = f'run-as {PKG} sh -c "readlink /proc/{pid}/cwd; ls -l /proc/{pid}/fd"'
    result = subprocess.run(ADB + ['shell', command], capture_output=True, text=True)
    lines.extend(line for line in result.stdout.splitlines() if any(word in line for word in ('files', '.bin', '.bdae', 'denied', 'sdcard')))
lines = list(dict.fromkeys(lines))
(ROOT / 'analysis/trial-open-paths.txt').write_text('\n'.join(lines))
print('\n'.join(lines[:35]))
