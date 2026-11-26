"""Capture only the game under test; writes no game resources."""
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
ADB = 'E:/06_Apps/Android-SDK/platform-tools/adb.exe'
BASE = [ADB, '-s', 'RFCY700C8ZZ']
args = sys.argv[1:]
if args and args[0] == 'tap':
    subprocess.run(BASE + ['shell', 'input', 'tap', args[1], args[2]], check=True)
    args = args[3:]
    time.sleep(0.7)
name = args[0] if args else 'screen'
subprocess.run(BASE + ['shell', 'screencap', '-p', '/sdcard/Download/.hoc-offline-check.png'], check=True, capture_output=True)
data = subprocess.check_output(BASE + ['exec-out', 'cat', '/sdcard/Download/.hoc-offline-check.png'])
pos = data.find(b'\x89PNG\r\n\x1a\n')
assert pos >= 0, 'Screenshot was not a PNG'
path = ROOT / (name + '.png')
path.write_bytes(data[pos:])
print(path)
