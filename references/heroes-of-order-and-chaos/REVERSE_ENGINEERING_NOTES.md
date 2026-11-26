# Heroes of Order & Chaos（混沌與秩序之英雄戰歌 v3.6.5a / Build 36523）原始檔案逆向工程筆記

> **解析範圍說明**：本筆記直接針對本機原始遊戲封裝檔（`original/HeroesOfOrderAndChaos-3.6.5a-36523.apk`、`original/assets/res.bin`、`tables.bin`、`script.bin`、`menu.bin`、`game_Android.conf`、`color_corrector.conf` 及 `libAndroid.so`，工作區總計 `2.16 GB` / `2.01 GiB`）進行唯讀記憶體解析；**地圖維度聚焦於經典 5v5「辛斯卡德裂口（Sinskaald Rift，`map_id=7`）」**（並附註同屬 5v5 的 `map_id=12` 結構表對照，略過 3v3 與其他測試地圖）。公開倉庫僅收錄自製離線化／AI／本地化腳本、交接紀錄與雜湊驗證 JSON，**嚴格排除所有原始 `.apk`／`.bin`／`.so`／`.dex` 與解包資產**。

---

## 1. 地圖設計逆向解析：5v5 辛斯卡德裂口（Sinskaald Rift）

### 1.1 `FTABLE` 原始地圖與區域座標表證據
透過解碼 `tables.bin`（`GBMP` 封裝）內的二進位資料表 `tables/map_info_hoc.tbl`（魔數 `FTABLE`，欄位格式 `uussuu`，共 20 列）與 `tables/quests_zones_hoc.tbl`（欄位格式 `uuffffffff`，共 39 列）：
- **經典 5v5 主地圖定義**：`id = 7` → 名稱 `'rift'`（遊戲內繁中譯名：**辛斯卡德裂口**），世界場景路徑 `'world/rift.wld'`（獨立地形分包 `rift.bin`），引擎空間預算參數 `917,504`，模式旗標 `4`。（註：表中另有一張後期擴充 5v5 地圖 `id = 12` `'Vault of Desecrators'`／地下領域遺跡 `'world/vault.wld'`，預算參數 `983,040`；本筆記以標準三線 5v5 `rift` 為主軸。）
- **`256 × 256` 正方形對角線雙陣營拓樸**：
  - 結合 `libAndroid.so` 地形高度查詢函式 `GetHeight` 之頂點索引上限 `256`（見 [offline_terrain.py](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/offline_terrain.py)）與 `quests_zones_hoc.tbl` 中 `map_id = 7` 的錨點座標：
    - 秩序（Order，左下聖光石城基地）核心錨點：`X = 55.0, Y = 10.12, Z = 236.0`
    - 混沌（Chaos，右上熔岩黑曜基地）核心錨點：`X = 240.60, Y = 10.31, Z = 43.71`
    - 河道／戰略中繼區錨點：`X = 189.02, Y = 10.00, Z = 223.40`（區域範圍 `20.0 × 5.0 × 10.0`）
  - 兩座主堡精確坐落於 `256 × 256` 高度場的左下—右上對角線端點（對角直線跨度約 `268` 世界單位，基準地表高程 `Y ≈ 7.0 ~ 10.5` 公尺）。
  - **混沌方視角翻轉支援**：引擎提供設定項 `LCFG_CAMERA_ROTATE_CHAOS` 並於 `res.bin` 內預置鏡像小地圖貼圖 `2d_texture/maps/rift_r_2X.tga` 與 `rift_r_X4_2X.tga`，解決傳統對角線 MOBA「右上陣營往左下推線受底部 HUD 遮擋視野」的手機端痛點。

### 1.2 三兵線、斜向河道與四象限多層級野區設計
1. **標準三線推塔與兵營破口機制**：
   - 上路（Top）、中路（Mid，最短對角捷徑）、下路（Bot）各設外塔、內塔、高地塔與兵營（`CBarrack` / `light_new_build_barracks.bdae` vs `dark_barracks.bdae`），最深處為基地祭壇與生命之泉。每波兵線由近戰、遠程與攻城車（`Unit_Chaos_Melee` / `Range` / `Siege.lua`）組成，摧毀兵營後強化己方超級兵施壓。
