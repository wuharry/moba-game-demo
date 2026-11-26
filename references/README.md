# Mobile MOBA 標竿遊戲原始檔案逆向工程總覽（VG 3v3 × HOC 5v5）

本目錄收錄針對兩款經典行動端 MOBA 標竿作品——**《最終榮耀 Vainglory》v4.13.4（聚焦 3v3 海希安峽谷）** 與 **《混沌與秩序之英雄戰歌 Heroes of Order & Chaos》v3.6.5a（聚焦 5v5 辛斯卡德裂口）**——直接解析本機原始封裝檔所得之五大設計維度逆向筆記、自製唯讀結構分析器、離線／繁中修補腳本、OpenCC 字典與雜湊驗證 JSON，供本專案（Godot 4.7 原創行動 MOBA Demo）地圖、場景渲染、資源分包與 UI 架構研發對照使用。

> [!IMPORTANT]
> **公開倉庫合規邊界**：本目錄透過 [.gitignore](file:///E:/hd2d-scene-starter/art-lookdev/references/.gitignore) 與 [.gdignore](file:///E:/hd2d-scene-starter/art-lookdev/references/.gdignore) 嚴格排除所有 `.apk`、`.obb`、`res.bin`、`tables.bin`、`script.bin`、`.so`、`.dex`、`.swf`、原始字庫與解包遊戲素材，且不參與 Godot 場景資產匯入與發布雜湊計算。

---

## 1. 逆向工程專題文件與工具索引

- **Vainglory（聚焦 3v3 海希安峽谷 Halcyon Fold）**
  - 完整逆向筆記：[vainglory/REVERSE_ENGINEERING_NOTES.md](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/REVERSE_ENGINEERING_NOTES.md)
  - 原始檔唯讀解析腳本：[vainglory/inspect_vg_3v3_architecture.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/inspect_vg_3v3_architecture.py)
  - 結構化驗證摘要：[vainglory/vg-3v3-architecture-summary.json](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/vg-3v3-architecture-summary.json)
- **Heroes of Order & Chaos（聚焦 5v5 辛斯卡德裂口 Sinskaald Rift）**
  - 完整逆向筆記：[heroes-of-order-and-chaos/REVERSE_ENGINEERING_NOTES.md](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/REVERSE_ENGINEERING_NOTES.md)
  - 原始檔唯讀解析腳本：[heroes-of-order-and-chaos/inspect_hoc_5v5_architecture.py](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/inspect_hoc_5v5_architecture.py)
  - 結構化驗證摘要：[heroes-of-order-and-chaos/hoc-5v5-architecture-summary.json](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/hoc-5v5-architecture-summary.json)

---

## 2. 跨引擎五大維度橫向對照與 Godot 原創 MOBA 落地規格

| 設計維度 | Vainglory（E.V.I.L. 引擎 — **3v3 海希安峽谷**） | Heroes of Order & Chaos（Glitch 引擎 — **5v5 辛斯卡德裂口**） | 本專案 Godot 4.7 原創 MOBA 吸收策略 |
| :--- | :--- | :--- | :--- |
| **1. 地圖設計** | `200m × 80m`（`2.5 : 1`）橫向構圖；**上方單一兵線（5 塔縱深）+ 下方扇形野區**（雙方水晶礦工、中央黃金礦工→15 分鐘海怪 Kraken、底部野區商店、反應式草叢） | `256 × 256` 正方形對角線構圖（`map_id=7` `world/rift.wld`）；**上中下三線 + 斜向河道 + 四象限三級野怪／紅藍菁英／河道巨龍 Boss**，支援混沌方鏡頭翻轉 | 支援橫向精煉 3v3 與對角線 5v5 雙規格；若採對角線地圖必實作鏡像視角轉換，並將野區商店／中立計時目標納入前期爭奪動線 |
| **2. 場景設計** | 離線烘焙 `2048²` 底圖 + **`100×40`（`2m` 間距）19-float 動態光照探針** + 漂移雲影 `CloudShadows` + 非同步 `FogOfWar.Texture` + PCF 接觸軟陰影；嚴守「石板路中高明度低彩度 vs 野區低明度冷調」 | `256×256` 高度場地形（含英雄腳部水深染色 `waterDepthFactor`）+ **24 塊烘焙 Lightmap 網格（`26.10 MiB`）+ 頂點 9 階球諧光照（L2 SH）** + 高斯模糊 `WarFog` 貼圖裁剪；秩序暖金 vs 混沌暗紫熔岩對比 | 延續本專案 v9 原神級雙色環境光與雲影（`sunvine_clouds.png`），結合 VG 的 `2m` 級 LightmapGI / SH 探針與明度三分法，確保英雄與血條在華麗植被上 100% 清晰 |
| **3. 資源分配** | `1.33 GiB` 單一 OBB（48,443 檔，MD5 雜湊槽位）：GPU Mipmap 貼圖佔 **55.2%**、音訊 **18.8%**、`RSC0` 網格/動畫/513 支 Shader **18.3%**、`CFF0` 關卡/UI 僅 **0.7%** | 核心母包 `res.bin`（`403.71 MiB` ZIP 零壓縮直讀：UI 49.1%、模型與 Lightmap 44.6%）+ `tables.bin`（136 表）+ `script.bin`（50 Lua AI）+ **獨立地圖包 `rift.bin` 與 66 個單英雄包 `hero_*.bin`** | 採用 HOC **「共用母包 + 每張地圖獨立 `.pck` + 每位英雄獨立 `.pck`」** 按需載入架構，單局僅載入登場英雄資源以壓低行動端記憶體 |
| **4. 主選單 UI** | 原生 `CFF0` UI + `MenuMeshCamera` 3D 展示；首頁極簡減法（滿版群像 + 左側背包 + 右下暗紅「開始遊戲」），2 次點擊進房；複合 `.font` 區段路由無縫混排拉丁數字與繁中 | `gameswf` 向量動畫（`LGM_android.swf` `759 KB`）+ 30+ `DlgLgmMainMenu*` + 動態星火雲霧粒子；頂部雙貨幣列 + 中央五宮格 Bento 活動／限免／個人檔案磁貼 | 主選單採 VG 式「3D 即時場景／英雄展示 + 2 步極速開局主按鈕」，字體設定 Godot `FontVariation` / Fallback 鏈分離英數標題字與繁中字庫 |
| **5. 戰鬥 HUD** | 原生支援 **Tap 點觸** 與 **Joystick 搖桿**；左上橫向小地圖、左緣垂直主動道具欄、底部置中 3 技 + Ult、半透明防偷襲黑底商店（`DHUD_Store`） | 輕量化 `IGM_android.swf`（`313 KB`）；左上三色數值條與快買入口、右上 `DlgMiniMap` 3D↔2D 雙向投影小地圖（點擊移鏡）、右側 4 技 + 獨立金色 `+` 加點鈕、五頁籤 10 人計分板 | 預設提供「左搖桿 + 右扇形技能 + 獨立加點鈕 + 雙向投影小地圖」，並保留高階點觸模式與 VG 式半透明樹狀快買商店 |

---

## 3. 重現唯讀分析指令

若本機下載資料夾存在對應原始封裝檔，可隨時執行以下唯讀腳本重新驗證（不會解包或修改任何原始檔案）：

```powershell
C:\Python313\python.exe references/vainglory/inspect_vg_3v3_architecture.py
C:\Python313\python.exe references/heroes-of-order-and-chaos/inspect_hoc_5v5_architecture.py
```
