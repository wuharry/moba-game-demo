from pathlib import Path
import subprocess,sys,time
ROOT=Path(__file__).resolve().parent
ADB='E:/06_Apps/Android-SDK/platform-tools/adb.exe'
args=sys.argv[1:]
if args and args[0]=='tap':
 subprocess.run([ADB,'shell','input','tap',args[1],args[2]],check=True);args=args[3:];time.sleep(0.6)
name=args[0] if args else 'screen'
subprocess.run([ADB,'shell','screencap','-p','/sdcard/Download/.vg-translation-check.png'],check=True,capture_output=True)
b=subprocess.check_output([ADB,'exec-out','cat','/sdcard/Download/.vg-translation-check.png'])
pos=b.find(b'\x89PNG\r\n\x1a\n');assert pos>=0
p=ROOT/(name+'.png');p.write_bytes(b[pos:]);print(p)
