# P34 Windows 重拍

以 Godot 4.7.2 開啟 `project.godot`。1 原固定鏡、M 正交 MOBA、N 材質 A/B、7／J／6 日照／午後／薄暮、WASD 移動。渲染時保持 Compatibility。

```powershell
$engine = 'E:\06_Apps\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$project = (Resolve-Path '.').Path
$output = Join-Path $project 'replay-P34'
New-Item -ItemType Directory -Force -Path "$output/captures", "$output/angles" | Out-Null
$env:P34_REVIEW_DIR = $output.Replace('\','/')
$env:P34_STILLS_ONLY = '1'
& $engine --path $project --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 --script res://calibration_daylight/review/P34/capture.gd
$env:P34_ANGLE_DIR = "$output/angles"
& $engine --path $project --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 --script res://calibration_daylight/review/P34/extra_angles.gd
& $engine --headless --path $project --fixed-fps 60 -- --study-test
& $engine --headless --path $project --fixed-fps 60 --script res://calibration_daylight/review/P34/test_camera.gd
& $engine --headless --path $project --script res://calibration_daylight/review/P34/check_recorded_sweep.gd
$env:DAYLIGHT_CAPTURE_DIR = "$output/safe"
& $engine --path $project --rendering-method gl_compatibility --audio-driver Dummy --resolution 960x540 -- --study-safe-motion
$env:DAYLIGHT_CAPTURE_DIR = "$output/original"
& $engine --path $project --rendering-method gl_compatibility --audio-driver Dummy --resolution 960x540 -- --study-motion
```

自動化背景執行可用 `Start-Process -WindowStyle Hidden -Wait`，並把 APPDATA 設在可寫入的執行資料夾。禁止 headless 作畫面驗收。

原始基底：Godot_Daylight_P33.zip，Library ID `libfile_fde3_f-ec49d001a4e0819190c4a0516163d08c_4ffde4c2a6608191a7a5b930dbd15373`；SHA256 `97649ac6a353ae93838bf5eb5a6aed7107b98b44f54751e4b67fa5917797dc8d`。歷史圖片／影片若未收進精簡包，仍在該原包；舊 Markdown 與程式不應冒稱為本輪重新渲染的證據。
