"""Capture a bounded, local startup sequence without reading player files."""
from pathlib import Path
import io
import json
import subprocess
import sys
import time
from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parent
ADB = ['E:/06_Apps/Android-SDK/platform-tools/adb.exe', '-s', 'RFCY700C8ZZ']
PACKAGE = 'com.superevilmegacorp.game'
label = sys.argv[1]
assert label in ('original', 'patched')


def call(*args):
    return subprocess.check_output(ADB + list(args), timeout=30)


call('shell', 'am', 'force-stop', PACKAGE)
start = time.perf_counter()
call('shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
records = []
for index, offset in enumerate((0, 1, 2, 4, 8, 12)):
    time.sleep(max(0, start + offset - time.perf_counter()))
    capture_start = time.perf_counter() - start
    call('shell', 'screencap', '-p', '/sdcard/Download/.vg-translation-check.png')
    data = call('exec-out', 'cat', '/sdcard/Download/.vg-translation-check.png')
    assert data.startswith(b'\x89PNG\r\n\x1a\n')
    path = ROOT / f'startup-{label}-{index:02}.png'
    path.write_bytes(data)
    frame = Image.open(io.BytesIO(data)).convert('RGB')
    mean = sum(ImageStat.Stat(frame).mean) / 3
    row = {'file': path.name, 'capture_start_seconds': round(capture_start, 3),
           'capture_end_seconds': round(time.perf_counter() - start, 3),
           'mean_brightness_0_255': round(mean, 2)}
    records.append(row)
    print(json.dumps(row), flush=True)
(ROOT / f'startup-{label}.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
