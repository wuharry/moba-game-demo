# R20-D 重拍

Godot 4.7.2 開啟 project.godot，F5 後按 4 進硃萼雨庭，C 切固定近景／MOBA 俯視，WASD 移動。

在專案根目錄執行（輸出目錄需可寫）：

```powershell
& 'E:\06_Apps\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --windowed --resolution 1280x720 --fixed-fps 60 -- --gallery-map=3 --gallery-capture=review/refinement/GROVE_R20/replay
& 'E:\06_Apps\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 -- --gallery-walk
```

Mobile 桌機回歸加 `--rendering-method mobile`；記錄輸出不等於手機實測。
固定鏡位與原版完全相同，光照參數差異見 refine_grove.gd _build_light。