2. **斜向河道與四象限野區生態（`script.bin` 50 支 AI 腳本證實）**：
   - 斜貫左上至右下的河道（`model/scene/water/river.bdae`）將野區切為四個象限，透過河道高地斜坡製造視野落差與 Gank 動線。
   - 野區營地採三級強度梯度配置：
     - **常規經濟／經驗營地**：巨熊（`Bear01/02`）、豺狼人（`Gnoll02`）、哥布林（`Goblin02`）、巨蛛（`Spider01/02`）、岩石魔像（`Stone_Golem`），供打野與線上英雄發育。
     - **紅藍屬性增益菁英營地**：`Action_Neutral_Elite01.lua` 與 `Action_Neutral_Elite02.lua`。
     - **河道史詩級團隊 Boss**：巨龍（`Action_Neutral_Dragon01.lua`）與雙大型首領（`Action_Neutral_Boss.lua` / `Boss2.lua`），強制中後期雙方在中路河道口展開 5v5 正面視野爭奪與團戰。

---

## 2. 場景設計逆向解析：Glitch 引擎高度場、球諧光照與 Shader 管線

解析 `res.bin` 根目錄共 **143 支 `.glsl` Shader**、`model/scene/` 場景分塊與 `libAndroid.so` 渲染符號，可見 Gameloft Glitch 引擎針對百元至旗艦行動裝置設計的可伸縮渲染管線：

### 2.1 `256 × 256` 高度場地形與水深染色連動
- **規則網格高度場（Heightfield Terrain）**：由 `TerrainVP/FP.glsl`、`TerrainNormalVP/FP.glsl` 與 `TerrainNormalIrrFP.glsl`（另備低階 GPU 變體 `*_N6.glsl`）渲染；CPU 端 `GetHeight` 對 `257 × 257` 頂點（索引 `0..256`）做快速雙線性插值，供角色貼地、粒子發射器（`GetHeightForEmitter`）與水體判定共用。
- **水體平面反射與英雄涉水深度著色**：
  - 河道水面 `waterVS.glsl` / `waterFS.glsl` 結合 `_Fresnel` 菲涅爾貼圖、`_ReflectionTex` 動態／預烘焙反射貼圖與 `_BumpMapNormal` 雙層滾動波紋法線（`waterBumpOffset`）；熔岩與流體則使用多層 UV 混合之 `FluidSurfaceVS/FS.glsl` 與 `lavaVS/FS.glsl`。
  - 更巧妙的是，英雄專屬 Shader `CommonHeroFS.glsl`（`6,092 B`）內建 `varying mediump vec2 waterDepthFactor` 與 `uniform lowp vec3 waterColor`，當英雄走入河道時直接依地形水深對腿部做涉水染色過渡，免除昂貴的螢幕空間深度讀取！

### 2.2 24 塊烘焙 Lightmap 場景網格 + L2 九階球諧光照（Spherical Harmonics）
- **雙陣營主題場景視覺分區**：秩序半場（`model/scene/light_new/` `6.81 MiB` + `light/` `4.68 MiB`）採用明亮暖白石磚、翠綠草甸與金飾雕像；混沌半場（`dark/` `4.25 MiB` + `dark_new/` `1.95 MiB`）轉為焦黑火山岩、紫紅水晶與暗紅火盆，跨過河道即呈現鮮明領地心理暗示。
- **批次烘焙 Lightmap 分塊**：`model/scene/lightmap/rift/` 內含 **24 個** 二進位 Collada 烘焙光影分塊（`glitchobject00.bdae` ~ `glitchobject23.bdae`，合計 **`26.10 MiB`**），由 `EntityGroup::LoadBatchedLightMapScene` 與 `STerrainChunk::SetLightMapTexture` 批次載入並綁定第二組 UV `TexCoord1`（`global_lightMapCoef`）。
- **頂點 9 階球諧環境光（SH9）**：主力場景頂點著色器 `CommonSceneVS.glsl`（`13,835 B`）明確定義 `#define eNum 9 // sh bands level` 與完整 `Y00`、`Y1_1..Y11`、`Y2_2..Y22` 球諧基底巨集，搭配片段著色器 `CommonSceneFS.glsl` / `CommonSceneFS_High.glsl` 的雙環境光 `global_sceneAmbientColor1/2` 與高光查表貼圖 `global_powerTable`，在無須逐像素 PBR 運算下保有立體石雕受光層次。

