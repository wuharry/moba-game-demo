# 四景環境美術驗收

用 Godot 4.7.2 匯入專案根目錄的 `project.godot`，等待 GLB 與貼圖匯入完成，按 F5 進入四景比較。實機驗證使用 Forward+、Vulkan、RTX 4080 Laptop GPU 和 1120 × 630。建置專案已附模型及貼圖。

| 操作 | 功能 |
| --- | --- |
| 1、2、3、4 | 北盆地壓力站、潮鎖棧岸、日藤庭院、硃萼雨庭 |
| WASD | 角色移動 |
| C | 近景、俯視和行走相機 |
| E | 北盆地壓力站的供電互動 |
| Tab | 壓力站的任務測試場 |
| G | 在任務場回到四景比較 |

每張場景都是可走動的小型原型。壓力站另有互動和岔路。四張圖的主路用同一套碰撞膠囊走過各自的檢查點。分數為人工對照的美術評核，會受鏡位和選用畫面影響。完整 MOBA 對局、多人遮擋和手機效能待驗證。

## Prompt 與截圖

- [跨場景共同關鍵點](review/refinement/COMMON_FINDINGS.md)
- [實際使用的主 Prompt](review/refinement/MASTER_PROMPT.md)
- [後續場景建置與 90 分驗收](review/refinement/SCENE_STYLE_STANDARD.md)
- [專案製作與驗收 Harness](AGENTS.md)
- [四景實機雙鏡位總覽](review/refinement/Godot_Four_Scenes_Final.jpg)
- [北盆地逐輪紀錄](review/refinement/basin_iterations.md) · [岩地子測試](review/refinement/basin_geology_iterations.md)
- [潮鎖棧岸逐輪紀錄](review/refinement/tide_iterations.md)
- [日藤庭院逐輪紀錄](review/refinement/sunvine_iterations.md)
- [硃萼雨庭逐輪紀錄](review/refinement/grove_iterations.md)

`review/refinement/final/` 放四張場景最新保留版的八張固定鏡位和路線驗證輸出。各版本子資料夾包含過程驗收圖。Blender 作者檔及角色底模來源說明放在 `authoring/`。

## 重跑路線與截圖

在專案目錄以 PowerShell 執行，先將 `$godot` 設為本機 Godot console 執行檔路徑。

```powershell
& $godot --headless --path . --fixed-fps 60 -- --gallery-walk
& $godot --path . --windowed --resolution 1120x630 --fixed-fps 60 -- '--gallery-capture=./review/refinement/final'
& $godot --path . --windowed --resolution 1120x630 --fixed-fps 60 -- '--gallery-capture=./review/refinement/basin_rounds/B10' --gallery-map=0 --basin-round=10
& $godot --headless --path . --scene res://station.tscn --fixed-fps 60 -- --station-test
```

截圖請用實際渲染窗。歷史版本的完整效果以已保留的固定鏡位為準。
四景定版、雙鏡位分項與步行結果見 [四景美術定版](review/refinement/ROUND_SCORES.md)。提交前執行 `python tools/check_scene_release.py` 驗證定版證據。