### 2.3 高斯柔化戰爭迷霧（WarFog）與面板級色彩校正
- **迷霧管線**：引擎將視野格網渲染至迷霧緩衝區（`SaveWarfogVS/FS.glsl`），再經 `WarfogBlurVP/FP.glsl` 模糊柔化邊界後輸出為全域貼圖 `global_fogTexture`，所有地形、場景物件與水體 Shader 皆透過 `vCoordWarFog` 同步壓暗迷霧外區域，並由 `EffectManager::SetWarFogVisible` 隱藏迷霧內敵方技能粒子以防透視作弊。
- **畫質開關與後處理**：提供 `LCFG_GFX_TERRAIN`、`LCFG_GFX_WATER`、`LCFG_GFX_UNIT_SHADOW` 三大效能分級開關，並以 `ColorCorrectorFS.glsl` 的 `mat4 colorCorrection` 搭配 `color_corrector.conf` 進行後處理調色。

---

## 3. 資源分配逆向解析：`GBMP` 封裝與「母包 + 英雄/地圖單獨分包」架構

### 3.1 `GBMP` 自訂 ZIP 封裝機制
- HOC 所有 `.bin` 資源包底層皆為標準 ZIP 結構（保留檔案尾端 Central Directory 索引），僅將每筆 Local File Header 的前 4 Bytes 由 `PK\x03\x04` 替換為 `GBMP`（引擎於 `glitch::io::CPackReader::UpdateFileLocalHeader` 讀取時動態還原），且在大型美術包 `res.bin` 中全面採用 **ZIP Store（0 壓縮，`compress_size == file_size`）**，以空間換取手機端 **零解壓 CPU 開銷與瞬間串流讀取**。

### 3.2 原始基礎包（`444.11 MiB`）與 85 檔模組化 DLC 總體配置
1. **原始基礎目錄（`original/` 共 `444.11 MiB`）**：
   - `HeroesOfOrderAndChaos-3.6.5a-36523.apk`：**`37.47 MiB`**（含 ARM64 `libAndroid.so`、DEX 啟動層與基礎 Android 資源）。
   - `assets/res.bin`：**`403.71 MiB`**（共 **7,465 個檔案**，核心 UI、共用場景 Lightmap、小兵／野怪／建築模型、特效與 143 支 Shader）。
   - `assets/tables.bin`：**`2.67 MiB`**（Deflate 壓縮，解壓後 **`12.65 MiB`**，共 **136 張 `.tbl` `FTABLE` 遊戲數值表**）。
   - `assets/script.bin`：**`0.23 MiB`**（Deflate 壓縮，解壓後 **`1.44 MiB`**，共 **50 支 Lua 5.1 AI 行為與單位配置腳本**）。
   - `assets/menu.bin`：**`174 B`**（內含 `world/menu.wld` `48 B` `AWLD` 場景定義）及 `hoc.txt` / `game_Android.conf` / `color_corrector.conf`。
2. **核心美術包 `res.bin`（7,465 檔 / 402.44 MiB 內容）精確配比表**：

| 頂層目錄 / 類別 | 檔案數量 | 大小（MiB） | 佔比 | 關鍵內容與格式（`.bdae` / `.png` / `.beff` / `.swf` / `.glsl`） |
| :--- | ---: | ---: | ---: | :--- |
| **`ui/`**（大廳與戰鬥介面） | 2,188 | 197.66 MiB | **49.1%** | `ui/icon/` 技能／裝備／成就圖示 2,144 張（`120.07 MiB`）、三平台解析度大廳圖集 `LGM*`（`58.18 MiB`）、戰鬥 HUD 圖集 `IGM*`（`16.34 MiB`）、6 支 Flash `.swf`（`3.07 MiB`） |
| **`model/`**（二進位 Collada 網格） | 2,454 | 179.31 MiB | **44.6%** | `model/scene/` 1,683 檔（`138.71 MiB`，其中各圖烘焙 Lightmap 佔 `102.69 MiB`，5v5 `rift` 佔 `26.10 MiB`）、`model/npc/` 614 檔（`37.84 MiB` 小兵／野怪／塔）、`model/item/` 147 檔（`2.70 MiB`） |
| **`effect/`**（粒子與技能特效） | 2,554 | 11.31 MiB | **2.8%** | `.beff` 特效描述檔（含英雄技能、自然環境與主選單動態粒子） |
| **`2d_texture/`**（小地圖與環境貼圖） | 22 | 9.32 MiB | **2.3%** | 含 5v5 小地圖 `rift_2X.tga`（`8,244 B`）、放大戰術地圖 `rift_X4_2X.tga`（`131,124 B`）與混沌鏡像版 |
| **`strings/`**（多語系字串包） | 18 | 3.64 MiB | **0.9%** | `.bar` 本地化字串封裝 |
| **根目錄 Shader 與設定 + `max_fx/`** | 229 | 1.20 MiB | **0.3%** | **143 支 `.glsl` Shader**（`0.23 MiB`）與 35 個刀光／箭矢 `.bdae` 模型（`0.54 MiB`） |

3. **按需下載之 85 檔模組化 DLC 策略（見 [asset-copy-list.json](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/trial/asset-copy-list.json)）**：
   - 將每張地圖地形拆為獨立包（`rift.bin`、`vault.bin`、`3v3_desert.bin`），並將 **66 位英雄各自封裝為單獨的 `hero_<name>.bin`**（如 `hero_elfhunter.bin`、`hero_flame_knight.bin`），外加 `sounds.bin`、`res_t.bin`、`model_phy.bin` 與 4 套字型（`EduFontin.ttf`、`Exo2.0-Bold.otf`、`FontJP.ttf`、`Fontin.ttf`）。單局 5v5 對戰只需掛載 `rift.bin` 與本場 10 名英雄的 `.bin`，大幅降低執行期 RAM 峰值與熱更新流量！

---

## 4. 主選單 UI 設計逆向解析：`gameswf` 向量大廳與 Bento 磁貼儀表板

1. **Scaleform / `gameswf` + C++ `Dlg*` 雙層架構**：
   - 大廳視覺排版與補間動畫封裝於未壓縮 SWF v8 向量檔 `ui/LGM_android.swf`（`758,851 B`）（另有標準與 iPad 版），由 `GameSWFVS/FS.glsl` 硬體加速繪製；業務邏輯則綁定至 `libAndroid.so` 內超過 **30 個 `DlgLgmMainMenu*` C++ 類別**（如 `DlgLgmMainMenu`、`DlgLgmMainMenuPlayNew`、`DlgLgmMainMenuPlayMapSelect`、`DlgLgmMainMenuUserTalent`、`DlgLgmMainMenuTabletMain`），背景疊加 `world/menu.wld` 與 `scene_menu_cloud.beff`、`scene_menu_spark.beff`、`main_menu_play_button_effect1/2.beff` 星火雲霧特效。
2. **「頂部資產列 + 中央五宮格磁貼 + 右緣社交列」資訊密度配置**：
   - **頂部常駐列**：左起為英雄頭像、成就獎盃、召喚師等級徽章（Lv.40）與體力條，中右為綠底「商店」入口、藍鑽與金幣餘額（附綠色 `+` 號儲值鈕）。
   - **中央 Bento 儀表板磁貼**：左上大尺寸焦點輪播區、中上「活動／HOC TV」、右上「英雄收藏與本週限免進度」、左下「熱門物品」、中下「抽獎」與「個人檔案（天賦樹 52 格與銘文板系統入口）」、右下為帶動態流光粒子的藍色主行動按鈕 **「開始」**。
   - **開局導覽流**：`主選單「開始」 → 模式選擇（單人／合作／排位） → 三卡橫向地圖選擇（首卡即為「5v5 辛斯卡德裂口」） → 對戰房間與選角／天賦／銘文頁切換（DlgMatchSettingNew / DlgChooseHero） → VS 載入畫面（VS_loading_2x.png）`。

---

## 5. 戰鬥介面 UI 設計逆向解析：高密度雙手 HUD 與 3D↔2D 小地圖投影

1. **輕量化戰鬥專屬 SWF 容器**：進入 5v5 對戰後卸載龐大的大廳圖集，改載僅 **`313,408 B`** 的 `ui/IGM_android.swf`，將寶貴 VRAM 讓給 10 名英雄模型與場景烘焙貼圖。
2. **四角機能分區與右手扇形戰鬥熱區**：
   - **左上角角色儀表板（`DlgHUD`）**：英雄頭像與等級旁並列三條帶精確數值的長條（綠 HP `609/609`、白藍 MP `150/150`、經驗條 `0/200`），上方緊貼即時金幣與快捷購買推薦裝按鈕（一鍵直通 `DlgNPCShopNew`），下方附隊伍展開鈕、快捷聊天（`DlgChatControl`）與設定齒輪。
   - **右上角雙向投影小地圖（`DlgMiniMap`，40 個引擎方法）**：頂部細列顯示比賽時間與雙陣營擊殺總分，正下方為 5v5 裂口正方形小地圖。引擎透過 `_InitPos3dToMap2d`、`_Positon3dToMap2d` 與 `_Map2dToPositon3d` 將 `256 × 256` 3D 戰場即時映射至 2D 畫布，支援野怪刷新提示（`NeutralitySpawnInfo`）、點擊小地圖瞬間移動觀察鏡頭（`_SetCamPosByClick`）、拖曳滑動視角（`onDragged`）與長按發送戰術標記（`SetPlayerMark`），點擊放大亦可檢視高解析 `rift_X4_2X.tga` 戰術全圖。
   - **右側技能列與目標鎖定區（`DlgChooseSkill` + `DlgShortcutBar`）**：小地圖下方設目標頭像環，往下垂直排列 4 顆主動技能圓鈕（當升級點數可用時，每顆技能左側浮現獨立金色 `+` 號按鈕，支援點擊瞬發與拖曳指向施放），右下角配置大型「普攻劍鈕」與「切換敵方目標鈕」，底部偏右則橫排天賦主動技、藥水與回城快捷欄。
3. **五合一戰術計分板（`DlgBattleStatistics`）與分類商店（`DlgNPCShopNew`）**：
   - 點擊頂部戰況可開啟整合「統計／背包／屬性／目標／選項」5 枚圓形徽章頁籤的中央視窗，同屏檢視 5v5 雙方 10 人的等級、K/D/A/補刀、雙天賦技能與 6 格裝備。
   - 商店介面頂部固定顯示「返回 + 金幣 + 6 格背包」，底部以 6 顆大型金屬圓鈕切換「推薦／靴子／消耗品／物理／魔法／防禦」，在手機小螢幕上兼顧合成路線瀏覽與單指快買。

---

## 6. 本目錄收錄之自製腳本、離線 AI 與驗證檔案索引

- [inspect_hoc_5v5_architecture.py](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/inspect_hoc_5v5_architecture.py)：唯讀記憶體解析 `GBMP` 封裝（`res.bin` / `tables.bin`）與 5v5 裂口架構之自動化腳本。
- [hoc-5v5-architecture-summary.json](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/hoc-5v5-architecture-summary.json)：上述腳本對原始檔案執行輸出之結構化驗證摘要。
- [HANDOVER-20261120.txt](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/HANDOVER-20261120.txt) / [AI-HANDOVER-20261120.txt](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/AI-HANDOVER-20261120.txt)：離線單機化、ARM64 高度場邊界越界修復、繁中字串修補（479 列）與雙陣營 AI v3 實機驗證交接紀錄。
- [offline_terrain.py](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/offline_terrain.py) / [build_trial.py](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/build_trial.py) / [localize_resources.py](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/localize_resources.py) / [unpack_resources.py](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/unpack_resources.py)：ARM64 原生指令修補、高度場邊界保護與 `GBMP`/`FTABLE` 資源工具鏈。
- [hero_decisions.lua](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/offline_ai/hero_decisions.lua) / [test_decisions.lua](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/offline_ai/test_decisions.lua) / [build_ai_resources.py](file:///E:/hd2d-scene-starter/art-lookdev/references/heroes-of-order-and-chaos/build_ai_resources.py)：自製 Lua 5.1 雙陣營英雄集火、殘血保護、防禦塔仇恨撤退與 22 項單元測試腳本。
